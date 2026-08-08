import 'dart:async';
import 'dart:io';

import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:printer_agent/core/printer/bluetooth_address.dart';

import 'escpos_bluetooth_send.dart';
import 'printer_driver.dart';

/// BLE thermal printer driver (Android + Windows via flutter_thermal_printer).
class BluetoothPrinterDriver implements PrinterDriver {
  final String macAddress;
  final _plugin = FlutterThermalPrinter.instance;
  Printer? _printer;

  BluetoothPrinterDriver({required this.macAddress});

  bool _matches(Printer p) {
    final addr = p.address;
    if (addr == null) return false;
    return BluetoothAddress.samePrinter(addr, macAddress);
  }

  /// Windows WinBle init races — retry until ready.
  Future<void> _startBleScan() async {
    Object? lastError;
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        await _plugin.getPrinters(connectionTypes: [ConnectionType.BLE]);
        return;
      } catch (e) {
        lastError = e;
        final msg = e.toString().toLowerCase();
        if (!msg.contains('not initialized') && !msg.contains('try starting')) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    throw lastError ?? Exception('BLE scan failed to initialize');
  }

  @override
  Future<void> connect() async {
    final completer = Completer<Printer>();

    await _startBleScan();

    final sub = _plugin.devicesStream.listen((List<Printer> found) {
      for (final p in found) {
        if (_matches(p) && !completer.isCompleted) {
          completer.complete(p);
        }
      }
    });

    _printer = await completer.future.timeout(
      Duration(seconds: Platform.isWindows ? 20 : 10),
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

    if (bytes.isEmpty) {
      print('❌ ERROR: Byte array is empty! Aborting print.');
      return;
    }

    print('📦 BT BLE payload: ${bytes.length} bytes');

    final printer = _printer!;
    await EscPosBluetoothTransport.send(
      bytes: bytes,
      maxChunk: 64,
      chunkDelay: const Duration(milliseconds: 50),
      settleDelay: const Duration(milliseconds: 2000),
      write: (chunk) => _plugin.printData(printer, chunk, longData: false),
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
