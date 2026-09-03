import 'dart:async';

import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';

import 'printer_driver.dart';

class UsbPrinterDriver implements PrinterDriver {
  final int vendorId;
  final int productId;
  final _plugin = FlutterThermalPrinter.instance;
  Printer? _printer;

  UsbPrinterDriver({required this.vendorId, required this.productId});

  bool _matches(Printer p) {
    final vid = int.tryParse(p.vendorId ?? '') ?? 0;
    final pid = int.tryParse(p.productId ?? '') ?? 0;
    if (vid != vendorId) return false;
    if (productId == 0) return true;
    return pid == productId;
  }

  @override
  Future<void> connect() async {
    final completer = Completer<Printer>();

    await _plugin.getPrinters(connectionTypes: [ConnectionType.USB]);

    final sub = _plugin.devicesStream.listen((List<Printer> found) {
      for (final p in found) {
        if (_matches(p) && !completer.isCompleted) {
          completer.complete(p);
        }
      }
    });

    _printer = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        sub.cancel();
        _plugin.stopScan();
        throw Exception(
          '❌ USB printer not found (vendor:$vendorId product:$productId)',
        );
      },
    );

    await sub.cancel();
    await _plugin.stopScan();
    await _plugin.connect(_printer!);
    print('✅ USB connected: ${_printer!.name} (vendor:$vendorId product:$productId)');
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    if (_printer == null) throw Exception('USB printer not connected');
    await _plugin.printData(_printer!, bytes, longData: true);
  }

  @override
  Future<void> disconnect() async {
    if (_printer != null) {
      await _plugin.disconnect(_printer!);
      _printer = null;
    }
  }
}
