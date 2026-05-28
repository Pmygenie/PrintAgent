// import 'dart:async';
// import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
// import 'package:flutter_thermal_printer/utils/printer.dart';
// import 'printer_driver.dart';

// class UsbPrinterDriver implements PrinterDriver {
//   final String vendorId;
//   final String productId;
//   final _plugin = FlutterThermalPrinter.instance; // ✅ correct
//   Printer? _printer;

//   UsbPrinterDriver({required this.vendorId, required this.productId});

//   @override
//   Future<void> connect() async {
//     final completer = Completer<Printer>();

//     await _plugin.getPrinters(
//       connectionTypes: [ConnectionType.USB],
//     );

//     final sub = _plugin.devicesStream.listen((List<Printer> found) {
//       for (final p in found) {
//         if (p.vendorId  == vendorId
//          && p.productId == productId
//          && !completer.isCompleted) {
//           completer.complete(p);
//         }
//       }
//     });

//     _printer = await completer.future.timeout(
//       const Duration(seconds: 8),
//       onTimeout: () {
//         sub.cancel();
//         _plugin.stopScan();
//         throw Exception('❌ USB printer not found (vendor:$vendorId)');
//       },
//     );

//     await sub.cancel();
//     await _plugin.stopScan();
//     await _plugin.connect(_printer!);
//     print('✅ USB connected: vendor=$vendorId');
//   }

//   @override
//   Future<void> sendBytes(List<int> bytes) async {
//     if (_printer == null) throw Exception('USB printer not connected');
//     await _plugin.printData(_printer!, bytes, longData: true);
//   }

//   @override
//   Future<void> disconnect() async {
//     if (_printer != null) {
//       await _plugin.disconnect(_printer!);
//       _printer = null;
//     }
//   }
// }

import 'dart:typed_data';

import 'package:thermal_printer_plus/thermal_printer.dart';

import 'printer_driver.dart';

class UsbPrinterDriver implements PrinterDriver {
  final int vendorId;
  final int productId;
  bool _connected = false;

  UsbPrinterDriver({required this.vendorId, required this.productId});

  @override
  Future<void> connect() async {
    // ✅ Discover USB devices
    final devices = <PrinterDevice>[];
    PrinterManager.instance
        .discovery(type: PrinterType.usb)
        .listen((device) => devices.add(device));

    // Wait for scan to complete
    await Future.delayed(const Duration(seconds: 3));

    print('📋 USB devices found: ${devices.length}');
    for (final d in devices) {
      print('  → name=${d.name} vendor=${d.vendorId} product=${d.productId}');
    }

    final match = devices.firstWhere(
      (d) => d.vendorId == vendorId.toString(),
      orElse: () => throw Exception('❌ Printer not found (vendor:$vendorId)'),
    );

    // ✅ Connect directly by vendorId + productId
    await PrinterManager.instance.connect(
      type: PrinterType.usb,
      model: UsbPrinterInput(
        name: match.name,
        vendorId: match.vendorId,
        productId: match.productId,
      ),
    );

    _connected = true;
    print('✅ USB connected: ${match.name}');
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    if (!_connected) throw Exception('USB printer not connected');
    await PrinterManager.instance.send(
      type: PrinterType.usb,
      bytes: bytes,
    );
  }

  @override
  Future<void> disconnect() async {
    await PrinterManager.instance.disconnect(type: PrinterType.usb);
    _connected = false;
  }
}
