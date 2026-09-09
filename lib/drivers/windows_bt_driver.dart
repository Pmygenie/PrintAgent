import 'dart:typed_data';

import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';
import 'package:printer_agent/core/printer/bluetooth_address.dart';
import 'package:printer_agent/core/printer/op_timeout.dart';

import 'escpos_bluetooth_send.dart';
import 'printer_driver.dart';

/// Windows classic Bluetooth (SPP) driver via [ThermalPrinterWindows].
class WindowsBluetoothDriver implements PrinterDriver {
  final String macAddress;
  final _api = ThermalPrinterWindows.instance;
  BluetoothPrinter? _printer;

  WindowsBluetoothDriver({required this.macAddress});

  BluetoothPrinter? _match(Iterable<BluetoothPrinter> devices) {
    for (final d in devices) {
      if (BluetoothAddress.samePrinter(d.macAddress, macAddress) ||
          BluetoothAddress.samePrinter(d.id, macAddress)) {
        return d;
      }
    }
    return null;
  }

  @override
  Future<void> connect() async {
    BluetoothPrinter? target = _match(await bounded(
      _api.getPairedPrinters(),
      OpTimeout.sppDiscover,
      'SPP paired-printer lookup',
    ));

    if (target == null) {
      final scanned = await _api.scanForPrinters(
        timeout: const Duration(seconds: 20),
      );
      target = _match(scanned);
    }

    if (target == null) {
      throw Exception('❌ Windows BT (SPP) printer not found: $macAddress');
    }

    if (!target.isPaired) {
      await bounded(
        _api.pairPrinter(target),
        OpTimeout.sppPair,
        'SPP pair $macAddress',
      );
    }
    await bounded(
      _api.connect(target),
      OpTimeout.sppConnect,
      'SPP connect $macAddress',
    );
    _printer = target;
    print('✅ Windows SPP connected: $macAddress');
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    if (_printer == null) throw Exception('Windows BT printer not connected');
    if (bytes.isEmpty) {
      print('❌ ERROR: Byte array is empty! Aborting print.');
      return;
    }

    print('📦 BT SPP payload: ${bytes.length} bytes');

    final printer = _printer!;
    // SPP: pace writes; settle long enough for last QR to finish printing.
    await EscPosBluetoothTransport.send(
      bytes: bytes,
      maxChunk: 512,
      chunkDelay: const Duration(milliseconds: 60),
      settleDelay: const Duration(milliseconds: 2000),
      writeTimeout: OpTimeout.sppWrite,
      write: (chunk) => _api.printRawBytes(
        printer,
        Uint8List.fromList(chunk),
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    final printer = _printer;
    _printer = null;
    if (printer == null) return;
    await bounded(
      _api.disconnect(printer),
      OpTimeout.sppDisconnect,
      'SPP disconnect $macAddress',
    );
  }
}
