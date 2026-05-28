// import 'dart:async';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:socket_io_client/socket_io_client.dart' as IO;
// import '../queue/print_queue.dart';
// import '../models/print_job.dart';
// import '../models/restaurant_order.dart';
// import '../config/print_config.dart';

// class WindowsSocketService {
//   IO.Socket? _socket;
//   final PrintQueue _queue;
//   final Set<int> _printedIds = {};

//   bool _connected = false;
//   bool get isConnected => _connected;

//   final _logController = StreamController<String>.broadcast();
//   final _statusController = StreamController<bool>.broadcast();

//   Stream<String> get logStream => _logController.stream;
//   Stream<bool> get statusStream => _statusController.stream;

//   WindowsSocketService(this._queue);

//   Future<Map<String, dynamic>?> _fetchOrderRaw(String orderId) async {
//     try {
//       final url = '${PrintConfig.apiUrl}'
//           '/api/v1/vendoremployee/order-temp-details'
//           '?order_id=$orderId';

//       _log('🌐 Fetching: $url');

//       final response = await http.get(
//         Uri.parse(url),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer ${PrintConfig.authToken}',
//         },
//       ).timeout(const Duration(seconds: 10));

//       if (response.statusCode != 200) {
//         _log('❌ API error: ${response.statusCode}');
//         return null;
//       }

//       final json = jsonDecode(response.body);
//       final details = json['order_details_data'];

//       if (details == null) {
//         _log('❌ order_details_data is null');
//         return null;
//       }

//       return Map<String, dynamic>.from(details);
//     } catch (e) {
//       _log('❌ fetchOrderRaw error: $e');
//       return null;
//     }
//   }

//   void connect() {
//     _socket = IO.io(PrintConfig.serverUrl, <String, dynamic>{
//       'transports': ['websocket'],
//       'autoConnect': false,
//       'reconnection': true,
//       'reconnectionDelay': 2000,
//       'reconnectionAttempts': 999999,
//     });

//     _socket!.onConnect((_) {
//       _connected = true;
//       _statusController.add(true);
//       _log('✅ Connected to ${PrintConfig.serverUrl}');
//       _registerListeners();
//     });

//     _socket!.onDisconnect((_) {
//       _connected = false;
//       _statusController.add(false);
//       _log('❌ Disconnected — retrying...');
//     });

//     _socket!.onReconnect((_) {
//       _log('♻️ Reconnected — re-registering listeners');
//       _registerListeners();
//     });

//     _socket!.onError((e) => _log('⚠️ Socket error: $e'));
//     _socket!.connect();
//   }

//   void _registerListeners() {
//     final restaurantId = PrintConfig.restaurantId.toString();

//     // ═══════════════════════════════════════════════════
//     // NEW ORDER — ✅ NOT TOUCHED — exactly as before
//     // ═══════════════════════════════════════════════════
//     _socket!.off('new_order_$restaurantId');
//     _socket!.on('new_order_$restaurantId', (data) {
//       _log('📡 Received new_order_$restaurantId : $data');
//       try {
//         final payload = data as List<dynamic>;
//         final eventType = payload[0].toString();

//         if (eventType != 'new-order' && eventType != 'scan-new-order') return;
//         if ('${payload[2]}' != restaurantId) return;

//         if (payload.length < 5 || payload[4] == null) {
//           _log('⚠️ No order JSON in data[4]');
//           return;
//         }

//         print('🔍 Recieved Socket ORDER JSON: ${payload[4]}');

//         final orderMap = payload[4] is String
//             ? jsonDecode(payload[4]['orders'][0])
//             : Map<String, dynamic>.from(payload[4]['orders'][0]);

//         final order = RestaurantOrder.fromJson(orderMap);

//         // if (_printedIds.contains(order.orderId)) {
//         //   _log('⏩ Already printed #${order.displayOrderId} — skip');
//         //   return;
//         // }

//         if (!PrintConfig.autoPrint) {
//           _log('⏸️ Auto print OFF — skip #${order.displayOrderId}');
//           return;
//         }

//         if (order.printKot == 'Yes') {
//           _printedIds.add(order.orderId);

//           // ✅ Get stations present in this order's items
//           final myStations =
//               PrintConfig.stations.map((s) => s.trim().toUpperCase()).toSet();

