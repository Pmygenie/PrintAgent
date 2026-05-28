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
import 'package:permission_handler/permission_handler.dart';

import 'core/config/print_config.dart';
import 'core/models/printer_config.dart';
import 'core/printer/printer_manager.dart';
import 'core/queue/print_queue.dart';
import 'core/socket/windows_socket_service.dart';
import 'core/background/background_service.dart';
import 'core/profile/restaurant_profile_api.dart';
import 'core/profile/restaurant_profile_repository.dart';
import 'core/profile/restaurant_profile_store.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load saved config
  await PrintConfig.load();
  final savedPrinters = await PrinterConfigStorage.load();

  // ✅ NEW — sync restaurant profile in background
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
    print('🔌 Android USB → vendorId=${PrintConfig.usbVendorId} productId=${PrintConfig.usbProductId}');
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();

    await initBackgroundService();

    // ✅ Android — LAN or USB based on connectionType
    final androidPrinters = savedPrinters.isNotEmpty
        ? savedPrinters
        : [_buildDefaultPrinterConfig()];

    final androidManager = PrinterManager()..registerAll(androidPrinters);
    final androidQueue = PrintQueue(androidManager);
    final androidSocket = WindowsSocketService(androidQueue)..connect();

    runApp(PrintAgentApp(windowsSocket: androidSocket, queue: androidQueue));
    return;
  }

  // 4. Windows → socket in main isolate
  // ✅ LAN or USB based on connectionType
  final printers = savedPrinters.isNotEmpty
      ? savedPrinters
      : [_buildDefaultPrinterConfig()];

  final manager = PrinterManager()..registerAll(printers);
  final queue = PrintQueue(manager);
  final socket = WindowsSocketService(queue)..connect();

  runApp(PrintAgentApp(windowsSocket: socket, queue: queue));
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

// ✅ NEW — builds PrinterConfig from PrintConfig.connectionType
PrinterConfig _buildDefaultPrinterConfig() {
  if (PrintConfig.connectionType == PrinterConnectionType.lan) {
    print('🌐 LAN Printer → ${PrintConfig.lanIp}:${PrintConfig.lanPort}');
    return PrinterConfig(
      id: 'kitchen_printer',
      label: 'Kitchen Printer',
      type: PrinterType.lan,
      ipAddress: PrintConfig.lanIp,
      port: PrintConfig.lanPort,
      paperSize: PrintConfig.paperSize,
    );
  }

  // USB — Windows or Android
  print('🖨️ USB Printer → ${PrintConfig.printerName} / vendor=${PrintConfig.usbVendorId}');
  return PrinterConfig(
    id: 'kitchen_printer',
    label: 'Kitchen Printer',
    type: PrinterType.usb,
    windowsPrinterName: PrintConfig.printerName,
    vendorId: PrintConfig.usbVendorId,
    productId: PrintConfig.usbProductId,
    paperSize: PrintConfig.paperSize,
  );
}

class PrintAgentApp extends StatelessWidget {
  final WindowsSocketService? windowsSocket;
  final PrintQueue? queue;

  const PrintAgentApp({
    super.key,
    required this.windowsSocket,
    required this.queue,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Print Agent',
      theme: ThemeData.dark(useMaterial3: true),
      home: HomeScreen(
        windowsSocket: windowsSocket,
        queue: queue,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}