import 'dart:async';
import 'dart:io';

import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:printer_agent/core/printer/bluetooth_address.dart';

import 'escpos_bluetooth_send.dart';
import 'printer_driver.dart';

/// BLE thermal printer driver (Android + Windows via flutter_thermal_printer).
///
/// Connection lifecycle for keep-alive is owned by [BleSessionRegistry].
/// [connect] performs a clean scan→match→stopScan→GATT connect. Scans are
/// serialized process-wide to avoid Android "could not find callback wrapper".
class BluetoothPrinterDriver implements PrinterDriver {
  final String macAddress;
  final _plugin = FlutterThermalPrinter.instance;
  Printer? _printer;

  /// Serializes BLE scans so stop/start cannot overlap across printers.
  static Future<void> _scanTail = Future<void>.value();

  BluetoothPrinterDriver({required this.macAddress});

  bool get isConnected => _printer != null;

  String get _logMac =>
      BluetoothAddress.extractPrinterMac(macAddress) ??
      BluetoothAddress.displayMac(macAddress);

  bool _matches(Printer p) {
    final addr = p.address;
    if (addr == null) return false;
    return BluetoothAddress.samePrinter(addr, macAddress);
  }

  /// flutter_thermal_printer 1.2.4+ uses `universal_ble` on every platform
  /// (including Windows), which manages its own init state safely — repeated
  /// calls to `getPrinters()` no longer race or throw "already initialized".
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

  static Future<T> _withScanExclusive<T>(Future<T> Function() action) async {
    final previous = _scanTail;
    final gate = Completer<void>();
    _scanTail = gate.future;
    await previous;
    try {
      return await action();
    } finally {
      // Let Android tear down the scanner callback before the next startScan.
      await Future.delayed(const Duration(milliseconds: 350));
      if (!gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<void> connect() async {
    await _withScanExclusive(() async {
      final completer = Completer<Printer>();
      StreamSubscription<List<Printer>>? sub;

      try {
        // Listen BEFORE starting scan — devicesStream is broadcast (no replay).
        sub = _plugin.devicesStream.listen((List<Printer> found) {
          for (final p in found) {
            if (_matches(p) && !completer.isCompleted) {
              completer.complete(p);
            }
          }
        });

        await _startBleScan();

        _printer = await completer.future.timeout(
          Duration(seconds: Platform.isWindows ? 20 : 25),
          onTimeout: () {
            throw Exception('❌ BT printer not found: $macAddress');
          },
        );

        await _plugin.stopScan();
        await Future.delayed(const Duration(milliseconds: 200));

        await _plugin.connect(_printer!);
        print('[BT] GATT CONNECTED $_logMac');
      } catch (e) {
        _printer = null;
        rethrow;
      } finally {
        await sub?.cancel();
        try {
          await _plugin.stopScan();
        } catch (_) {}
      }
    });
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
    final printer = _printer;
    if (printer == null) return;
    _printer = null;
    try {
      await _plugin.disconnect(printer);
    } catch (_) {}
    print('[BT] DISCONNECTED $_logMac');
  }
}