//           final orderStations = order.items
//               .map((i) => i.station?.trim().toUpperCase() ?? '')
//               .where((s) => s.isNotEmpty)
//               .toSet();

//           final matched = myStations.intersection(orderStations);

//           if (matched.isEmpty) {
//             // ✅ Fallback — no station data → print all items as one KOT
//             _queue.addJob(PrintJob(
//               type: PrintType.kot,
//               printerId: 'kitchen_printer',
//               order: order,
//             ));
//             _log('🖨️ Queued KOT (no station match) #${order.displayOrderId}');
//           } else {
//             // ✅ Print one KOT per matched station
//             for (final station in matched) {
//               final stationItems = order.items
//                   .where((i) => i.station?.trim().toUpperCase() == station)
//                   .toList();

//               if (stationItems.isEmpty) continue;

//               final stationOrder = RestaurantOrder(
//                 orderId: order.orderId,
//                 displayOrderId: order.displayOrderId,
//                 tableId: order.tableId,
//                 tableName: order.tableName,
//                 waiterName: order.waiterName,
//                 orderAmount: stationItems.fold(
//                     0.0, (sum, i) => sum + (i.price * i.quantity)),
//                 orderNote: order.orderNote,
//                 orderType: order.orderType,
//                 printKot: order.printKot,
//                 restaurantName: order.restaurantName,
//                 items: stationItems,
//               );

//               _queue.addJob(PrintJob(
//                 type: PrintType.kot,
//                 printerId: 'kitchen_printer',
//                 order: stationOrder,
//                 stationLabel: station, // ✅ prints [ KDS ] or [ BAR ] on KOT
//               ));
//               _log(
//                   '🖨️ Queued KOT [$station] (${stationItems.length} items) #${order.displayOrderId}');
//             }
//           }
//         } else {
//           _log('⏩ print_kot=No — skip #${order.displayOrderId}');
//         }
//       } catch (e) {
//         _log('❌ new_order parse error: $e');
//       }
//     });

//     // ═══════════════════════════════════════════════════
//     // MANUAL PRINT — ✅ UPDATED with station filter logic
//     // ═══════════════════════════════════════════════════
//     _socket!.off('manually_print_$restaurantId');
//     _socket!.on('manually_print_$restaurantId', (data) async {
//       _log('📡 Received manually_print_$restaurantId : $data');
//       try {
//         final payload = data as List<dynamic>;
//         final printType =
//             payload[0].toString().toLowerCase(); // 'kot' or 'bill'
//         final orderId = payload[1].toString();
//         final socketRestId = payload[2].toString();

//         if (socketRestId != restaurantId) return;

//         // ── BILL ────────────────────────────────────────
//         if (printType == 'bill') {
//           _log('🧾 Manual bill for order #$orderId — fetching from API...');

//           final rawData = await _fetchOrderRaw(orderId);
//           if (rawData == null) {
//             _log('❌ Could not fetch order #$orderId');
//             return;
//           }

//           // ✅ emp_code check — always ON for bill
//           final empCode = rawData['emp_code']?.toString() ?? '';
//           if (empCode != PrintConfig.empId) {
//             _log(
//                 '⏩ emp_code=$empCode != empId=${PrintConfig.empId} — not my order, skip');
//             return;
//           }

//           // Build order with all items (no station filter for bill)
//           final order = RestaurantOrder.fromTempApi(rawData);

//           _queue.addJob(PrintJob(
//             type: PrintType.bill,
//             printerId: 'kitchen_printer',
//             order: order,
//             stationLabel: null, // bill has no station label
//           ));
//           _log('🧾 Manual Bill queued #$orderId');
//           return;
//         }

//         // ── KOT ─────────────────────────────────────────
//         if (printType == 'kot') {
//           _log('🖨️ Manual kot for order #$orderId — fetching from API...');

//           // ✅ emp_code check — COMMENTED OUT for KOT (future use)
//           // Reason: manually_print KOT uses station match, not emp_code

//           // Parse socket stations from data[3] e.g. 'BAR,KDS'
//           final socketStationsRaw =
//               payload.length > 3 ? payload[3].toString() : '';

