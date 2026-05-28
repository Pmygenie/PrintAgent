// import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';
// import 'printer_driver.dart';

// class WindowsBluetoothDriver implements PrinterDriver {
//   final String macAddress;
//   final _printer = FlutterThermalPrinterWindows.instance;

//   WindowsBluetoothDriver({required this.macAddress});

//   @override
//   Future<void> connect() async {
//     final devices = await _printer.scan();
//     final target  = devices.firstWhere(
//       (d) => d.address == macAddress,
//       orElse: () => throw Exception('Windows BT printer not found'),
//     );
//     await _printer.connect(target);
//   }

//   @override
//   Future<void> sendBytes(List<int> bytes) async {
//     await _printer.writeBytes(bytes);
//   }

//   @override
//   Future<void> disconnect() async {
//     await _printer.disconnect();
//   }
// }