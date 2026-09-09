import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:printer_agent/core/auth/auth_session_monitor.dart';
import 'package:printer_agent/core/models/order_item.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../queue/print_queue_manager.dart';
import '../router/printer_router.dart';
import '../models/print_job.dart';
import '../models/restaurant_order.dart';
import '../config/print_config.dart';
import '../config/app_constants.dart';
import '../printer/kot_separate_ticket.dart';
import '../services/printer_agent_config_sync_service.dart';

class WindowsSocketService {
  IO.Socket? _socket;
  final PrintQueueManager _queueManager;
  final PrinterRouter _router;
  final Set<int> _printedIds = {};
  final Set<int> _cancelledPrintedIds = {};
  final Set<int> _socketBillPrintedIds = {};
  final Set<int> _aggregatorBillPrintedIds = {};

  bool _connected = false;
  bool get isConnected => _connected;

  /// True while a socket-pushed config apply is in progress (avoids overlapping applies).
  bool _applyingConfig = false;

  final _logController = StreamController<String>.broadcast();
  final _statusController = StreamController<bool>.broadcast();
  final _configUpdatedController = StreamController<void>.broadcast();

  Stream<String> get logStream => _logController.stream;
  Stream<bool> get statusStream => _statusController.stream;

  /// Fires after a `printer_agent_config_*` push was applied to local storage.
  /// Home should rebuild queue/router/socket (same as manual refresh).
  Stream<void> get configUpdatedStream => _configUpdatedController.stream;

  WindowsSocketService(this._queueManager, this._router);

