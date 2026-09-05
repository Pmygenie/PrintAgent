import 'dart:async';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      onStart:                   onBackgroundServiceStart,
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
// Keep-alive only — printing stays in WindowsSocketService
// ─────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title:   '🖨️ Print Agent',
      content: 'Running...',
    );
  }

  service.on('stop').listen((_) async {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 30), (_) {
    service.invoke('heartbeat', {
      'time':  DateTime.now().toIso8601String(),
      'queue': 0,
    });
  });
}
