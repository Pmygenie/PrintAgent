import 'dart:async';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'printer_driver.dart';

class BluetoothPrinterDriver implements PrinterDriver {
  final String macAddress;
  final _plugin = FlutterThermalPrinter.instance; // ✅ correct class name
  Printer? _printer;

  BluetoothPrinterDriver({required this.macAddress});

  @override
  Future<void> connect() async {
    final completer = Completer<Printer>();

    // Start scan
    await _plugin.getPrinters(
      connectionTypes: [ConnectionType.BLE],
    );

    // Listen to stream and find by MAC
    final sub = _plugin.devicesStream.listen((List<Printer> found) {
      for (final p in found) {
        if (p.address == macAddress && !completer.isCompleted) {
          completer.complete(p);
        }
      }
    });

    // Wait max 10 seconds
    _printer = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        sub.cancel();
        _plugin.stopScan();
        throw Exception('❌ BT printer not found: $macAddress');
      },
    );

    await sub.cancel();
    await _plugin.stopScan();
    await _plugin.connect(_printer!);
    print('✅ BT connected: $macAddress');
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    if (_printer == null) throw Exception('BT printer not connected');
    await _plugin.printData(
      _printer!,
      bytes,
      longData: true, // handles large ESC/POS data in chunks
    );
  }

  @override
  Future<void> disconnect() async {
    if (_printer != null) {
      await _plugin.disconnect(_printer!);
      _printer = null;
    }
  }
}