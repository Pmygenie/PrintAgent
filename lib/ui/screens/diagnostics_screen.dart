import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/printer_config.dart';
import 'package:printer_agent/core/printer/pdf_formatter.dart';
import 'package:printer_agent/core/queue/print_queue_manager.dart';
import 'package:printer_agent/drivers/windows_usb_driver.dart';
import 'package:printing/printing.dart' hide Printer;

enum DiagnosticConnectionType { usb, bluetooth }

class DiagnosticsScreen extends StatefulWidget {
  final PrintQueueManager? queueManager;

  const DiagnosticsScreen({super.key, this.queueManager});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _plugin = FlutterThermalPrinter.instance;
  final List<Printer> _foundPrinters = [];
  Printer? _connectedPrinter;
  final List<String> _logs = [];

  bool _scanning = false;
  bool _isSaving = false;
  DiagnosticConnectionType _mode = DiagnosticConnectionType.usb;

  // ✅ FIX 2 — Store stream subscription so it can be cancelled (was leaking)
  StreamSubscription<List<Printer>>? _scanSubscription;

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

  // ── TEST 1 — Discovery ─────────────────────────────────
  Future<void> testDiscovery() async {
    setState(() {
      _foundPrinters.clear();
      _scanning = true;
    });

    final modeName =
        _mode == DiagnosticConnectionType.usb ? 'USB' : 'Bluetooth';
    _log('🔍 Scanning for $modeName printers...');

    try {
      await _plugin.getPrinters(
        connectionTypes: [
          _mode == DiagnosticConnectionType.usb
              ? ConnectionType.USB
              : ConnectionType.BLE,
        ],
      );

      // ✅ FIX 2 — Cancel previous subscription before re-subscribing
      await _scanSubscription?.cancel();
      _scanSubscription =
          _plugin.devicesStream.listen((List<Printer> printers) {
        if (!mounted) return;
        setState(() {
          _foundPrinters
            ..clear()
            ..addAll(printers.where((p) =>
                p.connectionType ==
                (_mode == DiagnosticConnectionType.usb
                    ? ConnectionType.USB
                    : ConnectionType.BLE)));
          _scanning = false;
        });

        if (_foundPrinters.isEmpty) {
          _log('❌ No $modeName printers found');
        } else {
          for (final p in _foundPrinters) {
            _log('✅ Found: ${p.name ?? "Unknown"} (${p.address ?? "-"})');
          }
        }
      });
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
  Future<void> testConnect(Printer printer) async {
    _log('🔌 Connecting to ${printer.name ?? "Printer"}...');
    try {
      await _plugin.connect(printer);
      setState(() => _connectedPrinter = printer);
      _log('✅ Connected to ${printer.name ?? "Printer"}');
    } catch (e) {
      _log('❌ Connect failed: $e');
    }
  }

  // ── TEST 3 — Test Print ────────────────────────────────
  Future<void> testPrint() async {
    if (_connectedPrinter == null) {
      _log('⚠️ Connect to a printer first');
      return;
    }

    _log('🖨️ Generating ESC/POS payload...');
    try {
      final profile = await CapabilityProfile.load();
      final gen = Generator(
        PrintConfig.is80mm
            ? PaperSize.mm80
            : PaperSize.mm58, // ✅ FIX 3 — respect saved paper size
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
      bytes += gen.text('Printer  : ${_connectedPrinter!.name ?? "Unknown"}');
      bytes += gen.text('Address  : ${_connectedPrinter!.address ?? "-"}');
      bytes += gen.text('Time     : ${DateTime.now()}');
      bytes += gen.hr();
      bytes += gen.text('Diagnostics Successful!',
          styles: const PosStyles(align: PosAlign.center));
      bytes += gen.feed(2);
      bytes += gen.cut();

      _log('📦 Payload: ${bytes.length} bytes');

      const int chunkSize = 200;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end =
            (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        await _plugin.printData(
          _connectedPrinter!,
          bytes.sublist(i, end),
          longData: false,
        );
        await Future.delayed(const Duration(milliseconds: 30));
      }

      _log('✅ Test print sent!');
    } catch (e) {
      _log('❌ Print failed: $e');
      _log('→ Try disconnect → reconnect.');
    }
  }

  // ── STEP 4 — Save & Apply to Live Runtime ─────────────
  Future<void> saveToSettings() async {
    if (_connectedPrinter == null) return;

    final targetAddress = _connectedPrinter!.address;
    if (targetAddress == null || targetAddress.isEmpty) {
      _log('❌ Printer address is empty — cannot save');
      return;
    }

    setState(() => _isSaving = true);
    _log('💾 Saving configuration...');

    try {
      // ── 1. Update PrintConfig static fields ────────────
      PrintConfig.connectionType = _mode == DiagnosticConnectionType.bluetooth
          ? PrinterConnectionType.bluetooth
          : PrinterConnectionType.usb;

      if (_mode == DiagnosticConnectionType.bluetooth) {
        PrintConfig.macAddress = targetAddress;
        _log('📶 MAC saved: $targetAddress');
      } else {
        // USB — save vendorId/productId if available from the printer object
        final vid = int.tryParse(_connectedPrinter!.vendorId ?? '0') ?? 0;
        final pid = int.tryParse(_connectedPrinter!.productId ?? '0') ?? 0;
        if (vid != 0) {
          PrintConfig.usbVendorId = vid;
          PrintConfig.usbProductId = pid;
          _log('🔌 USB IDs saved: vendor=$vid product=$pid');
        }
        if (_connectedPrinter!.name != null) {
          PrintConfig.printerName = _connectedPrinter!.name!;
        }
      }

      // ── 2. Persist to SharedPreferences ───────────────
      await PrintConfig.save();
      _log('✅ PrintConfig saved to SharedPreferences');

      // ── 3. Build the updated hardware config ──────────
      final paperSize = PrintConfig.is80mm ? PaperSize.mm80 : PaperSize.mm58;

      final updatedPrinterConfig = _mode == DiagnosticConnectionType.bluetooth
          ? PrinterConfig(
              id: 'kitchen_printer',
              label: 'Kitchen Printer',
              type: PrinterType.bluetooth,
              macAddress: targetAddress,
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

      // ── 4. Update live queue manager in memory ──────────────
      widget.queueManager?.registerPrinter(updatedPrinterConfig);
      _log('✅ Live QueueManager updated');

      // ── 5. ✅ FIX 4 — Persist to PrinterConfigStorage ─
      // This ensures cold-start (main.dart) also picks up the new config.
      await PrinterConfigStorage.save([updatedPrinterConfig]);
      _log('✅ PrinterConfigStorage (disk) updated');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎯 ${_connectedPrinter!.name ?? "Printer"} set as active printer via ${_mode.name.toUpperCase()}',
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

  // ── Disconnect ─────────────────────────────────────────
  Future<void> disconnect() async {
    if (_connectedPrinter == null) return;
    try {
      await _plugin.disconnect(_connectedPrinter!);
      _log('🔌 Disconnected from ${_connectedPrinter!.name}');
      setState(() => _connectedPrinter = null);
    } catch (e) {
      _log('❌ Disconnect error: $e');
    }
  }

  // ✅ FIX 2 — Cancel scan subscription on dispose
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
            segments: const [
              ButtonSegment(
                value: DiagnosticConnectionType.usb,
                label: Text('USB'),
                icon: Icon(Icons.usb),
              ),
              ButtonSegment(
                value: DiagnosticConnectionType.bluetooth,
                label: Text('Bluetooth (BLE)'),
                icon: Icon(Icons.bluetooth),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (v) {
              setState(() {
                _mode = v.first;
                _foundPrinters.clear();
                _logs.clear();
              });
              // ✅ FIX 2 — disconnect cleanly before switching mode
              if (_connectedPrinter != null) disconnect();
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
                    for (final n in names) _log('🖨️  $n');
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
              onPressed: _connectedPrinter != null ? testPrint : null,
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
              label: const Text('Step 3: Apply to Settings'),
              onPressed: _connectedPrinter != null && !_isSaving
                  ? saveToSettings
                  : null,
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            ),
            // ElevatedButton.icon(
            //   icon: const Icon(Icons.translate),
            //   label: const Text('Gujarati PDF POC'),
            //   onPressed: () async {
            //     try {
            //       _log('📄 Generating Gujarati PDF POC...');
            //       final bytes = await PdfFormatter.generateGujaratiPocPdf();
            //       await Printing.layoutPdf(
            //         onLayout: (_) async => bytes,
            //         name: 'gujarati_poc',
            //       );
            //       _log('✅ Gujarati PDF POC ready — check print preview');
            //     } catch (e) {
            //       _log('❌ Gujarati POC failed: $e');
            //     }
            //   },
            //   style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            // ),
            if (_connectedPrinter != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
                onPressed: disconnect,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
          ]),
          const SizedBox(height: 16),
          if (_foundPrinters.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Found Hardware:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: _foundPrinters.length,
                itemBuilder: (_, i) {
                  final p = _foundPrinters[i];
                  final isCurrent = _connectedPrinter?.address == p.address;
                  return Card(
                    color: isCurrent ? Colors.green.withOpacity(0.15) : null,
                    child: ListTile(
                      leading: Icon(_mode == DiagnosticConnectionType.usb
                          ? Icons.usb
                          : Icons.bluetooth),
                      title: Text(p.name ?? 'Unknown Printer'),
                      subtitle: Text('ID/MAC: ${p.address ?? "N/A"}'),
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
