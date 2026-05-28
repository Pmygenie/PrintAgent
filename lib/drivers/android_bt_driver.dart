// import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
// import 'printer_driver.dart';

// class AndroidBluetoothDriver implements PrinterDriver {
//   final String macAddress;
//   final _manager = PrinterManager.instance;

//   AndroidBluetoothDriver({required this.macAddress});

//   @override
//   Future<void> connect() async {
//     final devices = await _manager
//         .discovery(type: PrinterType.bluetooth).toList();
//     final target  = devices.firstWhere(
//       (d) => d.address == macAddress,
//       orElse: () => throw Exception('BT printer not found: $macAddress'),
//     );
//     await _manager.connect(
//       type: PrinterType.bluetooth,
//       model: BluetoothPrinterInput(
//         name: target.name ?? '',
//         address: target.address!,
//         isBle: false,
//         autoConnect: false,
//       ),
//     );
//   }

//   @override
//   Future<void> sendBytes(List<int> bytes) async {
//     await _manager.send(type: PrinterType.bluetooth, bytes: bytes);
//   }

//   @override
//   Future<void> disconnect() async {
//     await _manager.disconnect(type: PrinterType.bluetooth);
//   }
// }