  Future<Map<String, dynamic>?> _fetchOrderRaw(String orderId) async {
    const maxAttempts = 3; // 1 initial + 2 retries
    final url = '${AppConstants.apiUrl}'
        '/api/v2/vendoremployee/order-temp-details'
        '?order_id=$orderId';

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _log('🌐 Fetching (attempt $attempt/$maxAttempts): $url');
        _log('🔑 token: ${PrintConfig.authToken}');

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${PrintConfig.authToken}',
          },
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 401) {
          _log('❌ 401 Unauthorized — session invalid, aborting retries');
          AuthSessionMonitor.instance.notifyExpired();
          return null;
        }

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

        if (billData['station_gst_details'] == null) {
          if (json['station_gst_details'] != null) {
            billData['station_gst_details'] = json['station_gst_details'];
          } else if (details is Map && details['station_gst_details'] != null) {
            billData['station_gst_details'] = details['station_gst_details'];
          }
        }

        return {
          ...Map<String, dynamic>.from(details),
          'bill': billData,
          'kds': kdsData,
          if (json['station_gst_details'] != null)
            'station_gst_details': json['station_gst_details'],
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
    final url = '${AppConstants.apiUrl}'
        '/api/v1/vendoremployee/urbanpiper/get-order-details';

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _log(
            '🌐 Aggregator fetch (attempt $attempt/$maxAttempts) orderId=$orderId');
        _log('🔑 token: ${PrintConfig.authToken}');

        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json; charset=UTF-8',
                'X-localization': 'en',
                'Authorization': 'Bearer ${PrintConfig.authToken}',
              },
              body: jsonEncode({'order_id': int.tryParse(orderId) ?? orderId}),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 401) {
          _log('❌ Aggregator 401 Unauthorized — session invalid, aborting retries');
          AuthSessionMonitor.instance.notifyExpired();
          return null;
        }

        if (response.statusCode != 200) {
          _log(
              '❌ Aggregator API error: ${response.statusCode} (attempt $attempt)');
          if (attempt < maxAttempts) continue;
          return null;
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        print('=====> Aggregator $orderId response: $json');

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
    _socket = IO.io(AppConstants.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionDelay': 2000,
      'reconnectionAttempts': 999999,
    });

    _socket!.onConnect((_) {
      _connected = true;
      _statusController.add(true);
      _log('✅ Connected to ${AppConstants.socketUrl}');

      // Join restaurant room on every connect/reconnect.
      _socket!.emit('join_restaurant', {
        'restaurant_id': PrintConfig.restaurantId,
      });

      _registerListeners();
    });

    _socket!.on('joined_restaurant', (data) {
      _log('🏠 Joined room: ${data['room']}');
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      _statusController.add(false);
      _log('❌ Disconnected — retrying...');
    });

    _socket!.onReconnect((_) {
      _log('♻️ Reconnected — re-registering listeners');
      // _registerListeners();
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
    _socket!.on('new_order_$restaurantId', (data) async {
      log('📡 Received new_order_$restaurantId : $data');
      try {
        final payload = data as List<dynamic>;
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

        final orderMapRaw = (rawPayload is Map && rawPayload['orders'] != null)
            ? (rawPayload['orders'] as List).first
            : rawPayload;
        final orderMap = Map<String, dynamic>.from(orderMapRaw as Map);

        final order = RestaurantOrder.fromJson(orderMap);

        // ── GATE 3: Auto print check ──────────────────────────────────
        // Cancel KOT uses its own toggle; normal KOT uses Auto Print KOT.
        if (eventType == 'update-order-status') {
          if (!PrintConfig.autoPrintCancelKot) {
            _log(
                '⏸️ Auto Print Cancel KOT OFF — skip #${order.displayOrderId}');
            return;
          }
        } else if (!PrintConfig.autoPrint) {
          _log('⏸️ Auto print OFF — skip #${order.displayOrderId}');
          return;
        }

        // ── Socket auto-bill (new-order only) ─────────────────────────
        // Requires auto-settle + bill flags Yes + BILL printer_agent match.
        // Deferred until the KOTs finish so the kitchen ticket prints first;
        // every early return below still queues it exactly once.
        final agentList = (rawPayload is Map
            ? rawPayload['printer_agent'] as List<dynamic>? ?? <dynamic>[]
            : <dynamic>[]);

        var billQueued = false;
        void queueBillNow() {
          if (billQueued || eventType != 'new-order') return;
          billQueued = true;
          _tryQueueSocketAutoBill(orderMap, order, agentList);
        }

        // ── GATE 4: printKot check ────────────────────────────────────
        if (order.printKot != 'Yes') {
          _log('⏩ print_kot=${order.printKot} — skip #${order.displayOrderId}');
          queueBillNow();
          return;
        }

        _printedIds.add(order.orderId);

        // ── scan-new-order: bypass printer_agent, use Scan Order Auto Print toggle ──
        if (eventType == 'scan-new-order') {
          if (!PrintConfig.scanOrderAutoPrint) {
            _log(
                '⏸️ Scan Order Auto Print OFF — skip #${order.displayOrderId}');
            return;
          }

          final stationGroups = <String, List<OrderItem>>{};
          for (final item in order.items) {
            final st = item.station?.trim().toUpperCase() ?? 'KDS';
            stationGroups.putIfAbsent(st, () => []).add(item);
          }

          for (final station in stationGroups.keys) {
            final stationItems = stationGroups[station]!;
            final printerIds = _router.resolveForStation(station);
            if (printerIds.isEmpty) {
              _log('⚠️ No printer configured for station=$station');
              continue;
            }

            final stationOrder = RestaurantOrder(
              orderId: order.orderId,
              displayOrderId: order.displayOrderId,
              tableId: order.tableId,
              tableName: order.tableName,
              waiterName: order.waiterName,
              orderAmount: stationItems.fold(
                  0.0, (sum, i) => sum + (i.price * i.quantity)),
              orderNote: order.orderNote,
              orderType: order.orderType,
              printKot: order.printKot,
              restaurantName: order.restaurantName,
              receivedAt: order.receivedAt,
              userCustName: order.userCustName,
              userCustPhone: order.userCustPhone,
              dailyToken: order.dailyToken,
              items: stationItems,
            );

            KotSeparateTicket.queue(
              queueManager: _queueManager,
              printerIds: printerIds,
              type: PrintType.kot,
              order: stationOrder,
              stationLabel: station,
            );
            _log(
                '🖨️ Scan KOT [$station] → ${printerIds.join(', ')} (${stationItems.length} items) #${order.displayOrderId}');
          }
          return;
        }

        // ── update-order from web: bypass printer_agent, use Scan Order Auto Print ──
        final isWebSource =
            payload.length > 5 && payload[5].toString().trim() == 'web';
        if (eventType == 'update-order' && isWebSource) {
          if (!PrintConfig.scanOrderAutoPrint) {
            _log(
                '⏸️ Scan Order Auto Print OFF — skip web update-order #${order.displayOrderId}');
            return;
          }

          final newlyAdded = rawPayload is Map
              ? rawPayload['newly_added_items'] as List<dynamic>?
              : null;
          if (newlyAdded == null || newlyAdded.isEmpty) {
            _log(
                '⏩ web update-order but no newly_added_items — skip #${order.displayOrderId}');
            return;
          }

          final itemsToPrint = newlyAdded
              .cast<Map<String, dynamic>>()
              .map((e) => OrderItem.fromJson(e))
              .toList();
          _log(
              '📦 web update-order: ${itemsToPrint.length} newly added items #${order.displayOrderId}');

          final stationGroups = <String, List<OrderItem>>{};
          for (final item in itemsToPrint) {
            final st = item.station?.trim().toUpperCase() ?? 'KDS';
            stationGroups.putIfAbsent(st, () => []).add(item);
          }

          for (final station in stationGroups.keys) {
            final stationItems = stationGroups[station]!;
            final printerIds = _router.resolveForStation(station);
            if (printerIds.isEmpty) {
              _log('⚠️ No printer configured for station=$station');
              continue;
            }

            final stationOrder = RestaurantOrder(
              orderId: order.orderId,
              displayOrderId: order.displayOrderId,
              tableId: order.tableId,
              tableName: order.tableName,
              waiterName: order.waiterName,
              orderAmount: stationItems.fold(
                  0.0, (sum, i) => sum + (i.price * i.quantity)),
              orderNote: order.orderNote,
              orderType: order.orderType,
              printKot: order.printKot,
              restaurantName: order.restaurantName,
              receivedAt: order.receivedAt,
              userCustName: order.userCustName,
              userCustPhone: order.userCustPhone,
              dailyToken: order.dailyToken,
              items: stationItems,
            );

            KotSeparateTicket.queue(
              queueManager: _queueManager,
              printerIds: printerIds,
              type: PrintType.kot,
              order: stationOrder,
              stationLabel: station,
            );
            _log(
                '🖨️ Web update KOT [$station] → ${printerIds.join(', ')} (${stationItems.length} items) #${order.displayOrderId}');
          }
          return;
        }

        // ── GATE 5: printer_agent array ───────────────────────────────
        if (agentList.isEmpty) {
          _log('⏩ printer_agent missing — skip #${order.displayOrderId}');
          queueBillNow();
          return;
        }

        _log('📋 printer_agent count: ${agentList.length}');

        // ── GATE 6: Filter agents for this device ─────────────────────
        final myEmpId = PrintConfig.empId.trim();
        final myAgents = agentList
            .cast<Map<String, dynamic>>()
            .where((a) => a['printer_agent_id']?.toString().trim() == myEmpId)
            .toList();

        if (myAgents.isEmpty) {
          _log(
              '⏩ No agents for empId=$myEmpId — skip #${order.displayOrderId}');
          queueBillNow();
          return;
        }

        _log(
            '✅ Matched agents: ${myAgents.map((a) => a['station']).toList()} for empId=$myEmpId');

        // ── Resolve items to print ────────────────────────────────────
        final List<OrderItem> itemsToPrint;
        if (eventType == 'update-order') {
          final newlyAdded = rawPayload['newly_added_items'] as List<dynamic>?;
          if (newlyAdded == null || newlyAdded.isEmpty) {
            _log(
                '⏩ update-order but no newly_added_items — skip #${order.displayOrderId}');
            queueBillNow();
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
            queueBillNow();
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
        final kotJobs = <PrintJob>[];

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
            orderId: order.orderId,
            displayOrderId: order.displayOrderId,
            tableId: order.tableId,
            tableName: order.tableName,
            waiterName: order.waiterName,
            orderAmount: stationItems.fold(
                0.0, (sum, i) => sum + (i.price * i.quantity)),
            orderNote: order.orderNote,
            orderType: order.orderType,
            printKot: order.printKot,
            restaurantName: order.restaurantName,
            receivedAt: order.receivedAt,
            userCustName: order.userCustName,
            userCustPhone: order.userCustPhone,
            dailyToken: order.dailyToken,
            items: stationItems,
          );

          final jobType = eventType == 'update-order-status'
              ? PrintType.cancelKot
              : PrintType.kot;

          kotJobs.addAll(KotSeparateTicket.queue(
            queueManager: _queueManager,
            printerIds: printerIds,
            type: jobType,
            order: stationOrder,
            stationLabel: station,
          ));

          final label = jobType == PrintType.cancelKot
              ? '🚫 Queued CANCEL KOT'
              : '🖨️ Queued KOT';
          _log(
              '$label [$station] → ${printerIds.join(', ')} (${stationItems.length} items) #${order.displayOrderId}');
        }

        // ── Bill after KOTs reach a terminal state ────────────────────
        if (kotJobs.isNotEmpty) {
          _log(
              '⏳ Waiting for ${kotJobs.length} KOT job(s) before bill #${order.displayOrderId}');
          await Future.wait(kotJobs.map((j) => j.completed));
        }
        queueBillNow();
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
        final payload = data as List<dynamic>;
        final printType = payload[0].toString().toLowerCase();
        final orderId = payload[1].toString();
        final socketRestId = payload[2].toString();

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
            _log(
                '⏩ No BILL agent for empId=${PrintConfig.empId} — not my bill, skip');
            return;
          }

          _log('✅ BILL agent matched — empId=${PrintConfig.empId}');

          final order = RestaurantOrder.fromTempApi(rawData);

          // Ask router which printer(s) handle bills
          final printerIds = _router.resolveForBill();
          if (printerIds.isEmpty) return;

          for (final printerId in printerIds) {
            _queueManager.route(PrintJob(
              type: PrintType.bill,
              printerId: printerId,
              order: order,
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

          final socketStationsRaw =
              payload.length > 3 ? payload[3].toString() : '';
          final socketStations = socketStationsRaw
              .split(',')
              .map((s) => s.trim().toUpperCase())
              .where((s) => s.isNotEmpty)
              .toSet();

          _log('📋 Socket stations from event: $socketStations');

          final agentList = (rawData['printer_agent'] as List<dynamic>? ?? []);
          final myAgents = agentList
              .cast<Map<String, dynamic>>()
              .where((a) =>
                  a['printer_agent_id']?.toString() == PrintConfig.empId &&
                  a['station']?.toString().toUpperCase() != 'BILL' &&
                  socketStations
                      .contains(a['station']?.toString().toUpperCase()))
              .toList();

          if (myAgents.isEmpty) {
            _log(
                '⏩ No matching KOT agents for empId=${PrintConfig.empId} — skip');
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

            KotSeparateTicket.queue(
              queueManager: _queueManager,
              printerIds: printerIds,
              type: PrintType.kot,
              order: stationOrder,
              stationLabel: station,
            );

            _log(
                '🖨️ KOT queued [$station] → ${printerIds.join(', ')} (${stationOrder.items.length} items) #$orderId');
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
        final payload = data as List<dynamic>;
        final eventType = payload[0].toString();
        final orderId = payload[1].toString();
        final socketRestId = payload[2].toString();
        final status = payload.length > 3 ? payload[3].toString() : '';

        // ── GATE 1: Event type ────────────────────────────────────────
        if (eventType != 'aggrigator-order-update') return;

        // ── GATE 2: Restaurant check ──────────────────────────────────
        if (socketRestId != restaurantId) return;

        // ── GATE 3: Acknowledged / Food Ready / Cancelled ─────────────
        if (status != 'Acknowledged' &&
            status != 'Cancelled' &&
            status != 'Food Ready') {
          _log(
              '⏩ Aggregator status=$status — skip (only Acknowledged / Food Ready / Cancelled)');
          return;
        }

        final orderIdInt = int.tryParse(orderId) ?? 0;

        // ═══════════════════════════════════════════════════════════════
        // CANCELLED → Cancel KOT (gated by Aggregator Auto KOT)
        // ═══════════════════════════════════════════════════════════════
        if (status == 'Cancelled') {
          if (!PrintConfig.aggregatorAutoKot) {
            _log('⏸️ Aggregator Auto KOT OFF — skip cancel #$orderId');
            return;
          }

          if (_cancelledPrintedIds.contains(orderIdInt)) {
            _log(
                '⏩ Aggregator cancel #$orderId already printed — skip duplicate');
            return;
          }

          _log('🌐 Fetching aggregator order #$orderId (cancel)...');
          final rawJson = await _fetchAggregatorOrder(orderId);
          if (rawJson == null) {
            _log('❌ Could not fetch aggregator order #$orderId');
            return;
          }

          // GATE: f_order_status must be 3
          final ordersRoot = rawJson['orders'];
          final orderInfo =
              ordersRoot is Map ? ordersRoot['order_details_order'] : null;
          final fOrderStatus = orderInfo is Map
              ? (orderInfo['f_order_status'] is int
                  ? orderInfo['f_order_status'] as int
                  : int.tryParse(orderInfo['f_order_status']?.toString() ?? ''))
              : null;
          if (fOrderStatus != 3) {
            _log(
                '⏩ Aggregator cancel #$orderId f_order_status=$fOrderStatus — skip (need 3)');
            return;
          }

          _cancelledPrintedIds.add(orderIdInt);

          final order = RestaurantOrder.fromAggregatorApi(rawJson);
          _queueAggregatorStationJobs(
            order,
            orderId,
            jobType: PrintType.cancelKot,
            logLabel: '🚫 Aggregator CANCEL KOT',
          );
          return;
        }

        // ═══════════════════════════════════════════════════════════════
        // FOOD READY → Bill only (if stage = Food Ready)
        // ═══════════════════════════════════════════════════════════════
        if (status == 'Food Ready') {
          if (!PrintConfig.aggregatorAutoBill) {
            _log('⏸️ Aggregator Auto Bill OFF — skip Food Ready #$orderId');
            return;
          }
          if (PrintConfig.aggregatorAutoBillStage != 'Food Ready') {
            _log(
                '⏩ Aggregator Food Ready #$orderId — bill stage=${PrintConfig.aggregatorAutoBillStage} — skip');
            return;
          }
          if (_aggregatorBillPrintedIds.contains(orderIdInt)) {
            _log(
                '⏩ Aggregator bill #$orderId already printed — skip duplicate');
            return;
          }

          _log('🌐 Fetching aggregator order #$orderId (Food Ready bill)...');
          final rawJson = await _fetchAggregatorOrder(orderId);
          if (rawJson == null) {
            _log('❌ Could not fetch aggregator order #$orderId');
            return;
          }

          _aggregatorBillPrintedIds.add(orderIdInt);
          final order = RestaurantOrder.fromAggregatorApi(rawJson);
          _queueAggregatorBill(order, orderId);
          return;
        }

        // ═══════════════════════════════════════════════════════════════
        // ACKNOWLEDGED → KOT + Bill (if stage = Acknowledged)
        // ═══════════════════════════════════════════════════════════════
        final shouldPrintKot = PrintConfig.aggregatorAutoKot;
        final shouldPrintBill = PrintConfig.aggregatorAutoBill &&
            PrintConfig.aggregatorAutoBillStage == 'Acknowledged';

        if (!shouldPrintKot && !shouldPrintBill) {
          _log(
              '⏸️ Aggregator Acknowledged #$orderId — nothing to print '
              '(kot=${PrintConfig.aggregatorAutoKot}, '
              'bill=${PrintConfig.aggregatorAutoBill}, '
              'stage=${PrintConfig.aggregatorAutoBillStage})');
          return;
        }

        final needKot =
            shouldPrintKot && !_printedIds.contains(orderIdInt);
        final needBill = shouldPrintBill &&
            !_aggregatorBillPrintedIds.contains(orderIdInt);

        if (!needKot && !needBill) {
          _log(
              '⏩ Aggregator Acknowledged #$orderId already printed — skip duplicate');
          return;
        }

        _log('🌐 Fetching aggregator order #$orderId...');
        final rawJson = await _fetchAggregatorOrder(orderId);
        if (rawJson == null) {
          _log('❌ Could not fetch aggregator order #$orderId');
          return;
        }

        final order = RestaurantOrder.fromAggregatorApi(rawJson);

        if (needKot) {
          _printedIds.add(orderIdInt);
          _queueAggregatorStationJobs(
            order,
            orderId,
            jobType: PrintType.kot,
            logLabel: '🖨️ Aggregator KOT',
          );
        }

        if (needBill) {
          _aggregatorBillPrintedIds.add(orderIdInt);
          _queueAggregatorBill(order, orderId);
        }
      } catch (e) {
        _log('❌ aggregator_order error: $e');
      }
    });

    _log('👂 Listening: aggregator_order_$restaurantId');

    // ═══════════════════════════════════════════════════════════════════
    // MANUAL AGGREGATOR PRINT
    // ═══════════════════════════════════════════════════════════════════
    _socket!.off('manually_print_aggregator_$restaurantId');
    _socket!.on('manually_print_aggregator_$restaurantId', (data) async {
      _log('📡 Received manually_print_aggregator_$restaurantId : $data');
      try {
        final payload = data as List<dynamic>;
        final eventType = payload[0].toString().toLowerCase();
        final orderId = payload[1].toString();
        final socketRestId = payload[2].toString();
        final printType =
            payload.length > 3 ? payload[3].toString().toLowerCase() : '';

        if (eventType != 'manually_print_aggregator') return;
        if (socketRestId != restaurantId) return;

        if (printType != 'aggr_kot' && printType != 'aggr_bill') {
          _log('⏩ Unknown aggregator print type: $printType — skip #$orderId');
          return;
        }

        _log('🌐 Manual aggregator $printType for order #$orderId — fetching...');
        final rawJson = await _fetchAggregatorOrder(orderId);
        if (rawJson == null) {
          _log('❌ Could not fetch aggregator order #$orderId');
          return;
        }

        final order = RestaurantOrder.fromAggregatorApi(rawJson);

        if (printType == 'aggr_kot') {
          _queueAggregatorStationJobs(
            order,
            orderId,
            jobType: PrintType.kot,
            logLabel: '🖨️ Manual Aggregator KOT',
          );
        } else {
          _queueAggregatorBill(
            order,
            orderId,
            logLabel: '🧾 Manual Aggregator Bill',
          );
        }
      } catch (e) {
        _log('❌ manually_print_aggregator error: $e');
      }
    });

    _log('👂 Listening: manually_print_aggregator_$restaurantId');

    // ═══════════════════════════════════════════════════════════════════
    // PRINTER AGENT CONFIG (push from server when config is saved)
    // ═══════════════════════════════════════════════════════════════════
    final configChannel = 'printer_agent_config_$restaurantId';
    _socket!.off(configChannel);
    _socket!.on(configChannel, (data) async {
      print('📡 Received $configChannel : $data');
      if (_applyingConfig) {
        _log('⏩ printer_agent_config — apply already in progress, skip');
        return;
      }
      try {
        final dynamic raw = data is String ? jsonDecode(data) : data;
        if (raw is! Map) {
          _log('⚠️ printer_agent_config — payload is not a Map');
          return;
        }

        final body = Map<String, dynamic>.from(raw);
        final configData = body['data'] is Map
            ? Map<String, dynamic>.from(body['data'] as Map)
            : body;

        final rid = body['restaurant_id'] ?? configData['restaurant_id'];
        if (rid != null && '$rid' != restaurantId) {
          _log('⏩ printer_agent_config — restaurant mismatch ($rid), skip');
          return;
        }

        // Apply whatever arrives, including a different employee_id.
        // final empId = configData['employee_id']?.toString();
        // if (empId != null &&
        //     empId.trim().isNotEmpty &&
        //     empId.trim() != PrintConfig.empId.trim()) {
        //   _log(
        //       '⏩ printer_agent_config — empId mismatch ($empId vs ${PrintConfig.empId}), skip');
        //   return;
        // }

        _applyingConfig = true;
        final ok =
            await PrinterAgentConfigSyncService.applyFromData(configData);
        if (!ok) {
          _log('❌ printer_agent_config — apply failed, local cache unchanged');
          return;
        }

        _log('✅ printer_agent_config applied — notifying UI to reconnect');
        if (!_configUpdatedController.isClosed) {
          _configUpdatedController.add(null);
        }
      } catch (e) {
        _log('❌ printer_agent_config error: $e');
      } finally {
        _applyingConfig = false;
      }
    });
    _log('👂 Listening: $configChannel');
  }

  void _queueAggregatorStationJobs(
    RestaurantOrder order,
    String orderId, {
    required PrintType jobType,
    required String logLabel,
  }) {
    final stationGroups = <String, List<OrderItem>>{};
    for (final item in order.items) {
      final st = item.station?.trim().toUpperCase() ?? 'KDS';
      stationGroups.putIfAbsent(st, () => []).add(item);
    }

    for (final station in stationGroups.keys) {
      final stationItems = stationGroups[station]!;
      final printerIds = _router.resolveForStation(station);
      if (printerIds.isEmpty) {
        _log('⚠️ No printer configured for station=$station');
        continue;
      }

      final stationOrder = RestaurantOrder(
        orderId: order.orderId,
        displayOrderId: order.displayOrderId,
        tableId: order.tableId,
        tableName: order.tableName,
        waiterName: order.waiterName,
        orderAmount:
            stationItems.fold(0.0, (s, i) => s + i.price * i.quantity),
        orderNote: order.orderNote,
        orderType: order.orderType,
        printKot: 'Yes',
        restaurantName: order.restaurantName,
        receivedAt: order.receivedAt,
        userCustName: order.userCustName,
        userCustPhone: order.userCustPhone,
        dailyToken: order.dailyToken,
        items: stationItems,
      );

      KotSeparateTicket.queue(
        queueManager: _queueManager,
        printerIds: printerIds,
        type: jobType,
        order: stationOrder,
        stationLabel: station,
      );
      _log(
          '$logLabel [$station] → ${printerIds.join(', ')} (${stationItems.length} items) #$orderId');
    }
  }

  void _queueAggregatorBill(
    RestaurantOrder order,
    String orderId, {
    String logLabel = '🧾 Aggregator Bill',
  }) {
    final printerIds = _router.resolveForBill();
    if (printerIds.isEmpty) {
      _log('⚠️ No printer configured for bill');
      return;
    }

    for (final printerId in printerIds) {
      _queueManager.route(PrintJob(
        type: PrintType.bill,
        printerId: printerId,
        order: order,
      ));
    }
    _log('$logLabel queued → ${printerIds.join(', ')} #$orderId');
  }

  /// Auto-bill from new-order socket when auto-settle + bill flags are Yes
  /// and this device is mapped as the BILL printer_agent.
  void _tryQueueSocketAutoBill(
    Map<String, dynamic> orderMap,
    RestaurantOrder order,
    List<dynamic> agentList,
  ) {
    final billingAuto =
        orderMap['billing_auto_bill_print']?.toString().trim() ?? '';
    final printBillStatus =
        orderMap['print_bill_status']?.toString().trim() ?? '';
    final paymentType =
        orderMap['payment_type']?.toString().trim().toLowerCase() ?? '';

    if (!PrintConfig.autoSettle ||
        billingAuto != 'Yes' ||
        printBillStatus != 'Yes' ||
        paymentType != 'prepaid') {
      _log(
        '⏩ Socket auto-bill skipped '
        '(autoSettle=${PrintConfig.autoSettle}, '
        'billing_auto_bill_print=$billingAuto, print_bill_status=$printBillStatus, '
        'payment_type=$paymentType) '
        '#${order.displayOrderId}',
      );
      return;
    }

    if (!PrintConfig.autoPrintBill) {
      _log('⏸️ Auto Bill print OFF — skip socket bill #${order.displayOrderId}');
      return;
    }

    final billAgent = agentList.cast<Map<String, dynamic>>().firstWhere(
          (a) =>
              a['printer_agent_id']?.toString() == PrintConfig.empId &&
              a['station']?.toString().toUpperCase() == 'BILL',
          orElse: () => {},
        );

    if (billAgent.isEmpty) {
      _log(
        '⏩ No BILL agent for empId=${PrintConfig.empId} — skip socket bill #${order.displayOrderId}',
      );
      return;
    }

    if (_socketBillPrintedIds.contains(order.orderId)) {
      _log(
        '⏩ Socket auto-bill already queued for #${order.displayOrderId} — skip',
      );
      return;
    }

    final printerIds = _router.resolveForBill();
    if (printerIds.isEmpty) {
      _log('⚠️ No bill printer configured — skip socket bill #${order.displayOrderId}');
      return;
    }

    _socketBillPrintedIds.add(order.orderId);

    final billOrder = RestaurantOrder(
      orderId: order.orderId,
      displayOrderId: order.displayOrderId,
      tableId: order.tableId,
      tableName: order.tableName,
      waiterName: order.waiterName,
      orderAmount: order.orderAmount,
      orderNote: order.orderNote,
      orderType: order.orderType,
      printKot: order.printKot,
      restaurantName: order.restaurantName,
      receivedAt: order.receivedAt,
      userCustName: order.userCustName,
      userCustPhone: order.userCustPhone,
      dailyToken: order.dailyToken,
      items: order.items,
      billData: RestaurantOrder.billDataFromSocketOrder(orderMap),
    );

    for (final printerId in printerIds) {
      _queueManager.route(PrintJob(
        type: PrintType.bill,
        printerId: printerId,
        order: billOrder,
      ));
    }
    _log(
      '🧾 Socket auto-bill queued → ${printerIds.join(', ')} #${order.displayOrderId}',
    );
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
    _configUpdatedController.close();
  }
}
