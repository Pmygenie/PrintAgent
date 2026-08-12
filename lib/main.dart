// import 'dart:io';
// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';

// import 'core/config/print_config.dart';
// import 'core/models/printer_config.dart';
// import 'core/printer/printer_manager.dart';
// import 'core/queue/print_queue.dart';
// import 'core/socket/windows_socket_service.dart';
// import 'core/background/background_service.dart';
// import 'ui/screens/home_screen.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // 1. Load saved config
//   await PrintConfig.load();
//   final savedPrinters = await PrinterConfigStorage.load();

//   // 2. Request Android permissions
//   if (Platform.isAndroid) {
//     await [
//       Permission.bluetooth,
//       Permission.bluetoothScan,
//       Permission.bluetoothConnect,
//       Permission.notification,
//       Permission.ignoreBatteryOptimizations,
//     ].request();
//   }

//   // 3. Android → init background service
//   if (Platform.isAndroid) {
//     print('🔌 Android USB → vendorId=${PrintConfig.usbVendorId} productId=${PrintConfig.usbProductId}');
//     await [
//       Permission.bluetooth,
//       Permission.bluetoothScan,
//       Permission.bluetoothConnect,
//       Permission.notification,
//       Permission.ignoreBatteryOptimizations,
//     ].request();

//     await initBackgroundService();

//     // ✅ Android — LAN or USB based on connectionType
//     final androidPrinters = savedPrinters.isNotEmpty
//         ? savedPrinters
//         : [_buildDefaultPrinterConfig()];

//     final androidManager = PrinterManager()..registerAll(androidPrinters);
//     final androidQueue = PrintQueue(androidManager);
//     final androidSocket = WindowsSocketService(androidQueue)..connect();

//     runApp(PrintAgentApp(windowsSocket: androidSocket, queue: androidQueue));
//     return;
//   }

//   // 4. Windows → socket in main isolate
//   // ✅ LAN or USB based on connectionType
//   final printers = savedPrinters.isNotEmpty
//       ? savedPrinters
//       : [_buildDefaultPrinterConfig()];

//   final manager = PrinterManager()..registerAll(printers);
//   final queue = PrintQueue(manager);
//   final socket = WindowsSocketService(queue)..connect();

//   runApp(PrintAgentApp(windowsSocket: socket, queue: queue));
// }

// // ✅ NEW — builds PrinterConfig from PrintConfig.connectionType
// PrinterConfig _buildDefaultPrinterConfig() {
//   if (PrintConfig.connectionType == PrinterConnectionType.lan) {
//     print('🌐 LAN Printer → ${PrintConfig.lanIp}:${PrintConfig.lanPort}');
//     return PrinterConfig(
//       id: 'kitchen_printer',
//       label: 'Kitchen Printer',
//       type: PrinterType.lan,
//       ipAddress: PrintConfig.lanIp,
//       port: PrintConfig.lanPort,
//       paperSize: PrintConfig.paperSize,
//     );
//   }

//   // USB — Windows or Android
//   print('🖨️ USB Printer → ${PrintConfig.printerName} / vendor=${PrintConfig.usbVendorId}');
//   return PrinterConfig(
//     id: 'kitchen_printer',
//     label: 'Kitchen Printer',
//     type: PrinterType.usb,
//     windowsPrinterName: PrintConfig.printerName,
//     vendorId: PrintConfig.usbVendorId,
//     productId: PrintConfig.usbProductId,
//     paperSize: PrintConfig.paperSize,
//   );
// }

// class PrintAgentApp extends StatelessWidget {
//   final WindowsSocketService? windowsSocket;
//   final PrintQueue? queue;

//   const PrintAgentApp({
//     super.key,
//     required this.windowsSocket,
//     required this.queue,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Print Agent',
//       theme: ThemeData.dark(useMaterial3: true),
//       home: HomeScreen(
//         windowsSocket: windowsSocket,
//         queue: queue,
//       ),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'core/config/print_config.dart';
import 'core/models/printer_config.dart';
import 'core/queue/print_queue_manager.dart';
import 'core/router/printer_router.dart';
import 'core/socket/windows_socket_service.dart';
import 'core/background/background_service.dart';
import 'core/profile/restaurant_profile_api.dart';
import 'core/profile/restaurant_profile_repository.dart';
import 'core/profile/restaurant_profile_store.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load saved config
  await PrintConfig.load();
  final savedPrinters = await PrinterConfigStorage.load();

  // Sync restaurant profile in background (fire and forget)
  _syncRestaurantProfileOnStart();

  // 2. Request Android permissions
  if (Platform.isAndroid) {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();
  }

  // 3. Android → init background service
  if (Platform.isAndroid) {
    print('📱 Initializing Android Environment...');

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    List<Permission> permissionsToRequest = [];

    if (sdkInt <= 30) {
      permissionsToRequest = [
        Permission.location,
        Permission.bluetooth,
        Permission.notification,
        Permission.ignoreBatteryOptimizations,
      ];
    } else {
      permissionsToRequest = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.notification,
        Permission.ignoreBatteryOptimizations,
      ];
    }

    await permissionsToRequest.request();

    print('🔌 Android USB → vendorId=${PrintConfig.usbVendorId} productId=${PrintConfig.usbProductId}');

    await initBackgroundService();

    final androidPrinters = savedPrinters.isNotEmpty
        ? savedPrinters
        : [_buildDefaultPrinterConfig()];

    final androidQueueManager = PrintQueueManager()..registerAll(androidPrinters);
    final androidRouter       = PrinterRouter(androidPrinters);
    final androidSocket       = WindowsSocketService(androidQueueManager, androidRouter)..connect();

    runApp(PrintAgentApp(windowsSocket: androidSocket, queueManager: androidQueueManager));
    return;
  }

  // 4. Windows → socket in main isolate
  final printers = savedPrinters.isNotEmpty
      ? savedPrinters
      : [_buildDefaultPrinterConfig()];

  final queueManager = PrintQueueManager()..registerAll(printers);
  final router       = PrinterRouter(printers);
  final socket       = WindowsSocketService(queueManager, router)..connect();

  runApp(PrintAgentApp(windowsSocket: socket, queueManager: queueManager));
}

