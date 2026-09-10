import 'dart:async';
import 'dart:io';

import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:printer_agent/core/printer/bluetooth_address.dart';
import 'package:printer_agent/core/printer/op_timeout.dart';

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

  /// Cached per GATT connection — cleared on [disconnect], never reused across
  /// connections. Writing through it directly (instead of `printData`) is what
  /// makes failures throw: the plugin swallows every BLE write error.
  BleCharacteristic? _writeChar;
  bool _writeAcknowledged = false;
  int _mtu = 0;

  /// Serializes BLE scans so stop/start cannot overlap across printers.
  static Future<void> _scanTail = Future<void>.value();

  BluetoothPrinterDriver({required this.macAddress});

  /// Real GATT state, not just "we hold a handle" — a link can drop without
  /// this driver being told.
  Future<bool> get isConnected async {
    final printer = _printer;
    if (printer == null || _writeChar == null) return false;
    try {
      final state = await UniversalBle.getConnectionState(printer.deviceId);
      return state == BleConnectionState.connected;
    } catch (_) {
      return false;
    }
  }

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

        await _prepareWriteChannel(_printer!);
      } catch (e) {
        _printer = null;
        _writeChar = null;
        rethrow;
      } finally {
        await sub?.cancel();
        try {
          await _plugin.stopScan();
        } catch (_) {}
      }
    });
  }

  /// Negotiates MTU and caches the writable characteristic.
  ///
  /// MTU and characteristic-selection order mirror the plugin's `printData`
  /// exactly (including its last-match loop), so devices that print today
  /// resolve to the same characteristic.
  Future<void> _prepareWriteChannel(Printer printer) async {
    _mtu = Platform.isWindows
        ? 50
        : await printer.requestMtu(Platform.isMacOS ? 150 : 500);
    print('[BT] MTU $_mtu $_logMac');

    final services = await printer.discoverServices(
      timeout: OpTimeout.bleDiscover,
    );

    BleCharacteristic? pick(CharacteristicProperty property) {
      BleCharacteristic? found;
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.properties.contains(property)) {
            found = characteristic;
            break;
          }
        }
      }
      return found;
    }

    final acknowledged = pick(CharacteristicProperty.write);
    if (acknowledged != null) {
      _writeChar = acknowledged;
      _writeAcknowledged = true;
      print('[BT] WRITE CHAR ${acknowledged.uuid} (acknowledged) $_logMac');
      return;
    }

    final fireAndForget = pick(CharacteristicProperty.writeWithoutResponse);
    if (fireAndForget != null) {
      _writeChar = fireAndForget;
      _writeAcknowledged = false;
      print(
        '[BT] ⚠️ FALLBACK write-without-response ${fireAndForget.uuid} $_logMac'
        ' — writes are not acknowledged by the printer, so a successful send'
        ' does NOT confirm anything was printed',
      );
      return;
    }

    throw Exception(
      '❌ No writable BLE characteristic on $_logMac — cannot print',
    );
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    if (_printer == null || _writeChar == null) {
      throw Exception('BT printer not connected');
    }

    if (bytes.isEmpty) {
      print('❌ ERROR: Byte array is empty! Aborting print.');
      return;
    }

    print('📦 BT BLE payload: ${bytes.length} bytes');

    final characteristic = _writeChar!;
    final withResponse = _writeAcknowledged;
    // Image blocks are deliberately left uncut by chunkSafely, so a chunk can
    // exceed one BLE write. Fragment here exactly as printData does.
    final maxWrite = (_mtu - 3) < 20 ? 20 : _mtu - 3;

    await EscPosBluetoothTransport.send(
      bytes: bytes,
      maxChunk: 64,
      chunkDelay: const Duration(milliseconds: 50),
      settleDelay: const Duration(milliseconds: 2000),
      write: (chunk) async {
        for (var i = 0; i < chunk.length; i += maxWrite) {
          final end =
              (i + maxWrite > chunk.length) ? chunk.length : i + maxWrite;
          await characteristic.write(
            chunk.sublist(i, end),
            withResponse: withResponse,
            timeout: OpTimeout.bleWrite,
          );
        }
      },
    );
  }

  @override
  Future<void> disconnect() async {
    final printer = _printer;
    _writeChar = null;
    _writeAcknowledged = false;
    _mtu = 0;
    if (printer == null) return;
    _printer = null;
    try {
      await _plugin.disconnect(printer);
    } catch (_) {}
    print('[BT] DISCONNECTED $_logMac');
  }
}
