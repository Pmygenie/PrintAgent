import 'dart:async';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/printer_config.dart';
import '../printer/printer_manager.dart';
import '../queue/print_queue.dart';
import '../models/print_job.dart';
import '../models/restaurant_order.dart';
import '../config/print_config.dart';
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

  // Setup printer manager + queue
  final manager = PrinterManager();
  manager.registerAll(configs.isNotEmpty ? configs : _defaultPrinters());
  final queue = PrintQueue(manager);

  // Forward queue status to UI
  queue.statusStream.listen((msg) {
    service.invoke('queue_update', {'message': msg});
  });

  // Setup socket
  IO.Socket? socket;
  final Set<int> printedOrderIds = {};

  void connectSocket() {
    socket = IO.io(PrintConfig.serverUrl, <String, dynamic>{
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
          final wrapper = Map<String, dynamic>.from(payload[4]);
          final orders  = wrapper['orders'] as List<dynamic>? ?? [];

          for (final raw in orders) {
            final orderMap = Map<String, dynamic>.from(raw);
            final order    = RestaurantOrder.fromJson(orderMap);

            // Duplicate guard
            if (printedOrderIds.contains(order.orderId)) {
              service.invoke('log', {'msg': '⏭️ Duplicate #${order.displayOrderId}, skip'});
              continue;
            }

            if (order.printKot == 'No') {
              printedOrderIds.add(order.orderId);

              if (PrintConfig.autoPrint) {
                // AUTO → straight to queue
                queue.addJob(PrintJob(
                  type:      PrintType.kot,
                  printerId: 'kitchen_printer',
                  order:     order,
                ));
                service.invoke('log', {'msg': '🖨️ Auto printing #${order.displayOrderId}'});
              } else {
                // MANUAL → send to UI for staff tap
                service.invoke('pending_order', order.toMap());
                service.invoke('log', {'msg': '📋 Pending: #${order.displayOrderId}'});
              }
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
    final order = RestaurantOrder.fromMap(Map<String, dynamic>.from(data));
    queue.addJob(PrintJob(
      type:      PrintType.kot,
      printerId: 'kitchen_printer',
      order:     order,
    ));
    service.invoke('log', {'msg': '🖨️ Manual print #${order.displayOrderId}'});
  });

  // Listen for stop command from UI
  service.on('stop').listen((_) => service.stopSelf());

  // Heartbeat — proves service is alive
  Timer.periodic(const Duration(seconds: 30), (_) {
    service.invoke('heartbeat', {
      'time':  DateTime.now().toIso8601String(),
      'queue': queue.length,
    });
  });
}

List<PrinterConfig> _defaultPrinters() => [
  const PrinterConfig(
    id:        'kitchen_printer',
    label:     'Kitchen Printer',
    type:      PrinterType.lan,
    ipAddress: '192.168.1.100',
  ),
];