Future<void> _syncRestaurantProfileOnStart() async {
  try {
    final token = PrintConfig.authToken;
    if (token.isEmpty) {
      print('⚠️ Restaurant profile sync skipped: token not found');
      return;
    }

    final repo = RestaurantProfileRepository(
      api: RestaurantProfileApi(),
      store: RestaurantProfileStore(),
    );

    final profile = await repo.syncOnAppStart(token: token);

    if (profile != null && profile.isNotEmpty) {
      print('✅ Restaurant profile synced: ${profile.restaurantName}');
    } else {
      print('⚠️ Restaurant profile sync completed: no data found');
    }
  } catch (e) {
    print('❌ Restaurant profile sync failed: $e');
  }
}

/// Builds a single fallback [PrinterConfig] from [PrintConfig] global settings.
/// Used when no printers have been saved to disk yet (first launch).
/// The fallback printer handles all stations + bill so the app works out-of-the-box.
PrinterConfig _buildDefaultPrinterConfig() {
  final currentPaperSize = PrintConfig.is80mm ? PaperSize.mm80 : PaperSize.mm58;

  if (PrintConfig.connectionType == PrinterConnectionType.lan) {
    print('🌐 LAN Printer → ${PrintConfig.lanIp}:${PrintConfig.lanPort}');
    return PrinterConfig(
      id:               'kitchen_printer',
      label:            'Kitchen Printer',
      type:             PrinterType.lan,
      ipAddress:        PrintConfig.lanIp,
      port:             PrintConfig.lanPort,
      paperSize:        currentPaperSize,
      handledStations:  PrintConfig.stations,
      handlesBill:      true,
    );
  }

  if (PrintConfig.connectionType == PrinterConnectionType.bluetooth) {
    print('🔵 Bluetooth Printer → macAddress=${PrintConfig.macAddress}');
    return PrinterConfig(
      id:               'kitchen_printer',
      label:            'Kitchen Printer',
      type:             PrinterType.bluetooth,
      macAddress:       PrintConfig.macAddress,
      paperSize:        currentPaperSize,
      handledStations:  PrintConfig.stations,
      handlesBill:      true,
    );
  }

  print('🖨️ USB Printer → ${PrintConfig.printerName} / vendor=${PrintConfig.usbVendorId}');
  return PrinterConfig(
    id:                 'kitchen_printer',
    label:              'Kitchen Printer',
    type:               PrinterType.usb,
    windowsPrinterName: PrintConfig.printerName,
    vendorId:           PrintConfig.usbVendorId,
    productId:          PrintConfig.usbProductId,
    paperSize:          currentPaperSize,
    handledStations:    PrintConfig.stations,
    handlesBill:        true,
  );
}

class PrintAgentApp extends StatelessWidget {
  final WindowsSocketService? windowsSocket;
  final PrintQueueManager? queueManager;

  const PrintAgentApp({
    super.key,
    required this.windowsSocket,
    required this.queueManager,
  });

  @override
  Widget build(BuildContext context) {
    // Gate the whole app behind login: no stored token → Login screen first.
    // Once logged in (or on a session that already has a token), go straight
    // to Home, same as before this gate was added.
    final isLoggedIn = PrintConfig.authToken.trim().isNotEmpty;

    return GetMaterialApp(
      title: 'Print Agent',
      theme: ThemeData.dark(useMaterial3: true),
      home: isLoggedIn
          ? HomeScreen(
              windowsSocket: windowsSocket,
              queueManager:  queueManager,
            )
          : LoginScreen(
              windowsSocket: windowsSocket,
              queueManager:  queueManager,
            ),
      debugShowCheckedModeBanner: false,
    );
  }
}
