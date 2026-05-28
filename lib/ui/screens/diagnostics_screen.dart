import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:printer_agent/drivers/windows_usb_driver.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _plugin = FlutterThermalPrinter.instance;
  final List<Printer> _foundPrinters = [];
  Printer? _connectedPrinter;
  final List<String> _logs = [];
  bool _scanning = false;

  void _log(String msg) {
    setState(() {
      _logs.insert(0, '[${_timestamp()}] $msg');
      if (_logs.length > 30) _logs.removeLast();
    });
    print(msg);
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
    _log('🔍 Scanning for USB printers...');

    try {
      await _plugin.getPrinters(
        connectionTypes: [ConnectionType.USB],
      );

      _plugin.devicesStream.listen((List<Printer> printers) {
        setState(() {
          _foundPrinters
            ..clear()
            ..addAll(printers);
          _scanning = false;
        });

        if (printers.isEmpty) {
          _log('❌ No USB printers found');
          _log('→ Check USB cable is plugged in');
          _log('→ Check Device Manager for driver');
        } else {
          for (final p in printers) {
            _log('✅ Found: ${p.name ?? "Unknown"}');
            _log('   VendorId:  ${p.vendorId}');
            _log('   ProductId: ${p.productId}');
            _log('   Address:   ${p.address ?? "-"}');
          }
        }
      });
    } catch (e) {
      _log('❌ Discovery error: $e');
      setState(() => _scanning = false);
    }
  }

  // ── TEST 2 — Connect ───────────────────────────────────
  Future<void> testConnect(Printer printer) async {
    _log('🔌 Connecting to ${printer.name}...');
    try {
      await _plugin.connect(printer);
      setState(() => _connectedPrinter = printer);
      _log('✅ Connected to ${printer.name}');
    } catch (e) {
      _log('❌ Connect failed: $e');
      _log('→ Try: net stop spooler (PowerShell as Admin)');
      _log('→ Try: Unplug and replug USB cable');
    }
  }

  // ── TEST 3 — Test Print ────────────────────────────────
  Future<void> testPrint() async {
    if (_connectedPrinter == null) {
      _log('⚠️ Connect to a printer first (Test 2)');
      return;
    }

    _log('🖨️ Sending test print...');
    try {
      final profile = await CapabilityProfile.load();
      final gen = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += gen.text('=== TEST PRINT ===',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
            height: PosTextSize.size2,
          ));
      bytes += gen.hr();
      bytes += gen.text('Platform : Windows');
      bytes += gen.text('Type     : USB');
      bytes += gen.text('Printer  : ${_connectedPrinter!.name ?? "Unknown"}');
      bytes += gen.text('VendorId : ${_connectedPrinter!.vendorId}');
      bytes += gen.text('Time     : ${DateTime.now()}');
      bytes += gen.hr();
      bytes += gen.text('Print Agent Working',
          styles: const PosStyles(align: PosAlign.center));
      bytes += gen.feed(2);
      bytes += gen.cut();

      await _plugin.printData(
        _connectedPrinter!,
        bytes,
        longData: true,
      );

      _log('✅ Test print sent successfully!');
    } catch (e) {
      _log('❌ Print failed: $e');
      _log('→ Check paper is loaded');
      _log('→ Check paper size (58mm vs 80mm)');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔧 USB Diagnostics')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── List Windows Printers (Windows only) ──────
          if (Platform.isWindows)
            ElevatedButton.icon(
              icon: const Icon(Icons.list),
              label: const Text('List Windows Printers'),
              onPressed: () {
                final names = WindowsUsbDriver.listPrinters();
                if (names.isEmpty) {
                  _log('❌ No printers found in Windows');
                } else {
                  for (final n in names) _log('🖨️  $n');
                  _log('→ Use exact name above in PrinterConfig');
                }
              },
            ),

          const SizedBox(height: 8),

          // ── Action Buttons ────────────────────────────
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(_scanning ? 'Scanning...' : 'Test 1: Discover'),
              onPressed: _scanning ? null : testDiscovery,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Test 3: Print'),
              onPressed: _connectedPrinter != null ? testPrint : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            if (_connectedPrinter != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
                onPressed: disconnect,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
          ]),

          const SizedBox(height: 16),

          // ── Found Printers (scrollable, fixed height) ─
          if (_foundPrinters.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Found Printers:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),

            // ✅ Fixed height — no overflow regardless of count
            SizedBox(
              height: 220,
              child: ListView.builder(
                itemCount: _foundPrinters.length,
                itemBuilder: (_, i) {
                  final p = _foundPrinters[i];
                  return Card(
                    color: _connectedPrinter?.address == p.address
                        ? Colors.green.withOpacity(0.2)
                        : null,
                    child: ListTile(
                      leading: const Icon(Icons.print),
                      title: Text(p.name ?? 'Unknown Printer'),
                      subtitle: Text(
                          'Vendor: ${p.vendorId} | Product: ${p.productId}'),
                      trailing: _connectedPrinter?.address == p.address
                          ? const Chip(
                              label: Text('Connected ✅'),
                              backgroundColor: Colors.green,
                            )
                          : ElevatedButton(
                              onPressed: () => testConnect(p),
                              child: const Text('Test 2: Connect'),
                            ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── Log Panel (takes remaining space) ─────────
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Diagnostic Log:',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Expanded(
            // ✅ always gets remaining space
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text('Tap "Test 1: Discover" to start',
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
