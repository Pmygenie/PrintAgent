import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart'
    as spp;
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/printer_config.dart';
import 'package:printer_agent/core/printer/bluetooth_address.dart';
import 'package:printer_agent/core/queue/print_queue_manager.dart';
import 'package:printer_agent/drivers/escpos_bluetooth_send.dart';
import 'package:printer_agent/drivers/windows_usb_driver.dart';

enum DiagnosticConnectionType { usb, bluetooth }

/// Unified row for USB / BLE / classic-SPP discovery results.
class _FoundDevice {
  final String name;
  final String address;
  /// Short MAC for UI (e.g. 28:D0:EA:6E:00:31). Falls back to [address].
  final String displayAddress;
  final BluetoothMode? btMode;
  final Printer? thermal; // USB or BLE from flutter_thermal_printer
  final spp.BluetoothPrinter? sppPrinter;

  const _FoundDevice({
    required this.name,
    required this.address,
    String? displayAddress,
    this.btMode,
    this.thermal,
    this.sppPrinter,
  }) : displayAddress = displayAddress ?? address;
}

class DiagnosticsScreen extends StatefulWidget {
  final PrintQueueManager? queueManager;

  /// When opened from Settings Bluetooth scan.
  final DiagnosticConnectionType initialMode;
  final bool autoStartDiscover;

  /// If true, Step 3 pops with [BluetoothScanResult] instead of writing global config.
  final bool returnResult;

  const DiagnosticsScreen({
    super.key,
    this.queueManager,
    this.initialMode = DiagnosticConnectionType.usb,
    this.autoStartDiscover = false,
    this.returnResult = false,
  });

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _plugin = FlutterThermalPrinter.instance;
  final List<_FoundDevice> _foundDevices = [];
  _FoundDevice? _connectedDevice;
  final List<String> _logs = [];

  bool _scanning = false;
  bool _isSaving = false;
  late DiagnosticConnectionType _mode;

