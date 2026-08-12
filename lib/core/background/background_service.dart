import 'dart:async';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/printer_config.dart';
import '../queue/print_queue_manager.dart';
import '../router/printer_router.dart';
import '../models/print_job.dart';
import '../models/restaurant_order.dart';
import '../config/print_config.dart';
import '../config/app_constants.dart';
import 'dart:convert';

const _notifChannelId = 'print_agent_channel';
const _notifId        = 888;

// ─────────────────────────────────────────────────────────────
// CALL THIS IN main() — both Android & Windows
// ─────────────────────────────────────────────────────────────
Future<void> initBackgroundService() async {
  // Windows: no background service needed
  if (!Platform.isAndroid) return;

  final service = FlutterBackgroundService();

  // Setup notification channel
  final notif = FlutterLocalNotificationsPlugin();
  const channel = AndroidNotificationChannel(
    _notifChannelId,
    'Print Agent Service',
    description: 'Keeps print agent running',
    importance: Importance.low,
  );
  await notif
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    iosConfiguration: IosConfiguration(autoStart: false),
    androidConfiguration: AndroidConfiguration(
      onStart:                   onBackgroundServiceStart, // ← socket runs here
      autoStart:                 true,
      isForegroundMode:          true,
      notificationChannelId:     _notifChannelId,
      initialNotificationTitle:  '🖨️ Print Agent',
      initialNotificationContent: 'Waiting for orders...',
      foregroundServiceNotificationId: _notifId,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// THIS RUNS IN BACKGROUND ISOLATE — socket + queue lives here
// ─────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  // Load saved config
  await PrintConfig.load();
  final configs = await PrinterConfigStorage.load();

  // Setup queue manager + router
  final printers     = configs.isNotEmpty ? configs : _defaultPrinters();
  final queueManager = PrintQueueManager()..registerAll(printers);
  final router       = PrinterRouter(printers);

  // Forward queue status to UI
  queueManager.statusStream.listen((msg) {
    service.invoke('queue_update', {'message': msg});
  });

  // Setup socket
  IO.Socket? socket;
  final Set<int> printedOrderIds = {};

  void connectSocket() {
    socket = IO.io(AppConstants.socketUrl, <String, dynamic>{
      'transports':           ['websocket'],
      'autoConnect':          true,
      'reconnection':         true,
      'reconnectionDelay':    2000,
      'reconnectionAttempts': double.infinity,
    });

    socket!.onConnect((_) {
      service.invoke('socket_status', {'connected': true});
      service.invoke('log', {'msg': '✅ Socket connected'});

      // Update notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title:   '🖨️ Print Agent — Connected',
          content: 'Listening for orders...',
        );
      }
    });

    socket!.onDisconnect((_) {
      service.invoke('socket_status', {'connected': false});
      service.invoke('log', {'msg': '❌ Socket disconnected — retrying...'});

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title:   '🖨️ Print Agent — Reconnecting',
          content: 'Waiting for server...',
        );
      }
    });

    socket!.on('new_order_${PrintConfig.restaurantId}', (data) {
      try {
        final payload   = data as List<dynamic>;
        final eventType = payload[0].toString();

        service.invoke('log', {'msg': '📨 Event: $eventType'});

        if (eventType == 'new-order' && payload.length >= 5) {
          final rawPayload = payload[4] is String
              ? jsonDecode(payload[4])
              : payload[4] as Map<String, dynamic>;
          final orders = rawPayload['orders'] as List<dynamic>? ?? [];

          for (final raw in orders) {
            final orderMap = Map<String, dynamic>.from(raw);
            final order    = RestaurantOrder.fromJson(orderMap);

            if (printedOrderIds.contains(order.orderId)) {
              service.invoke('log', {'msg': '⏭️ Duplicate #${order.displayOrderId}, skip'});
              continue;
            }

            if (order.printKot != 'Yes') continue;

            printedOrderIds.add(order.orderId);

            if (!PrintConfig.autoPrint) {
              service.invoke('pending_order', order.toMap());
              service.invoke('log', {'msg': '📋 Pending: #${order.displayOrderId}'});
              continue;
            }

            // Route each item's station through the router
            final agentList = (rawPayload['printer_agent'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>()
                .where((a) => a['printer_agent_id']?.toString().trim() == PrintConfig.empId.trim())
                .toList();

            if (agentList.isEmpty) {
              // Fallback: no agent list, route all items to any bill-handling printer
              final printerIds = router.resolveForBill();
              for (final pid in printerIds) {
                queueManager.route(PrintJob(
                  type:      PrintType.kot,
                  printerId: pid,
                  order:     order,
                ));
              }
              service.invoke('log', {'msg': '🖨️ Auto KOT (fallback) #${order.displayOrderId}'});
              continue;
            }

            // Per-station routing
            for (final agent in agentList) {
              final station      = agent['station'].toString().toUpperCase().trim();
              final stationItems = order.items
                  .where((i) => i.station?.trim().toUpperCase() == station)
                  .toList();

              if (stationItems.isEmpty) continue;

              final printerIds = router.resolveForStation(station);
              if (printerIds.isEmpty) continue;

              final stationOrder = RestaurantOrder(
                orderId:        order.orderId,
                displayOrderId: order.displayOrderId,
                tableId:        order.tableId,
                tableName:      order.tableName,
                waiterName:     order.waiterName,
                orderAmount:    stationItems.fold(0.0, (s, i) => s + (i.price * i.quantity)),
                orderNote:      order.orderNote,
                orderType:      order.orderType,
                printKot:       order.printKot,
                restaurantName: order.restaurantName,
                receivedAt:     order.receivedAt,
                dailyToken:     order.dailyToken,
                items:          stationItems,
              );

              for (final pid in printerIds) {
                queueManager.route(PrintJob(
                  type:         PrintType.kot,
                  printerId:    pid,
                  order:        stationOrder,
                  stationLabel: station,
                ));
              }
              service.invoke('log', {'msg': '🖨️ KOT [$station] → ${printerIds.join(', ')} #${order.displayOrderId}'});
            }
          }
        }
      } catch (e) {
        service.invoke('log', {'msg': '❌ Parse error: $e'});
      }
    });
  }

  connectSocket();

  // Listen for manual print trigger from UI
  service.on('manual_print').listen((data) {
    if (data == null) return;
    final order      = RestaurantOrder.fromMap(Map<String, dynamic>.from(data));
    final printerIds = router.resolveForBill(); // fallback: route to bill printer
    for (final pid in printerIds) {
      queueManager.route(PrintJob(
        type:      PrintType.kot,
        printerId: pid,
        order:     order,
      ));
    }
    service.invoke('log', {'msg': '🖨️ Manual print #${order.displayOrderId}'});
  });

  // Listen for stop command from UI
  service.on('stop').listen((_) async {
    await queueManager.dispose();
    service.stopSelf();
  });

  // Heartbeat — proves service is alive
  Timer.periodic(const Duration(seconds: 30), (_) {
    service.invoke('heartbeat', {
      'time':  DateTime.now().toIso8601String(),
      'queue': queueManager.totalLength,
    });
  });
}

List<PrinterConfig> _defaultPrinters() => [
  PrinterConfig(
    id:              'kitchen_printer',
    label:           'Kitchen Printer',
    type:            PrinterType.lan,
    ipAddress:       PrintConfig.lanIp.isNotEmpty ? PrintConfig.lanIp : '192.168.1.100',
    port:            PrintConfig.lanPort,
    handledStations: PrintConfig.stations,
    handlesBill:     true,
  ),
];