//           final socketStations = socketStationsRaw
//               .split(',')
//               .map((s) => s.trim().toUpperCase())
//               .where((s) => s.isNotEmpty)
//               .toSet();

//           _log('📋 Socket stations: $socketStations');
//           _log('📋 My stations: ${PrintConfig.stations}');

//           // ✅ Find intersection — which of my stations are in this event
//           final myStationsUpper =
//               PrintConfig.stations.map((s) => s.trim().toUpperCase()).toSet();

//           final matched = myStationsUpper.intersection(socketStations);

//           if (matched.isEmpty) {
//             _log('⏩ No matching station — not for this device, skip');
//             return;
//           }

//           _log('✅ Matched stations: $matched — fetching order...');

//           // ✅ Fetch API ONCE for all stations
//           final rawData = await _fetchOrderRaw(orderId);
//           if (rawData == null) {
//             _log('❌ Could not fetch order #$orderId');
//             return;
//           }

//           // ✅ For each matched station → filter items → separate print job
//           for (final station in matched) {
//             final stationOrder = RestaurantOrder.fromTempApi(
//               rawData,
//               stationFilter: station, // ✅ only items for this station
//             );

//             if (stationOrder.items.isEmpty) {
//               _log('⏩ No items for station $station — skip');
//               continue;
//             }

//             _queue.addJob(PrintJob(
//               type: PrintType.kot,
//               printerId: 'kitchen_printer',
//               order: stationOrder,
//               stationLabel: station, // ✅ KOT header shows station name
//             ));

//             _log('🖨️ KOT queued for station $station'
//                 ' (${stationOrder.items.length} items) #$orderId');
//           }
//         }
//       } catch (e) {
//         _log('❌ manually_print error: $e');
//       }
//     });

//     _log('👂 Listening: new_order_$restaurantId');
//     _log('👂 Listening: manually_print_$restaurantId');
//   }

//   void _log(String msg) {
//     print('[WinSocket] $msg');
//     _logController.add(msg);
//   }

//   void disconnect() {
//     _socket?.disconnect();
//     _socket?.dispose();
//     _logController.close();
//     _statusController.close();
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:printer_agent/core/models/order_item.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../queue/print_queue.dart';
import '../models/print_job.dart';
import '../models/restaurant_order.dart';
import '../config/print_config.dart';

class WindowsSocketService {
  IO.Socket? _socket;
  final PrintQueue _queue;
  final Set<int> _printedIds = {};

  bool _connected = false;
  bool get isConnected => _connected;

  final _logController = StreamController<String>.broadcast();
  final _statusController = StreamController<bool>.broadcast();

  Stream<String> get logStream => _logController.stream;
  Stream<bool> get statusStream => _statusController.stream;

  WindowsSocketService(this._queue);

  // Future<Map<String, dynamic>?> _fetchOrderRaw(String orderId) async {
  //   try {
  //     final url = '${PrintConfig.apiUrl}'
  //         '/api/v2/vendoremployee/order-temp-details'
  //         '?order_id=$orderId';

  //     _log('🌐 Fetching: $url');

  //     final response = await http.get(
  //       Uri.parse(url),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer ${PrintConfig.authToken}',
  //       },
  //     ).timeout(const Duration(seconds: 10));

  //     if (response.statusCode != 200) {
  //       _log('❌ API error: ${response.statusCode}');
  //       return null;
  //     }

  //     final json = jsonDecode(response.body);
  //     final details = json['order_details_data'];

  //     if (details == null) {
  //       _log('❌ order_details_data is null');
  //       return null;
  //     }

  //     return Map<String, dynamic>.from(details);
  //   } catch (e) {
  //     _log('❌ fetchOrderRaw error: $e');
  //     return null;
  //   }
  // }

