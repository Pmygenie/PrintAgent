import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer_platform_interface.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';

import 'printer_driver.dart';

/// Android USB printing.
///
/// The native side resolves the device, requests permission, opens it, writes
/// and closes on every `printData` call — so no scan subscription and no
/// `connect()` are needed. Avoiding both matters: the plugin's `connect()`
/// pushes the permission result into an EventChannel sink that is only alive
/// while a scan is running, which throws NullPointerException otherwise.
class UsbPrinterDriver implements PrinterDriver {
  final int vendorId;
  final int productId;
  final _plugin = FlutterThermalPrinter.instance;
  Printer? _printer;

  UsbPrinterDriver({required this.vendorId, required this.productId});

  bool get isConnected => _printer != null;

  static int _parseId(Object? raw) {
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return 0;
    return int.tryParse(s) ??
        int.tryParse(s.replaceFirst(RegExp(r'^0x'), ''), radix: 16) ??
        0;
  }

  /// Confirms the device is attached, then builds the handle `printData` needs.
  ///
  /// Uses a one-shot device list (a plain method-channel call) instead of the
  /// devices stream — the stream drops any device whose USB product name is
  /// null, which is common on unbranded thermal printers.
  @override
  Future<void> connect() async {
    final devices = await FlutterThermalPrinterPlatform.instance.startUsbScan();

    final seen = <String>[];
    var attached = false;
    var hasPermission = false;

    if (devices is List) {
      for (final raw in devices) {
        if (raw is! Map) continue;
        final vid = _parseId(raw['vendorId']);
        final pid = _parseId(raw['productId']);
        seen.add(
          'name=${raw['name']} vendor=$vid product=$pid connected=${raw['connected']}',
        );
        if (vid == vendorId && (productId == 0 || pid == productId)) {
          attached = true;
          hasPermission = raw['connected'] == true;
        }
      }
    }

    if (!attached) {
      print('📋 USB devices attached (${seen.length}):');
      for (final line in seen) {
        print('  → $line');
      }
      throw Exception(
        '❌ USB printer not found (vendor:$vendorId product:$productId)',
      );
    }

    // Native printText() would call requestPermission() here, and its
    // PendingIntent is an Activity — that pulls the app to the foreground over
    // whatever the user is doing, and prints nothing anyway (the permission
    // request is async). Fail the job instead and let Diagnostics grant it.
    if (!hasPermission) {
      throw Exception(
        '❌ USB permission missing. Please grant permission from Diagnostics.',
      );
    }

    _printer = Printer(
      vendorId: '$vendorId',
      productId: '$productId',
      address: '$vendorId',
      connectionType: ConnectionType.USB,
    );
    print('✅ USB ready: vendor:$vendorId product:$productId');
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    if (_printer == null) throw Exception('USB printer not connected');
    await _plugin.printData(_printer!, bytes, longData: true);
  }

  /// No-op: the native layer closes the USB connection after every write.
  @override
  Future<void> disconnect() async {
    _printer = null;
  }
}
