import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:printer_agent/core/models/order_item.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../queue/print_queue_manager.dart';
import '../router/printer_router.dart';
import '../models/print_job.dart';
import '../models/restaurant_order.dart';
import '../config/print_config.dart';

class WindowsSocketService {
  IO.Socket? _socket;
  final PrintQueueManager _queueManager;
  final PrinterRouter _router;
  final Set<int> _printedIds = {};

  bool _connected = false;
  bool get isConnected => _connected;

  final _logController    = StreamController<String>.broadcast();
  final _statusController = StreamController<bool>.broadcast();

  Stream<String> get logStream    => _logController.stream;
  Stream<bool>   get statusStream => _statusController.stream;

  WindowsSocketService(this._queueManager, this._router);

  Future<Map<String, dynamic>?> _fetchOrderRaw(String orderId) async {
    const maxAttempts = 3; // 1 initial + 2 retries
    final url = '${PrintConfig.apiUrl}'
        '/api/v2/vendoremployee/order-temp-details'
        '?order_id=$orderId';

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _log('🌐 Fetching (attempt $attempt/$maxAttempts): $url');

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${PrintConfig.authToken}',
          },
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode != 200) {
          _log('❌ API error: ${response.statusCode} (attempt $attempt)');
          if (attempt < maxAttempts) continue;
          return null;
        }

        final json = jsonDecode(response.body);
        final details = json['order_details_data'];

        if (details == null) {
          _log('❌ order_details_data is null (attempt $attempt)');
          if (attempt < maxAttempts) continue;
          return null;
        }

        final billList = json['bill'] as List<dynamic>? ?? [];
        final billData = billList.isNotEmpty
            ? Map<String, dynamic>.from(billList[0] as Map)
            : <String, dynamic>{};

        final kdsList = json['kds'] as List<dynamic>? ?? [];
        final kdsData = kdsList.isNotEmpty
            ? Map<String, dynamic>.from(kdsList[0] as Map)
            : <String, dynamic>{};

        if (billData.isEmpty) {
          _log('bill is empty or missing');
        } else {
          _log('bill loaded');
        }

        if (kdsData.isEmpty) {
          _log('⚠️ kds is empty or missing');
        } else {
          _log('kds loaded');
        }

        return {
          ...Map<String, dynamic>.from(details),
          'bill': billData,
          'kds':  kdsData,
        };
      } catch (e) {
        _log('❌ fetchOrderRaw error (attempt $attempt): $e');
        if (attempt == maxAttempts) return null;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchAggregatorOrder(String orderId) async {
    const maxAttempts = 3;
    final url = '${PrintConfig.apiUrl}'
        '/api/v1/vendoremployee/urbanpiper/get-order-details';

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _log('🌐 Aggregator fetch (attempt $attempt/$maxAttempts) orderId=$orderId');

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'X-localization': 'en',
            'Authorization': 'Bearer ${PrintConfig.authToken}',
          },
          body: jsonEncode({'order_id': int.tryParse(orderId) ?? orderId}),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode != 200) {
          _log('❌ Aggregator API error: ${response.statusCode} (attempt $attempt)');
          if (attempt < maxAttempts) continue;
          return null;
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>;

        if (json['orders'] == null) {
          _log('❌ Aggregator response missing "orders" key (attempt $attempt)');
          if (attempt < maxAttempts) continue;
          return null;
        }

        _log('✅ Aggregator order fetched');
        return json;
      } catch (e) {
        _log('❌ Aggregator fetch error (attempt $attempt): $e');
        if (attempt == maxAttempts) return null;
      }
    }
    return null;
  }

  void connect() {
    _socket = IO.io(PrintConfig.serverUrl, <String, dynamic>{
      'transports':           ['websocket'],
      'autoConnect':          false,
      'reconnection':         true,
      'reconnectionDelay':    2000,
      'reconnectionAttempts': 999999,
    });

    _socket!.onConnect((_) {
      _connected = true;
      _statusController.add(true);
      _log('✅ Connected to ${PrintConfig.serverUrl}');
      _registerListeners();
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      _statusController.add(false);
      _log('❌ Disconnected — retrying...');
    });

    _socket!.onReconnect((_) {
      _log('♻️ Reconnected — re-registering listeners');
      _registerListeners();
    });

    _socket!.onError((e) => _log('⚠️ Socket error: $e'));
    _socket!.connect();
  }

  void _registerListeners() {
    final restaurantId = PrintConfig.restaurantId.toString();

    // ═══════════════════════════════════════════════════════════════════
    // NEW ORDER / UPDATE ORDER
    // ═══════════════════════════════════════════════════════════════════
    _socket!.off('new_order_$restaurantId');
    _socket!.on('new_order_$restaurantId', (data) {
      log('📡 Received new_order_$restaurantId : $data');
      try {
        final payload   = data as List<dynamic>;
        final eventType = payload[0].toString();

        // ── GATE 1: Event type check ──────────────────────────────────
        if (eventType != 'new-order' &&
            eventType != 'scan-new-order' &&
            eventType != 'update-order' &&
            eventType != 'update-order-status') return;

        // ── GATE 2: Restaurant check ──────────────────────────────────
        if ('${payload[2]}' != restaurantId) return;

        if (payload.length < 5 || payload[4] == null) {
          _log('⚠️ No order JSON in data[4]');
          return;
        }

        final rawPayload =
            payload[4] is String ? jsonDecode(payload[4]) : payload[4];

        final orderMap = (rawPayload is Map && rawPayload['orders'] != null)
            ? (rawPayload['orders'] as List).first
            : rawPayload as Map<String, dynamic>;

        final order = RestaurantOrder.fromJson(orderMap);

        // ── GATE 3: Auto print check ──────────────────────────────────
        if (!PrintConfig.autoPrint) {
          _log('⏸️ Auto print OFF — skip #${order.displayOrderId}');
          return;
        }

        // ── GATE 4: printKot check ────────────────────────────────────
        if (order.printKot != 'Yes') {
          _log('⏩ print_kot=${order.printKot} — skip #${order.displayOrderId}');
          return;
        }

        _printedIds.add(order.orderId);

        // ── GATE 5: printer_agent array ───────────────────────────────
        final agentList = ((rawPayload as Map<String, dynamic>)['printer_agent']
                as List<dynamic>? ?? []);

        if (agentList.isEmpty) {
          _log('⏩ printer_agent missing — skip #${order.displayOrderId}');
          return;
        }

        _log('📋 printer_agent count: ${agentList.length}');

        // ── GATE 6: Filter agents for this device ─────────────────────
        final myEmpId  = PrintConfig.empId.trim();
        final myAgents = agentList
            .cast<Map<String, dynamic>>()
            .where((a) => a['printer_agent_id']?.toString().trim() == myEmpId)
            .toList();

        if (myAgents.isEmpty) {
          _log('⏩ No agents for empId=$myEmpId — skip #${order.displayOrderId}');
          return;
        }

        _log('✅ Matched agents: ${myAgents.map((a) => a['station']).toList()} for empId=$myEmpId');

        // ── Resolve items to print ────────────────────────────────────
        final List<OrderItem> itemsToPrint;
        if (eventType == 'update-order') {
          final newlyAdded = rawPayload['newly_added_items'] as List<dynamic>?;
          if (newlyAdded == null || newlyAdded.isEmpty) {
            _log('⏩ update-order but no newly_added_items — skip #${order.displayOrderId}');
            return;
          }
          itemsToPrint = newlyAdded
              .cast<Map<String, dynamic>>()
              .map((e) => OrderItem.fromJson(e))
              .toList();
          _log('📦 update-order: ${itemsToPrint.length} newly added items');
        } else if (eventType == 'update-order-status') {
          final cancelledRaw = rawPayload['cancelled_items'] as List<dynamic>?;
          if (cancelledRaw == null || cancelledRaw.isEmpty) {
            _log('⏩ No cancelled_items — skip #${order.displayOrderId}');
            return;
          }
          itemsToPrint = cancelledRaw
              .cast<Map<String, dynamic>>()
              .map((e) => OrderItem.fromJson(e))
              .toList();
          _log('🚫 cancelled_items: ${itemsToPrint.length}');
        } else {
          itemsToPrint = order.items;
        }

        // ── GATE 7: Per station → router → enqueue ────────────────────
        for (final agent in myAgents) {
          final station = agent['station'].toString().toUpperCase().trim();

          final stationItems = itemsToPrint
              .where((i) => i.station?.trim().toUpperCase() == station)
              .toList();

          if (stationItems.isEmpty) {
            _log('⏩ No items for station=$station — skip');
            continue;
          }

          // Ask router which printer(s) handle this station
          final printerIds = _router.resolveForStation(station);
          if (printerIds.isEmpty) continue; // warning already logged by router

          final stationOrder = RestaurantOrder(
            orderId:        order.orderId,
            displayOrderId: order.displayOrderId,
            tableId:        order.tableId,
            tableName:      order.tableName,
            waiterName:     order.waiterName,
            orderAmount:    stationItems.fold(0.0, (sum, i) => sum + (i.price * i.quantity)),
            orderNote:      order.orderNote,
            orderType:      order.orderType,
            printKot:       order.printKot,
            restaurantName: order.restaurantName,
            receivedAt:     order.receivedAt,
            userCustName:   order.userCustName,
            userCustPhone:  order.userCustPhone,
            dailyToken:     order.dailyToken,
            items:          stationItems,
          );

          final jobType = eventType == 'update-order-status'
              ? PrintType.cancelKot
              : PrintType.kot;

          for (final printerId in printerIds) {
            _queueManager.route(PrintJob(
              type:         jobType,
              printerId:    printerId,
              order:        stationOrder,
              stationLabel: station,
            ));
          }

          final label = jobType == PrintType.cancelKot ? '🚫 Queued CANCEL KOT' : '🖨️ Queued KOT';
          _log('$label [$station] → ${printerIds.join(', ')} (${stationItems.length} items) #${order.displayOrderId}');
        }
      } catch (e) {
        _log('❌ new_order parse error: $e');
      }
    });

    // ═══════════════════════════════════════════════════════════════════
    // MANUAL PRINT
    // ═══════════════════════════════════════════════════════════════════
    _socket!.off('manually_print_$restaurantId');
    _socket!.on('manually_print_$restaurantId', (data) async {
      _log('📡 Received manually_print_$restaurantId : $data');
      try {
        final payload       = data as List<dynamic>;
        final printType     = payload[0].toString().toLowerCase();
        final orderId       = payload[1].toString();
        final socketRestId  = payload[2].toString();

        // ── GATE 1: Restaurant check ──────────────────────────────────
        if (socketRestId != restaurantId) return;

        // ── BILL ──────────────────────────────────────────────────────
        if (printType == 'bill') {
          if (!PrintConfig.autoPrintBill) {
            _log('⏸️ Auto Bill print OFF — skip #$orderId');
            return;
          }

          _log('🧾 Manual bill for order #$orderId — fetching from API...');

          final rawData = await _fetchOrderRaw(orderId);
          if (rawData == null) {
            _log('❌ Could not fetch order #$orderId');
            return;
          }

          // Verify this device has a BILL station in printer_agent
          final agentList = (rawData['printer_agent'] as List<dynamic>? ?? []);
          final billAgent = agentList.cast<Map<String, dynamic>>().firstWhere(
            (a) =>
                a['printer_agent_id']?.toString() == PrintConfig.empId &&
                a['station']?.toString().toUpperCase() == 'BILL',
            orElse: () => {},
          );

          if (billAgent.isEmpty) {
            _log('⏩ No BILL agent for empId=${PrintConfig.empId} — not my bill, skip');
            return;
          }

          _log('✅ BILL agent matched — empId=${PrintConfig.empId}');

          final order = RestaurantOrder.fromTempApi(rawData);

          // Ask router which printer(s) handle bills
          final printerIds = _router.resolveForBill();
          if (printerIds.isEmpty) return;

          for (final printerId in printerIds) {
            _queueManager.route(PrintJob(
              type:      PrintType.bill,
              printerId: printerId,
              order:     order,
            ));
          }
          _log('🧾 Manual Bill queued → ${printerIds.join(', ')} #$orderId');
          return;
        }

        // ── KOT ───────────────────────────────────────────────────────
        if (printType == 'kot') {
          _log('🖨️ Manual KOT for order #$orderId — fetching from API...');

          final rawData = await _fetchOrderRaw(orderId);
          if (rawData == null) {
            _log('❌ Could not fetch order #$orderId');
            return;
          }

          final socketStationsRaw = payload.length > 3 ? payload[3].toString() : '';
          final socketStations = socketStationsRaw
              .split(',')
              .map((s) => s.trim().toUpperCase())
              .where((s) => s.isNotEmpty)
              .toSet();

          _log('📋 Socket stations from event: $socketStations');

          final agentList = (rawData['printer_agent'] as List<dynamic>? ?? []);
          final myAgents  = agentList
              .cast<Map<String, dynamic>>()
              .where((a) =>
                  a['printer_agent_id']?.toString() == PrintConfig.empId &&
                  a['station']?.toString().toUpperCase() != 'BILL' &&
                  socketStations.contains(a['station']?.toString().toUpperCase()))
              .toList();

          if (myAgents.isEmpty) {
            _log('⏩ No matching KOT agents for empId=${PrintConfig.empId} — skip');
            return;
          }

          _log('✅ Matched agents: ${myAgents.map((a) => a['station'])}');

          for (final agent in myAgents) {
            final station = agent['station'].toString().toUpperCase();

            final stationOrder = RestaurantOrder.fromTempKdsApi(
              rawData,
              stationFilter: station,
            );

            if (stationOrder.items.isEmpty) {
              _log('⏩ No items for station $station — skip');
              continue;
            }

            // Ask router which printer(s) handle this station
            final printerIds = _router.resolveForStation(station);
            if (printerIds.isEmpty) continue;

            for (final printerId in printerIds) {
              _queueManager.route(PrintJob(
                type:         PrintType.kot,
                printerId:    printerId,
                order:        stationOrder,
                stationLabel: station,
              ));
            }

            _log('🖨️ KOT queued [$station] → ${printerIds.join(', ')} (${stationOrder.items.length} items) #$orderId');
          }
        }
      } catch (e) {
        _log('❌ manually_print error: $e');
      }
    });

    _log('👂 Listening: new_order_$restaurantId');
    _log('👂 Listening: manually_print_$restaurantId');

    // ═══════════════════════════════════════════════════════════════════
    // AGGREGATOR ORDER UPDATE
    // ═══════════════════════════════════════════════════════════════════
    _socket!.off('aggregator_order_$restaurantId');
    _socket!.on('aggregator_order_$restaurantId', (data) async {
      _log('📡 Received aggregator_order_$restaurantId : $data');
      try {
        final payload    = data as List<dynamic>;
        final eventType  = payload[0].toString();
        final orderId    = payload[1].toString();
        final socketRestId = payload[2].toString();
        final status     = payload.length > 3 ? payload[3].toString() : '';

        // ── GATE 1: Event type ────────────────────────────────────────
        if (eventType != 'aggrigator-order-update') return;

        // ── GATE 2: Restaurant check ──────────────────────────────────
        if (socketRestId != restaurantId) return;

        // ── GATE 3: Only on Acknowledged ─────────────────────────────
        if (status != 'Acknowledged') {
          _log('⏩ Aggregator status=$status — only print on Acknowledged, skip');
          return;
        }

        // ── GATE 4: At least one toggle ON ────────────────────────────
        if (!PrintConfig.aggregatorAutoKot && !PrintConfig.aggregatorAutoBill) {
          _log('⏸️ Aggregator Auto KOT & Bill both OFF — skip #$orderId');
          return;
        }

        // ── GATE 5: Deduplication ─────────────────────────────────────
        final orderIdInt = int.tryParse(orderId) ?? 0;
        if (_printedIds.contains(orderIdInt)) {
          _log('⏩ Aggregator order #$orderId already printed — skip duplicate');
          return;
        }
        _printedIds.add(orderIdInt);

        // ── Fetch order from aggregator API ───────────────────────────
        _log('🌐 Fetching aggregator order #$orderId...');
        final rawJson = await _fetchAggregatorOrder(orderId);
        if (rawJson == null) {
          _log('❌ Could not fetch aggregator order #$orderId');
          return;
        }

        final order = RestaurantOrder.fromAggregatorApi(rawJson);

        // ── KOT ───────────────────────────────────────────────────────
        if (PrintConfig.aggregatorAutoKot) {
          // Group items by station
          final stationGroups = <String, List<OrderItem>>{};
          for (final item in order.items) {
            final st = item.station?.trim().toUpperCase() ?? 'KDS';
            stationGroups.putIfAbsent(st, () => []).add(item);
          }

          for (final station in stationGroups.keys) {
            final stationItems = stationGroups[station]!;
            final printerIds   = _router.resolveForStation(station);
            if (printerIds.isEmpty) {
              _log('⚠️ No printer configured for station=$station');
              continue;
            }

            final stationOrder = RestaurantOrder(
              orderId:        order.orderId,
              displayOrderId: order.displayOrderId,
              tableId:        order.tableId,
              tableName:      order.tableName,
              waiterName:     order.waiterName,
              orderAmount:    stationItems.fold(0.0, (s, i) => s + i.price * i.quantity),
              orderNote:      order.orderNote,
              orderType:      order.orderType,
              printKot:       'Yes',
              restaurantName: order.restaurantName,
              receivedAt:     order.receivedAt,
              userCustName:   order.userCustName,
              userCustPhone:  order.userCustPhone,
              dailyToken:     order.dailyToken,
              items:          stationItems,
            );

            for (final printerId in printerIds) {
              _queueManager.route(PrintJob(
                type:         PrintType.kot,
                printerId:    printerId,
                order:        stationOrder,
                stationLabel: station,
              ));
            }
            _log('🖨️ Aggregator KOT [$station] → ${printerIds.join(', ')} (${stationItems.length} items) #$orderId');
          }
        }

        // ── Bill ──────────────────────────────────────────────────────
        if (PrintConfig.aggregatorAutoBill) {
          final printerIds = _router.resolveForBill();
          if (printerIds.isEmpty) {
            _log('⚠️ No printer configured for bill');
          } else {
            for (final printerId in printerIds) {
              _queueManager.route(PrintJob(
                type:      PrintType.bill,
                printerId: printerId,
                order:     order,
              ));
            }
            _log('🧾 Aggregator Bill queued → ${printerIds.join(', ')} #$orderId');
          }
        }
      } catch (e) {
        _log('❌ aggregator_order error: $e');
      }
    });

    _log('👂 Listening: aggregator_order_$restaurantId');
  }

  void _log(String msg) {
    print('[WinSocket] $msg');
    _logController.add(msg);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _logController.close();
    _statusController.close();
  }
}