  StreamSubscription<List<Printer>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    if (widget.autoStartDiscover) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) testDiscovery();
      });
    }
  }

  void _log(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, '[${_timestamp()}] $msg');
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  String _timestamp() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  static String _normMac(String address) =>
      BluetoothAddress.normalize(address);

  /// Printer MAC (remote / last) — matches Android.
  static String? _extractMac(String raw) =>
      BluetoothAddress.extractPrinterMac(raw);

  static String _shortMacLabel(String raw) =>
      BluetoothAddress.displayMac(raw);

  /// Prefer real Bluetooth name; otherwise "Printer XX:XX:…".
  static String _friendlyBtName(
    String? name,
    String address, {
    String? pairedName,
  }) {
    bool usable(String? s) {
      if (s == null) return false;
      final t = s.trim();
      if (t.isEmpty) return false;
      final lower = t.toLowerCase();
      if (lower == 'bluetooth printer' ||
          lower == 'ble printer' ||
          lower == 'n/a' ||
          lower == 'unknown' ||
          lower == 'unknown printer') {
        return false;
      }
      if (t.startsWith('Bluetooth#')) return false;
      return true;
    }

    if (usable(name)) return name!.trim();
    if (usable(pairedName)) return pairedName!.trim();
    final mac = _extractMac(address);
    if (mac != null) return 'Printer $mac';
    return 'Bluetooth Printer';
  }

  static bool _isGenericName(String name) {
    final lower = name.trim().toLowerCase();
    return lower.isEmpty ||
        lower == 'bluetooth printer' ||
        lower == 'ble printer' ||
        lower.startsWith('printer ') ||
        lower.startsWith('bluetooth#');
  }

  void _upsertDevice(_FoundDevice device) {
    final key = _normMac(_extractMac(device.address) ?? device.address);
    final idx = _foundDevices.indexWhere(
      (d) =>
          BluetoothAddress.samePrinter(d.address, device.address) ||
          _normMac(_extractMac(d.address) ?? d.address) == key,
    );
    if (idx >= 0) {
      final existing = _foundDevices[idx];
      // Prefer keeping SPP if already present; otherwise update.
      if (existing.btMode == BluetoothMode.classicSpp &&
          device.btMode == BluetoothMode.ble) {
        // Still upgrade name if we got a better one from BLE.
        if (_isGenericName(existing.name) && !_isGenericName(device.name)) {
          _foundDevices[idx] = _FoundDevice(
            name: device.name,
            address: existing.address,
            displayAddress: existing.displayAddress,
            btMode: existing.btMode,
            thermal: existing.thermal ?? device.thermal,
            sppPrinter: existing.sppPrinter,
          );
        }
        return;
      }
      // Prefer better (non-generic) name when replacing.
      final betterName = (!_isGenericName(device.name) ||
              _isGenericName(existing.name))
          ? device.name
          : existing.name;
      _foundDevices[idx] = _FoundDevice(
        name: betterName,
        address: device.address,
        displayAddress: device.displayAddress,
        btMode: device.btMode ?? existing.btMode,
        thermal: device.thermal ?? existing.thermal,
        sppPrinter: device.sppPrinter ?? existing.sppPrinter,
      );
    } else {
      _foundDevices.add(device);
    }
  }

  /// Windows WinBle init races — retry getPrinters until ready.
  Future<void> _startBleScanWithRetry() async {
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
        _log('⏳ BLE init… retry ${attempt + 1}');
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    throw lastError ?? Exception('BLE scan failed to initialize');
  }

  // ── TEST 1 — Discovery ─────────────────────────────────
  Future<void> testDiscovery() async {
    setState(() {
      _foundDevices.clear();
      _scanning = true;
      _connectedDevice = null;
    });

    if (_mode == DiagnosticConnectionType.usb) {
      await _discoverUsb();
    } else {
      await _discoverBluetooth();
    }
  }

  Future<void> _discoverUsb() async {
    _log('🔍 Scanning for USB printers...');
    try {
      await _plugin.getPrinters(connectionTypes: [ConnectionType.USB]);
      await _scanSubscription?.cancel();
      _scanSubscription = _plugin.devicesStream.listen((List<Printer> printers) {
        if (!mounted) return;
        setState(() {
          _foundDevices
            ..clear()
            ..addAll(printers
                .where((p) => p.connectionType == ConnectionType.USB)
                .map((p) => _FoundDevice(
                      name: p.name ?? 'Unknown Printer',
                      address: p.address ?? p.name ?? '',
                      thermal: p,
                    )));
          _scanning = false;
        });
        if (_foundDevices.isEmpty) {
          _log('❌ No USB printers found');
        } else {
          for (final p in _foundDevices) {
            _log('✅ Found: ${p.name} (${p.address})');
          }
        }
      });
    } catch (e) {
      _log('❌ Discovery error: $e');
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _discoverBluetooth() async {
    _log(Platform.isWindows
        ? '🔍 Scanning Bluetooth (BLE + Classic)…'
        : '🔍 Scanning Bluetooth (BLE)…');

    try {
      // BLE (all platforms)
      await _startBleScanWithRetry();
      await _scanSubscription?.cancel();
      _scanSubscription = _plugin.devicesStream.listen((List<Printer> printers) {
        if (!mounted || _mode != DiagnosticConnectionType.bluetooth) return;
        setState(() {
          for (final p in printers.where((p) => p.connectionType == ConnectionType.BLE)) {
            final addr = p.address;
            if (addr == null || addr.isEmpty) continue;
            final short = _shortMacLabel(addr);
            _upsertDevice(_FoundDevice(
              name: _friendlyBtName(p.name, addr),
              address: addr,
              displayAddress: short,
              btMode: BluetoothMode.ble,
              thermal: p,
            ));
          }
        });
      });

      // Classic SPP (Windows only) — parallel, no user prompt
      if (Platform.isWindows) {
        try {
          final sppApi = spp.ThermalPrinterWindows.instance;

          // Paired devices often have the friendly Windows name already.
          final pairedNameByMac = <String, String>{};
          try {
            for (final p in await sppApi.getPairedPrinters()) {
              final key = _normMac(
                _extractMac(p.macAddress) ??
                    _extractMac(p.id) ??
                    p.macAddress,
              );
              if (key.isNotEmpty && p.name.trim().isNotEmpty) {
                pairedNameByMac[key] = p.name.trim();
              }
            }
          } catch (_) {}

          final sppList = await sppApi.scanForPrinters(
            timeout: const Duration(seconds: 20),
          );
          if (mounted) {
            setState(() {
              for (final p in sppList) {
                final addr = p.macAddress.isNotEmpty ? p.macAddress : p.id;
                if (addr.isEmpty) continue;
                final short = _shortMacLabel(addr);
                final macKey = _normMac(_extractMac(addr) ?? addr);
                final displayName = _friendlyBtName(
                  p.name,
                  addr,
                  pairedName: pairedNameByMac[macKey],
                );
                _upsertDevice(_FoundDevice(
                  name: displayName,
                  address: addr,
                  displayAddress: short,
                  btMode: BluetoothMode.classicSpp,
                  sppPrinter: p,
                ));
                _log('✅ Found (Classic): $displayName ($short)');
              }
            });
          }
        } catch (e) {
          _log('⚠️ Classic BT scan: $e');
        }
      }

      // Let BLE stream collect for a bit, then finish scanning UI state
      await Future.delayed(
        Duration(seconds: Platform.isWindows ? 8 : 5),
      );

      if (!mounted) return;
      setState(() => _scanning = false);

      if (_foundDevices.isEmpty) {
        _log('❌ No Bluetooth printers found');
        _log('→ Turn Bluetooth on, put printer in pairing mode, retry');
      } else {
        _log('✅ Discovery done — ${_foundDevices.length} device(s)');
      }
    } catch (e) {
      if (e.toString().contains('Location')) {
        _log('❌ Turn on phone Location/GPS for Bluetooth scan!');
      } else {
        _log('❌ Discovery error: $e');
      }
      if (mounted) setState(() => _scanning = false);
    }
  }

  // ── TEST 2 — Connect ───────────────────────────────────
  Future<void> testConnect(_FoundDevice device) async {
    _log('🔌 Connecting to ${device.name}...');
    try {
      if (device.btMode == BluetoothMode.classicSpp && device.sppPrinter != null) {
        final api = spp.ThermalPrinterWindows.instance;
        var target = device.sppPrinter!;
        if (!target.isPaired) {
          _log('🔗 Pairing…');
          await api.pairPrinter(target);
        }
        await api.connect(target);
        setState(() => _connectedDevice = device);
        _log('✅ Connected (Classic SPP) to ${device.name}');
        return;
      }

      if (device.thermal == null) {
        throw Exception('No printable device handle');
      }
      await _plugin.connect(device.thermal!);
      setState(() => _connectedDevice = device);
      _log('✅ Connected to ${device.name}');
    } catch (e) {
      _log('❌ Connect failed: $e');
    }
  }

  // ── TEST 3 — Test Print ────────────────────────────────
  Future<void> testPrint() async {
    final device = _connectedDevice;
    if (device == null) {
      _log('⚠️ Connect to a printer first');
      return;
    }

    _log('🖨️ Generating ESC/POS payload...');
    try {
      final profile = await CapabilityProfile.load();
      final gen = Generator(
        PrintConfig.is80mm ? PaperSize.mm80 : PaperSize.mm58,
        profile,
      );
      List<int> bytes = [];

      bytes += gen.text('=== DIAGNOSTICS TEST ===',
          styles: const PosStyles(
              bold: true, align: PosAlign.center, height: PosTextSize.size2));
      bytes += gen.hr();
      bytes += gen.text('Platform : ${Platform.operatingSystem}');
      bytes += gen.text(
          'Type     : ${_mode == DiagnosticConnectionType.usb ? "USB" : "Bluetooth"}');
      if (device.btMode != null) {
        bytes += gen.text(
            'BT Mode  : ${device.btMode == BluetoothMode.classicSpp ? "Classic" : "BLE"}');
      }
      bytes += gen.text('Printer  : ${device.name}');
      bytes += gen.text('Address  : ${device.address}');
      bytes += gen.text('Time     : ${DateTime.now()}');
      bytes += gen.hr();
      bytes += gen.text('Diagnostics Successful!',
          styles: const PosStyles(align: PosAlign.center));
      bytes += gen.feed(2);
      bytes += gen.cut();

      _log('📦 Payload: ${bytes.length} bytes');

      if (device.btMode == BluetoothMode.classicSpp && device.sppPrinter != null) {
        final printer = device.sppPrinter!;
        await EscPosBluetoothTransport.send(
          bytes: bytes,
          maxChunk: 512,
          chunkDelay: const Duration(milliseconds: 20),
          write: (chunk) => spp.ThermalPrinterWindows.instance.printRawBytes(
            printer,
            Uint8List.fromList(chunk),
          ),
        );
      } else if (device.thermal != null) {
        final printer = device.thermal!;
        final isBle = _mode == DiagnosticConnectionType.bluetooth;
        if (isBle) {
          await EscPosBluetoothTransport.send(
            bytes: bytes,
            maxChunk: 64,
            chunkDelay: const Duration(milliseconds: 50),
            write: (chunk) =>
                _plugin.printData(printer, chunk, longData: false),
          );
        } else {
          await _plugin.printData(printer, bytes, longData: true);
        }
      } else {
        throw Exception('No printable device handle');
      }

      _log('✅ Test print sent!');
    } catch (e) {
      _log('❌ Print failed: $e');
      _log('→ Try disconnect → reconnect.');
    }
  }

  // ── STEP 4 — Save / return result ──────────────────────
  Future<void> saveToSettings() async {
    final device = _connectedDevice;
    if (device == null) return;

    if (device.address.isEmpty) {
      _log('❌ Printer address is empty — cannot save');
      return;
    }

    // Always persist the printer MAC (remote) — matches Android.
    final targetAddress = _mode == DiagnosticConnectionType.bluetooth
        ? (BluetoothAddress.extractPrinterMac(device.address) ??
            device.displayAddress)
        : device.address;

    if (targetAddress.isEmpty) {
      _log('❌ Printer address is empty — cannot save');
      return;
    }

    // Picker mode: return MAC (+ mode) to Edit Printer sheet
    if (widget.returnResult && _mode == DiagnosticConnectionType.bluetooth) {
      _log('💾 Returning MAC to printer form: $targetAddress');
      if (!mounted) return;
      Navigator.pop(
        context,
        BluetoothScanResult(
          macAddress: targetAddress,
          name: device.name,
          mode: device.btMode ?? BluetoothMode.ble,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    _log('💾 Saving configuration...');

    try {
      PrintConfig.connectionType = _mode == DiagnosticConnectionType.bluetooth
          ? PrinterConnectionType.bluetooth
          : PrinterConnectionType.usb;

      if (_mode == DiagnosticConnectionType.bluetooth) {
        PrintConfig.macAddress = targetAddress;
        _log('📶 MAC saved: $targetAddress');
      } else {
        final thermal = device.thermal;
        final vid = int.tryParse(thermal?.vendorId ?? '0') ?? 0;
        final pid = int.tryParse(thermal?.productId ?? '0') ?? 0;
        if (vid != 0) {
          PrintConfig.usbVendorId = vid;
          PrintConfig.usbProductId = pid;
          _log('🔌 USB IDs saved: vendor=$vid product=$pid');
        }
        if (device.name.isNotEmpty) {
          PrintConfig.printerName = device.name;
        }
      }

      await PrintConfig.save();
      _log('✅ PrintConfig saved to SharedPreferences');

      final paperSize = PrintConfig.is80mm ? PaperSize.mm80 : PaperSize.mm58;

      final updatedPrinterConfig = _mode == DiagnosticConnectionType.bluetooth
          ? PrinterConfig(
              id: 'kitchen_printer',
              label: 'Kitchen Printer',
              type: PrinterType.bluetooth,
              macAddress: targetAddress,
              bluetoothMode: device.btMode ?? BluetoothMode.ble,
              paperSize: paperSize,
            )
          : PrinterConfig(
              id: 'kitchen_printer',
              label: 'Kitchen Printer',
              type: PrinterType.usb,
              windowsPrinterName: PrintConfig.printerName,
              vendorId: PrintConfig.usbVendorId,
              productId: PrintConfig.usbProductId,
              paperSize: paperSize,
            );

      widget.queueManager?.registerPrinter(updatedPrinterConfig);
      _log('✅ Live QueueManager updated');

      await PrinterConfigStorage.save([updatedPrinterConfig]);
      _log('✅ PrinterConfigStorage (disk) updated');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎯 ${device.name} set as active printer via ${_mode.name.toUpperCase()}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _log('❌ Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> disconnect() async {
    final device = _connectedDevice;
    if (device == null) return;
    try {
      if (device.btMode == BluetoothMode.classicSpp && device.sppPrinter != null) {
        await spp.ThermalPrinterWindows.instance.disconnect(device.sppPrinter!);
      } else if (device.thermal != null) {
        await _plugin.disconnect(device.thermal!);
      }
      _log('🔌 Disconnected from ${device.name}');
      setState(() => _connectedDevice = null);
    } catch (e) {
      _log('❌ Disconnect error: $e');
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔧 Hardware Diagnostics')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          SegmentedButton<DiagnosticConnectionType>(
            segments: [
              ButtonSegment(
                value: DiagnosticConnectionType.usb,
                label: const Text('USB'),
                icon: const Icon(Icons.usb),
                // Hide USB as a choice when opened from Settings Bluetooth scan.
                enabled: !widget.returnResult,
              ),
              const ButtonSegment(
                value: DiagnosticConnectionType.bluetooth,
                label: Text('Bluetooth'),
                icon: Icon(Icons.bluetooth),
              ),
            ],
            selected: {_mode},
            // Keep enabled so the selected Bluetooth tab looks active
            // (null onSelectionChanged greys out the whole control).
            style: ButtonStyle(
              visualDensity: VisualDensity.comfortable,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.blueAccent.withValues(alpha: 0.35);
                }
                return null;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.lightBlueAccent;
                }
                return null;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const BorderSide(color: Colors.blueAccent, width: 1.5);
                }
                return null;
              }),
            ),
            onSelectionChanged: (v) {
              final next = v.first;
              // From Settings "Scan Bluetooth" — stay locked on Bluetooth.
              if (widget.returnResult &&
                  next != DiagnosticConnectionType.bluetooth) {
                return;
              }
              setState(() {
                _mode = next;
                _foundDevices.clear();
                _logs.clear();
              });
              if (_connectedDevice != null) disconnect();
            },
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (Platform.isWindows && _mode == DiagnosticConnectionType.usb)
              ElevatedButton.icon(
                icon: const Icon(Icons.list),
                label: const Text('List Windows Printers'),
                onPressed: () {
                  final names = WindowsUsbDriver.listPrinters();
                  if (names.isEmpty) {
                    _log('❌ No printers found in Windows');
                  } else {
                    for (final n in names) {
                      _log('🖨️  $n');
                    }
                  }
                },
              ),
            ElevatedButton.icon(
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(_scanning ? 'Scanning...' : 'Step 1: Discover'),
              onPressed: _scanning ? null : testDiscovery,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Step 2: Test Print'),
              onPressed: _connectedDevice != null ? testPrint : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.assignment_turned_in),
              label: Text(widget.returnResult
                  ? 'Step 3: Use This Printer'
                  : 'Step 3: Apply to Settings'),
              onPressed: _connectedDevice != null && !_isSaving
                  ? saveToSettings
                  : null,
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            ),
            if (_connectedDevice != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
                onPressed: disconnect,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
          ]),
          const SizedBox(height: 16),
          if (_foundDevices.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Found Hardware:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: _foundDevices.length,
                itemBuilder: (_, i) {
                  final p = _foundDevices[i];
                  final isCurrent = _connectedDevice != null &&
                      BluetoothAddress.samePrinter(
                          _connectedDevice!.address, p.address);
                  return Card(
                    color: isCurrent ? Colors.green.withOpacity(0.15) : null,
                    child: ListTile(
                      leading: Icon(_mode == DiagnosticConnectionType.usb
                          ? Icons.usb
                          : Icons.bluetooth),
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _mode == DiagnosticConnectionType.bluetooth
                            ? 'MAC: ${p.displayAddress}'
                            : 'ID/MAC: ${p.displayAddress}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isCurrent
                          ? const Chip(
                              label: Text('Active ✅',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              backgroundColor: Colors.green,
                            )
                          : ElevatedButton(
                              onPressed: () => testConnect(p),
                              child: const Text('Connect'),
                            ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Diagnostic Log:',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                          'Select a connection type and tap "Step 1: Discover"',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (_, i) => Text(
                        _logs[i],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}