  Future<Map<String, dynamic>?> _fetchOrderRaw(String orderId) async {
    try {
      final url = '${PrintConfig.apiUrl}'
          '/api/v2/vendoremployee/order-temp-details'
          '?order_id=$orderId';

      _log('🌐 Fetching: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${PrintConfig.authToken}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _log('❌ API error: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body);
      final details = json['order_details_data'];

      if (details == null) {
        _log('❌ order_details_data is null');
        return null;
      }

      // ✅ Extract bill[0] from root and inject into returned map
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
        _log(' bill loaded');
      }

      if (kdsData.isEmpty) {
        _log('⚠️ kds is empty or missing');
      } else {
        _log('kds loaded');
      }

      return {
        ...Map<String, dynamic>.from(details),
        'bill': billData,
        'kds': kdsData,
      };
    } catch (e) {
      _log('❌ fetchOrderRaw error: $e');
      return null;
    }
  }

  void connect() {
    _socket = IO.io(PrintConfig.serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionDelay': 2000,
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

    // ═══════════════════════════════════════════════════
    // NEW ORDER / UPDATE ORDER
    // ═══════════════════════════════════════════════════
    _socket!.off('new_order_$restaurantId');
    _socket!.on('new_order_$restaurantId', (data) {
      log('📡 Received new_order_$restaurantId : $data');
      try {
        final payload = data as List<dynamic>;
        final eventType = payload[0].toString();

        // ── GATE 1: Event type check ──────────────────────
        if (eventType != 'new-order' &&
            eventType != 'scan-new-order' &&
            eventType != 'update-order' &&
            eventType != 'update-order-status') return;

        // ── GATE 2: Restaurant check ──────────────────────
        if ('${payload[2]}' != restaurantId) return;

        if (payload.length < 5 || payload[4] == null) {
          _log('⚠️ No order JSON in data[4]');
          return;
        }

        // ✅ Single rawPayload — used for both orderMap + printer_agent
        final rawPayload =
            payload[4] is String ? jsonDecode(payload[4]) : payload[4];

        // ✅ Always unwrap from orders[0] if orders key exists
        final orderMap = (rawPayload is Map && rawPayload['orders'] != null)
            ? (rawPayload['orders'] as List).first
            : rawPayload as Map<String, dynamic>;

        final order = RestaurantOrder.fromJson(orderMap);

        // ── GATE 3: Auto print check ──────────────────────
        if (!PrintConfig.autoPrint) {
          _log('⏸️ Auto print OFF — skip #${order.displayOrderId}');
          return;
        }

        // ── GATE 4: printKot check ────────────────────────
        if (order.printKot != 'Yes') {
          _log('⏩ print_kot=No — skip #${order.printKot}');
          _log('⏩ print_kot=No — skip #${order.displayOrderId}');
          return;
        }

        _printedIds.add(order.orderId);

        // ── GATE 5: printer_agent — always at rawPayload root ✅
        final agentList = ((rawPayload as Map<String, dynamic>)['printer_agent']
                as List<dynamic>? ??
            []);

        if (agentList.isEmpty) {
          _log('⏩ printer_agent missing — skip #${order.displayOrderId}');
          return;
        }

        _log('📋 printer_agent count: ${agentList.length}');

        // ── GATE 6: Filter agents for this device ─────────
        final myEmpId = PrintConfig.empId.trim();

        final myAgents = agentList
            .cast<Map<String, dynamic>>()
            .where((a) => a['printer_agent_id']?.toString().trim() == myEmpId)
            .toList();

        if (myAgents.isEmpty) {
          _log(
              '⏩ No KOT agents for empId=$myEmpId — not my device, skip #${order.displayOrderId}');
          return;
        }

        _log(
            '✅ Matched agents: ${myAgents.map((a) => a['station']).toList()} for empId=$myEmpId');

        // ✅ NEW — For update-order use newly_added_items, else use order.items

        final List<OrderItem> itemsToPrint;
        if (eventType == 'update-order') {
          final newlyAdded = rawPayload['newly_added_items'] as List<dynamic>?;

          if (newlyAdded == null || newlyAdded.isEmpty) {
            _log(
                '⏩ update-order but no newly_added_items — skip #${order.displayOrderId}');
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

        // ── GATE 7: Per station → filter items → print ────
        for (final agent in myAgents) {
          final station = agent['station'].toString().toUpperCase().trim();

          final stationItems =
              itemsToPrint // ✅ uses newly_added_items for update-order
                  .where((i) => i.station?.trim().toUpperCase() == station)
                  .toList();

          if (stationItems.isEmpty) {
            _log('⏩ No items for station=$station — skip');
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
            items: stationItems,
          );

          _queue.addJob(PrintJob(
            type: eventType == 'update-order-status'
                ? PrintType.cancelKot
                : PrintType.kot,
            printerId: 'kitchen_printer',
            order: stationOrder,
            stationLabel: station,
          ));

          final label = eventType == 'update-order-status'
              ? '🚫 Queued CANCEL KOT'
              : '🖨️ Queued KOT';
          _log(
              '$label [$station] (${stationItems.length} items) #${order.displayOrderId}');
        }
      } catch (e) {
        _log('❌ new_order parse error: $e');
      }
    });
    // ═══════════════════════════════════════════════════
    // MANUAL PRINT — ✅ UPDATED: printer_agent routing
    // ═══════════════════════════════════════════════════
    _socket!.off('manually_print_$restaurantId');
    _socket!.on('manually_print_$restaurantId', (data) async {
      _log('📡 Received manually_print_$restaurantId : $data');
      try {
        final payload = data as List<dynamic>;
        final printType =
            payload[0].toString().toLowerCase(); // 'kot' or 'bill'
        final orderId = payload[1].toString();
        final socketRestId = payload[2].toString();

        // ── GATE 1: Restaurant check ─────────────────────
        if (socketRestId != restaurantId) return;

        // ── GATE 2: printType branch ──────────────────────

        // ── BILL ──────────────────────────────────────────
        if (printType == 'bill') {
          if (!PrintConfig.autoPrintBill) {
            _log('⏸️ Auto Bill print OFF — skip #$orderId');
            return;
          }

          _log('🧾 Manual bill for order #$orderId — fetching from API...');

          // ── GATE 3: Fetch API ──────────────────────────
          final rawData = await _fetchOrderRaw(orderId);
          if (rawData == null) {
            _log('❌ Could not fetch order #$orderId');
            return;
          }

          // ── GATE 4: Match printer_agent ────────────────
          // Find the BILL agent entry that belongs to this device.
          // Both conditions required:
          //   printer_agent_id == empId  → is this MY device?
          //   station == "BILL"          → is this the bill printer slot?
          final agentList = (rawData['printer_agent'] as List<dynamic>? ?? []);

          // _log('🔍 agentList: $agentList');
          // _log('🔍 empId from config: "${PrintConfig.empId}"');

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

          _log(
              '✅ BILL agent matched — empId=${PrintConfig.empId} | station = BILL');

          // ── GATE 5: Print ──────────────────────────────
          final order = RestaurantOrder.fromTempApi(rawData);

          _queue.addJob(PrintJob(
            type: PrintType.bill,
            printerId: 'kitchen_printer',
            order: order,
            stationLabel: null,
          ));
          _log('🧾 Manual Bill queued #$orderId');
          return;
        }

        // ── KOT ───────────────────────────────────────────
        if (printType == 'kot') {
          _log('🖨️ Manual kot for order #$orderId — fetching from API...');

          // ── GATE 3: Fetch API ──────────────────────────
          final rawData = await _fetchOrderRaw(orderId);
          if (rawData == null) {
            _log('❌ Could not fetch order #$orderId');
            return;
          }

          // Parse socketStations from payload[3] e.g. 'BAR,KDS'
          final socketStationsRaw =
              payload.length > 3 ? payload[3].toString() : '';

          final socketStations = socketStationsRaw
              .split(',')
              .map((s) => s.trim().toUpperCase())
              .where((s) => s.isNotEmpty)
              .toSet();

          _log('📋 Socket stations from event: $socketStations');

          // ── GATE 4: Filter printer_agent entries ───────
          // Keep entries where ALL 3 conditions pass:
          //   printer_agent_id == empId   → is this MY device?
          //   station != "BILL"           → safety guard
          //   station ∈ socketStations    → is this station in the event?
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

          // ── GATE 5: Per station → filter items → print ─
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

            _queue.addJob(PrintJob(
              type: PrintType.kot,
              printerId: 'kitchen_printer',
              order: stationOrder,
              stationLabel: station,
            ));

            _log('🖨️ KOT queued for station 🏠 $station 🏠'
                ' (${stationOrder.items.length} items) #$orderId');
          }
        }
      } catch (e) {
        _log('❌ manually_print error: $e');
      }
    });

    _log('👂 Listening: new_order_$restaurantId');
    _log('👂 Listening: manually_print_$restaurantId');
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
