// import 'dart:io';

// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
// import 'package:flutter_thermal_printer/utils/printer.dart';
// import '../../core/config/print_config.dart';

// class SettingsScreen extends StatefulWidget {
//   final VoidCallback onSaved;
//   const SettingsScreen({super.key, required this.onSaved});

//   @override
//   State<SettingsScreen> createState() => _SettingsScreenState();
// }

// class _SettingsScreenState extends State<SettingsScreen> {
//   final _restaurantIdCtrl = TextEditingController();
//   final _empIdCtrl = TextEditingController();
//   final _serverUrlCtrl = TextEditingController();
//   final _apiUrlCtrl = TextEditingController();
//   final _authTokenCtrl = TextEditingController();
//   final _printerNameCtrl = TextEditingController();
//   final _restaurantNameCtrl = TextEditingController();
//   final _kotCopiesCtrl = TextEditingController();
//   final _billCopiesCtrl = TextEditingController();
//   final _customStationCtrl = TextEditingController(); // ✅ NEW

//   PaperSize _paperSize = PaperSize.mm58;
//   bool _autoPrint = true;
//   bool _autoPrintBill = true;
//   bool _obscureToken = true;

//   // ✅ NEW — station toggles
//   bool _kdsEnabled = false;
//   bool _barEnabled = false;
//   List<String> _customStations = []; // e.g. ['PIZZA', 'GRILL']

//   List<Printer> _foundUsbPrinters = [];
//   Printer? _selectedUsbPrinter;

//   @override
//   void initState() {
//     super.initState();
//     _loadValues();
//   }

//   void _loadValues() {
//     _restaurantIdCtrl.text = PrintConfig.restaurantId.toString();
//     _empIdCtrl.text = PrintConfig.empId;
//     _serverUrlCtrl.text = PrintConfig.serverUrl;
//     _apiUrlCtrl.text = PrintConfig.apiUrl;
//     _authTokenCtrl.text = PrintConfig.authToken;
//     _printerNameCtrl.text = PrintConfig.printerName;
//     _restaurantNameCtrl.text = PrintConfig.restaurantName;
//     _kotCopiesCtrl.text = PrintConfig.kotCopies.toString();
//     _billCopiesCtrl.text = PrintConfig.billCopies.toString();
//     _autoPrint = PrintConfig.autoPrint;
//     _autoPrintBill = PrintConfig.autoPrintBill;
//     _paperSize = PrintConfig.paperSize;

//     // ✅ Derive switches from saved stations set
//     final saved = PrintConfig.stations.map((s) => s.toUpperCase()).toSet();
//     _kdsEnabled = saved.contains('KDS');
//     _barEnabled = saved.contains('BAR');
//     // Anything that's not KDS or BAR → custom
//     _customStations = saved.where((s) => s != 'KDS' && s != 'BAR').toList();
//   }

//   // ✅ Merge KDS + BAR + custom back into PrintConfig.stations
//   Set<String> _buildStationsSet() {
//     final merged = <String>{};
//     if (_kdsEnabled) merged.add('KDS');
//     if (_barEnabled) merged.add('BAR');
//     merged.addAll(_customStations.map((s) => s.toUpperCase()));
//     return merged;
//   }

//   Future<void> _save() async {
//     if (_serverUrlCtrl.text.isEmpty ||
//         _authTokenCtrl.text.isEmpty ||
//         _printerNameCtrl.text.isEmpty ||
//         _empIdCtrl.text.isEmpty) {
//       _showError('Server URL, Token, Printer Name and Emp ID are required');
//       return;
//     }

//     PrintConfig.restaurantId = int.tryParse(_restaurantIdCtrl.text) ?? 618;
//     PrintConfig.empId = _empIdCtrl.text.trim();
//     PrintConfig.serverUrl = _serverUrlCtrl.text.trim();
//     PrintConfig.apiUrl = _apiUrlCtrl.text.trim();
//     PrintConfig.authToken = _authTokenCtrl.text.trim();
//     PrintConfig.printerName = _printerNameCtrl.text.trim();
//     PrintConfig.restaurantName = _restaurantNameCtrl.text.trim();
//     PrintConfig.kotCopies = int.tryParse(_kotCopiesCtrl.text) ?? 1;
//     PrintConfig.billCopies = int.tryParse(_billCopiesCtrl.text) ?? 1;
//     PrintConfig.autoPrint = _autoPrint;
//     PrintConfig.autoPrintBill = _autoPrintBill;
//     PrintConfig.paperSize = _paperSize;
//     PrintConfig.stations = _buildStationsSet();

//     //  ADD THESE — save selected USB printer
//     // ── _save() — fixed USB block ──
//     if (_selectedUsbPrinter != null) {
//       PrintConfig.usbVendorId =
//           int.tryParse(_selectedUsbPrinter!.vendorId ?? '0') ?? 0;
//       PrintConfig.usbProductId =
//           int.tryParse(_selectedUsbPrinter!.productId ?? '0') ?? 0;
//     }

//     await PrintConfig.save(); // ✅ now saves vendorId + productId too

//     widget.onSaved();

//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('✅ Settings saved — reconnecting socket...'),
//           backgroundColor: Colors.green,
//         ),
//       );
//       Future.delayed(const Duration(seconds: 1), () {
//         if (mounted) Navigator.pop(context);
//       });
//     }
//   }

//   void _showError(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
//     );
//   }

//   void _addCustomStation() {
//     final val = _customStationCtrl.text.trim().toUpperCase();
//     if (val.isEmpty) return;
//     if (val == 'KDS' || val == 'BAR') {
//       _showError('Use the KDS/BAR toggle above instead');
//       return;
//     }
//     if (_customStations.contains(val)) {
//       _showError('Station $val already added');
//       return;
//     }
//     setState(() {
//       _customStations.add(val);
//       _customStationCtrl.clear();
//     });
//   }

//   Future<void> _scanUsbPrinters() async {
//     try {
//       final plugin = FlutterThermalPrinter.instance;
//       await plugin.getPrinters(connectionTypes: [ConnectionType.USB]);
//       plugin.devicesStream.listen((List<Printer> printers) {
//         if (mounted) setState(() => _foundUsbPrinters = printers);
//       });
//     } catch (e) {
//       _showError('USB scan failed: $e');
//     }
//   }

//   @override
//   void dispose() {
//     _restaurantIdCtrl.dispose();
//     _empIdCtrl.dispose();
//     _serverUrlCtrl.dispose();
//     _apiUrlCtrl.dispose();
//     _authTokenCtrl.dispose();
//     _printerNameCtrl.dispose();
//     _restaurantNameCtrl.dispose();
//     _kotCopiesCtrl.dispose();
//     _billCopiesCtrl.dispose();
//     _customStationCtrl.dispose(); // ✅ NEW
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('⚙️ Settings'),
//         actions: [
//           TextButton.icon(
//             icon: const Icon(Icons.save, color: Colors.white),
//             label: const Text('Save', style: TextStyle(color: Colors.white)),
//             onPressed: _save,
//           ),
//         ],
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           // ── Server ──────────────────────────────────
//           _sectionHeader('🌐 Server'),
//           _field(
//               controller: _serverUrlCtrl,
//               label: 'Socket URL',
//               hint: 'http://presocket.mygenie.online',
//               icon: Icons.electrical_services),
//           _field(
//               controller: _apiUrlCtrl,
//               label: 'API URL',
//               hint: 'https://preprod.mygenie.online',
//               icon: Icons.api),
//           _tokenField(),
//           const SizedBox(height: 16),

//           // ── Identity ─────────────────────────────────
//           _sectionHeader('🏪 Identity'),
//           _field(
//               controller: _restaurantIdCtrl,
//               label: 'Restaurant ID',
//               hint: '618',
//               icon: Icons.restaurant,
//               numeric: true),
//           _field(
//               controller: _empIdCtrl,
//               label: 'Employee ID (emp_code)',
//               hint: '002',
//               icon: Icons.badge),
//           _field(
//               controller: _restaurantNameCtrl,
//               label: 'Restaurant Name (for bill header)',
//               hint: 'Hogwarts',
//               icon: Icons.storefront),
//           const SizedBox(height: 16),

//           // ── Printer ──────────────────────────────────
//           _sectionHeader('🖨️ Printer'),
//           _field(
//               controller: _printerNameCtrl,
//               label: 'Windows Printer Name',
//               hint: 'Everycom-printer',
//               icon: Icons.print),
//           Padding(
//             padding: const EdgeInsets.only(bottom: 12),
//             child: DropdownButtonFormField<PaperSize>(
//               value: _paperSize,
//               decoration: const InputDecoration(
//                 labelText: 'Paper Size',
//                 prefixIcon: Icon(Icons.straighten),
//                 border: OutlineInputBorder(),
//                 filled: true,
//               ),
//               items: const [
//                 DropdownMenuItem(
//                     value: PaperSize.mm58,
//                     child: Text('58mm  —  Small receipt')),
//                 DropdownMenuItem(
//                     value: PaperSize.mm80,
//                     child: Text('80mm  —  Wide receipt')),
//               ],
//               onChanged: (v) =>
//                   setState(() => _paperSize = v ?? PaperSize.mm58),
//             ),
//           ),
//           _field(
//               controller: _billCopiesCtrl,
//               label: 'BILL Copies',
//               hint: '1',
//               icon: Icons.content_copy,
//               numeric: true),
//           const SizedBox(height: 12),

//               _field(
//               controller: _kotCopiesCtrl,
//               label: 'KOT Copies',
//               hint: '1',
//               icon: Icons.content_copy,
//               numeric: true),
//           const SizedBox(height: 16),

//           // ── Android USB Printer ──────────────────────────
//           if (Platform.isAndroid) ...[
//             _sectionHeader('📱 Android USB Printer'),
//             const Padding(
//               padding: EdgeInsets.only(bottom: 8),
//               child: Text(
//                 'Connect your thermal printer via USB OTG cable, then scan.',
//                 style: TextStyle(color: Colors.grey, fontSize: 12),
//               ),
//             ),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.usb),
//               label: const Text('Scan USB Printers'),
//               onPressed: _scanUsbPrinters,
//               style: ElevatedButton.styleFrom(
//                 minimumSize: const Size(double.infinity, 48),
//               ),
//             ),
//             const SizedBox(height: 8),
//             if (_foundUsbPrinters.isNotEmpty)
//               DropdownButtonFormField<Printer>(
//                 items: _foundUsbPrinters
//                     .map((p) => DropdownMenuItem<Printer>(
//                           value: p,
//                           child: Text('${p.name ?? 'Printer'} — ${p.vendorId}'),
//                         ))
//                     .toList(),
//                 // ── Dropdown onChanged — fixed ──
//                 onChanged: (Printer? p) {
//                   if (p == null) return;
//                   setState(
//                       () => _selectedUsbPrinter = p); // ✅ store full Printer
//                   PrintConfig.usbVendorId =
//                       int.tryParse(p.vendorId ?? '0') ?? 0;
//                   PrintConfig.usbProductId =
//                       int.tryParse(p.productId ?? '0') ?? 0;
//                 },
//               ),
//             // Show currently saved printer
//             if (PrintConfig.usbVendorId != 0)
//               Padding(
//                 padding: const EdgeInsets.only(top: 8),
//                 child: Text(
//                   '✅ Saved: vendor=${PrintConfig.usbVendorId} product=${PrintConfig.usbProductId}',
//                   style: const TextStyle(color: Colors.green, fontSize: 12),
//                 ),
//               ),
//             const SizedBox(height: 16),
//           ],

//           // ── KOT Stations ✅ NEW ───────────────────────
//           // _sectionHeader('🍽️ KOT Stations'),
//           // const Padding(
//           //   padding: EdgeInsets.only(bottom: 8),
//           //   child: Text(
//           //     'Select which stations this device prints KOT for.\n'
//           //     'Each matched station prints a separate KOT.',
//           //     style: TextStyle(color: Colors.grey, fontSize: 12),
//           //   ),
//           // ),

//           // // KDS toggle
//           // Card(
//           //   child: SwitchListTile(
//           //     secondary: const Icon(Icons.tv, color: Colors.tealAccent),
//           //     title: const Text('KDS Station'),
//           //     subtitle: const Text('Kitchen Display System items'),
//           //     value: _kdsEnabled,
//           //     onChanged: (v) => setState(() => _kdsEnabled = v),
//           //   ),
//           // ),

//           // // BAR toggle
//           // Card(
//           //   child: SwitchListTile(
//           //     secondary:
//           //         const Icon(Icons.local_bar, color: Colors.orangeAccent),
//           //     title: const Text('BAR Station'),
//           //     subtitle: const Text('Bar / Beverages items'),
//           //     value: _barEnabled,
//           //     onChanged: (v) => setState(() => _barEnabled = v),
//           //   ),
//           // ),

//           // const SizedBox(height: 8),

//           // // Custom stations chips
//           // if (_customStations.isNotEmpty) ...[
//           //   const Text('Custom Stations:',
//           //       style: TextStyle(fontSize: 13, color: Colors.grey)),
//           //   const SizedBox(height: 6),
//           //   Wrap(
//           //     spacing: 8,
//           //     runSpacing: 4,
//           //     children: _customStations
//           //         .map((station) => Chip(
//           //               label: Text(station),
//           //               backgroundColor: Colors.deepPurple.withOpacity(0.3),
//           //               deleteIcon: const Icon(Icons.close, size: 16),
//           //               onDeleted: () =>
//           //                   setState(() => _customStations.remove(station)),
//           //             ))
//           //         .toList(),
//           //   ),
//           //   const SizedBox(height: 8),
//           // ],

//           // // Add custom station row
//           // Row(children: [
//           //   Expanded(
//           //     child: TextField(
//           //       controller: _customStationCtrl,
//           //       textCapitalization: TextCapitalization.characters,
//           //       decoration: const InputDecoration(
//           //         labelText: 'Add Custom Station',
//           //         hintText: 'e.g. PIZZA, GRILL',
//           //         prefixIcon: Icon(Icons.add_circle_outline),
//           //         border: OutlineInputBorder(),
//           //         filled: true,
//           //       ),
//           //       onSubmitted: (_) => _addCustomStation(),
//           //     ),
//           //   ),
//           //   const SizedBox(width: 8),
//           //   ElevatedButton(
//           //     onPressed: _addCustomStation,
//           //     style: ElevatedButton.styleFrom(
//           //         padding:
//           //             const EdgeInsets.symmetric(horizontal: 16, vertical: 18)),
//           //     child: const Text('Add'),
//           //   ),
//           // ]),

//           // // ✅ Warning if no station selected
//           // if (!_kdsEnabled && !_barEnabled && _customStations.isEmpty)
//           //   Container(
//           //     margin: const EdgeInsets.only(top: 10),
//           //     padding: const EdgeInsets.all(10),
//           //     decoration: BoxDecoration(
//           //       color: Colors.orange.withOpacity(0.15),
//           //       border: Border.all(color: Colors.orange),
//           //       borderRadius: BorderRadius.circular(8),
//           //     ),
//           //     child: const Row(children: [
//           //       Icon(Icons.warning_amber, color: Colors.orange, size: 18),
//           //       SizedBox(width: 8),
//           //       Expanded(
//           //         child: Text(
//           //           'No stations selected — KOT will NOT print for manual events',
//           //           style: TextStyle(color: Colors.orange, fontSize: 12),
//           //         ),
//           //       ),
//           //     ]),
//           //   ),

//           // const SizedBox(height: 16),

//           // ── Auto Print ───────────────────────────────
//           _sectionHeader('⚡ Auto Print'),
//           _toggle(
//               label: 'Auto Print KOT',
//               subtitle: 'Print KOT when new order arrives',
//               value: _autoPrint,
//               onChanged: (v) => setState(() => _autoPrint = v)),
//           _toggle(
//               label: 'Auto Print Bill',
//               subtitle: 'Print bill on manual_print event',
//               value: _autoPrintBill,
//               onChanged: (v) => setState(() => _autoPrintBill = v)),

//           const SizedBox(height: 32),

//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: ElevatedButton.icon(
//               icon: const Icon(Icons.save),
//               label: const Text('Save & Reconnect',
//                   style: TextStyle(fontSize: 16)),
//               onPressed: _save,
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//             ),
//           ),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }

//   Widget _sectionHeader(String title) => Padding(
//         padding: const EdgeInsets.only(bottom: 8),
//         child: Text(title,
//             style: const TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.tealAccent)),
//       );

//   Widget _field({
//     required TextEditingController controller,
//     required String label,
//     required String hint,
//     required IconData icon,
//     bool numeric = false,
//   }) =>
//       Padding(
//         padding: const EdgeInsets.only(bottom: 12),
//         child: TextField(
//           controller: controller,
//           keyboardType: numeric ? TextInputType.number : TextInputType.text,
//           decoration: InputDecoration(
//             labelText: label,
//             hintText: hint,
//             prefixIcon: Icon(icon),
//             border: const OutlineInputBorder(),
//             filled: true,
//           ),
//         ),
//       );

//   Widget _tokenField() => Padding(
//         padding: const EdgeInsets.only(bottom: 12),
//         child: TextField(
//           controller: _authTokenCtrl,
//           obscureText: _obscureToken,
//           decoration: InputDecoration(
//             labelText: 'Auth Token (Bearer)',
//             hintText: 'FLwtm4SQ2nVv...',
//             prefixIcon: const Icon(Icons.key),
//             border: const OutlineInputBorder(),
//             filled: true,
//             suffixIcon: IconButton(
//               icon:
//                   Icon(_obscureToken ? Icons.visibility : Icons.visibility_off),
//               onPressed: () => setState(() => _obscureToken = !_obscureToken),
//             ),
//           ),
//         ),
//       );

//   Widget _toggle({
//     required String label,
//     required String subtitle,
//     required bool value,
//     required ValueChanged<bool> onChanged,
//   }) =>
//       Card(
//         child: SwitchListTile(
//           title: Text(label),
//           subtitle: Text(subtitle),
//           value: value,
//           onChanged: onChanged,
//         ),
//       );
// }

import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:printer_agent/core/models/printer_config.dart';
import 'package:printer_agent/core/queue/print_queue.dart';
import '../../core/config/print_config.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onSaved;
   final PrintQueue? queue;  
  const SettingsScreen({super.key, required this.onSaved , this.queue,});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Existing controllers ─────────────────────────────
  final _restaurantIdCtrl = TextEditingController();
  final _empIdCtrl = TextEditingController();
  final _serverUrlCtrl = TextEditingController();
  final _apiUrlCtrl = TextEditingController();
  final _authTokenCtrl = TextEditingController();
  final _printerNameCtrl = TextEditingController();
  final _restaurantNameCtrl = TextEditingController();
  final _kotCopiesCtrl = TextEditingController();
  final _billCopiesCtrl = TextEditingController();
  final _customStationCtrl = TextEditingController();

  // ✅ NEW — LAN controllers
  final _lanIpCtrl = TextEditingController();
  final _lanPortCtrl = TextEditingController(text: '9100');

  // ── Existing state ───────────────────────────────────
  PaperSize _paperSize = PaperSize.mm58;
  bool _autoPrint = true;
  bool _autoPrintBill = true;
  bool _obscureToken = true;
  bool _kdsEnabled = false;
  bool _barEnabled = false;
  List<String> _customStations = [];
  List<Printer> _foundUsbPrinters = [];
  Printer? _selectedUsbPrinter;

  // ✅ NEW — LAN state
  PrinterConnectionType _connectionType = PrinterConnectionType.usb;
  bool _isTestingLan = false;
  String? _lanTestResult;
  bool _lanTestSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  void _loadValues() {
    // ── Existing ─────────────────────────────────────
    _restaurantIdCtrl.text = PrintConfig.restaurantId.toString();
    _empIdCtrl.text = PrintConfig.empId;
    _serverUrlCtrl.text = PrintConfig.serverUrl;
    _apiUrlCtrl.text = PrintConfig.apiUrl;
    _authTokenCtrl.text = PrintConfig.authToken;
    _printerNameCtrl.text = PrintConfig.printerName;
    _restaurantNameCtrl.text = PrintConfig.restaurantName;
    _kotCopiesCtrl.text = PrintConfig.kotCopies.toString();
    _billCopiesCtrl.text = PrintConfig.billCopies.toString();
    _autoPrint = PrintConfig.autoPrint;
    _autoPrintBill = PrintConfig.autoPrintBill;
    _paperSize = PrintConfig.paperSize;

    final saved = PrintConfig.stations.map((s) => s.toUpperCase()).toSet();
    _kdsEnabled = saved.contains('KDS');
    _barEnabled = saved.contains('BAR');
    _customStations = saved.where((s) => s != 'KDS' && s != 'BAR').toList();

    // ✅ NEW — LAN
    _connectionType = PrintConfig.connectionType;
    _lanIpCtrl.text = PrintConfig.lanIp;
    _lanPortCtrl.text = PrintConfig.lanPort.toString();
  }

  Set<String> _buildStationsSet() {
    final merged = <String>{};
    if (_kdsEnabled) merged.add('KDS');
    if (_barEnabled) merged.add('BAR');
    merged.addAll(_customStations.map((s) => s.toUpperCase()));
    return merged;
  }

  Future<void> _save() async {
    if (_serverUrlCtrl.text.isEmpty ||
        _authTokenCtrl.text.isEmpty ||
        _empIdCtrl.text.isEmpty) {
      _showError('Server URL, Token and Emp ID are required');
      return;
    }

    // ✅ Validate printer fields based on connection type
    if (_connectionType == PrinterConnectionType.usb &&
        _printerNameCtrl.text.isEmpty) {
      _showError('Printer Name is required for USB');
      return;
    }
    if (_connectionType == PrinterConnectionType.lan &&
        _lanIpCtrl.text.isEmpty) {
      _showError('IP Address is required for LAN');
      return;
    }

    // ── Existing saves ────────────────────────────────
    PrintConfig.restaurantId = int.tryParse(_restaurantIdCtrl.text) ?? 618;
    PrintConfig.empId = _empIdCtrl.text.trim();
    PrintConfig.serverUrl = _serverUrlCtrl.text.trim();
    PrintConfig.apiUrl = _apiUrlCtrl.text.trim();
    PrintConfig.authToken = _authTokenCtrl.text.trim();
    PrintConfig.printerName = _printerNameCtrl.text.trim();
    PrintConfig.restaurantName = _restaurantNameCtrl.text.trim();
    PrintConfig.kotCopies = int.tryParse(_kotCopiesCtrl.text) ?? 1;
    PrintConfig.billCopies = int.tryParse(_billCopiesCtrl.text) ?? 1;
    PrintConfig.autoPrint = _autoPrint;
    PrintConfig.autoPrintBill = _autoPrintBill;
    PrintConfig.paperSize = _paperSize;
    PrintConfig.stations = _buildStationsSet();

    if (_selectedUsbPrinter != null) {
      PrintConfig.usbVendorId =
          int.tryParse(_selectedUsbPrinter!.vendorId ?? '0') ?? 0;
      PrintConfig.usbProductId =
          int.tryParse(_selectedUsbPrinter!.productId ?? '0') ?? 0;
    }

    // ✅ LAN saves
    PrintConfig.connectionType = _connectionType;
    PrintConfig.lanIp = _lanIpCtrl.text.trim();
    PrintConfig.lanPort = int.tryParse(_lanPortCtrl.text) ?? 9100;

    await PrintConfig.save();

    // ✅ FIX — re-register printer with updated config so running
    //          PrinterManager uses new settings without needing restart
    final updatedConfig = PrinterConfig(
      id: 'kitchen_printer',
      label: 'Kitchen Printer',
      type: _connectionType == PrinterConnectionType.lan
          ? PrinterType.lan
          : PrinterType.usb,
      ipAddress: PrintConfig.lanIp,
      port: PrintConfig.lanPort,
      windowsPrinterName: PrintConfig.printerName,
      vendorId: PrintConfig.usbVendorId,
      productId: PrintConfig.usbProductId,
      paperSize: PrintConfig.paperSize,
    );
    widget.queue?.manager.registerPrinter(updatedConfig);

    widget.onSaved();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Settings saved — reconnecting socket...'),
          backgroundColor: Colors.green,
        ),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
    );
  }

  void _addCustomStation() {
    final val = _customStationCtrl.text.trim().toUpperCase();
    if (val.isEmpty) return;
    if (val == 'KDS' || val == 'BAR') {
      _showError('Use the KDS/BAR toggle above instead');
      return;
    }
    if (_customStations.contains(val)) {
      _showError('Station $val already added');
      return;
    }
    setState(() {
      _customStations.add(val);
      _customStationCtrl.clear();
    });
  }

  Future<void> _scanUsbPrinters() async {
    try {
      final plugin = FlutterThermalPrinter.instance;
      await plugin.getPrinters(connectionTypes: [ConnectionType.USB]);
      plugin.devicesStream.listen((List<Printer> printers) {
        if (mounted) setState(() => _foundUsbPrinters = printers);
      });
    } catch (e) {
      _showError('USB scan failed: $e');
    }
  }

  // ✅ NEW — Test LAN connection
  Future<void> _testLanConnection() async {
    final ip = _lanIpCtrl.text.trim();
    final port = int.tryParse(_lanPortCtrl.text) ?? 9100;

    if (ip.isEmpty) {
      _showError('Enter IP address first');
      return;
    }

    setState(() {
      _isTestingLan = true;
      _lanTestResult = null;
    });

    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 3),
      );
      await socket.close();
      setState(() {
        _lanTestSuccess = true;
        _lanTestResult = '✅ Printer reachable at $ip:$port';
      });
    } catch (_) {
      setState(() {
        _lanTestSuccess = false;
        _lanTestResult = '❌ Could not reach $ip:$port — check IP/port';
      });
    } finally {
      setState(() => _isTestingLan = false);
    }
  }

  @override
  void dispose() {
    _restaurantIdCtrl.dispose();
    _empIdCtrl.dispose();
    _serverUrlCtrl.dispose();
    _apiUrlCtrl.dispose();
    _authTokenCtrl.dispose();
    _printerNameCtrl.dispose();
    _restaurantNameCtrl.dispose();
    _kotCopiesCtrl.dispose();
    _billCopiesCtrl.dispose();
    _customStationCtrl.dispose();
    // ✅ NEW
    _lanIpCtrl.dispose();
    _lanPortCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Settings'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Server ────────────────────────────────────
          _sectionHeader('🌐 Server'),
          _field(
            controller: _serverUrlCtrl,
            label: 'Socket URL',
            hint: 'http://presocket.mygenie.online',
            icon: Icons.electrical_services,
          ),
          _field(
            controller: _apiUrlCtrl,
            label: 'API URL',
            hint: 'https://preprod.mygenie.online',
            icon: Icons.api,
          ),
          _tokenField(),
          const SizedBox(height: 16),

          // ── Identity ──────────────────────────────────
          _sectionHeader('🏪 Identity'),
          _field(
            controller: _restaurantIdCtrl,
            label: 'Restaurant ID',
            hint: '618',
            icon: Icons.restaurant,
            numeric: true,
          ),
          _field(
            controller: _empIdCtrl,
            label: 'Employee ID (emp_code)',
            hint: '002',
            icon: Icons.badge,
          ),
          _field(
            controller: _restaurantNameCtrl,
            label: 'Restaurant Name (for bill header)',
            hint: 'Hogwarts',
            icon: Icons.storefront,
          ),
          const SizedBox(height: 16),

          // ── Printer ───────────────────────────────────
          _sectionHeader('🖨️ Printer'),

          // ✅ NEW — Connection type toggle
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<PrinterConnectionType>(
              segments: const [
                ButtonSegment(
                  value: PrinterConnectionType.usb,
                  label: Text('USB'),
                  icon: Icon(Icons.usb),
                ),
                ButtonSegment(
                  value: PrinterConnectionType.lan,
                  label: Text('LAN / WiFi'),
                  icon: Icon(Icons.wifi),
                ),
              ],
              selected: {_connectionType},
              onSelectionChanged: (v) => setState(() {
                _connectionType = v.first;
                _lanTestResult = null; // clear test result on switch
              }),
            ),
          ),

          // ✅ USB fields — only when USB
          if (_connectionType == PrinterConnectionType.usb) ...[
            _field(
              controller: _printerNameCtrl,
              label: 'Windows Printer Name',
              hint: 'Everycom-printer',
              icon: Icons.print,
            ),
          ],

          // ✅ LAN fields — only when LAN
          if (_connectionType == PrinterConnectionType.lan) ...[
            _field(
              controller: _lanIpCtrl,
              label: 'Printer IP Address',
              hint: '192.168.1.100',
              icon: Icons.router,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            _field(
              controller: _lanPortCtrl,
              label: 'Port',
              hint: '9100',
              icon: Icons.settings_ethernet,
              numeric: true,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTestingLan ? null : _testLanConnection,
                icon: _isTestingLan
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(_isTestingLan ? 'Testing...' : 'Test Connection'),
              ),
            ),
            if (_lanTestResult != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _lanTestSuccess
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  border: Border.all(
                    color: _lanTestSuccess ? Colors.green : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lanTestResult!,
                  style: TextStyle(
                    color: _lanTestSuccess ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],

          // ── Paper size (always shown) ─────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<PaperSize>(
              value: _paperSize,
              decoration: const InputDecoration(
                labelText: 'Paper Size',
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
                filled: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: PaperSize.mm58,
                  child: Text('58mm  —  Small receipt'),
                ),
                DropdownMenuItem(
                  value: PaperSize.mm80,
                  child: Text('80mm  —  Wide receipt'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _paperSize = v ?? PaperSize.mm58),
            ),
          ),

          // ── Copies (always shown) ─────────────────────
          _field(
            controller: _billCopiesCtrl,
            label: 'BILL Copies',
            hint: '1',
            icon: Icons.content_copy,
            numeric: true,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _kotCopiesCtrl,
            label: 'KOT Copies',
            hint: '1',
            icon: Icons.content_copy,
            numeric: true,
          ),
          const SizedBox(height: 16),

          // ── Android USB Printer (unchanged) ──────────
          if (Platform.isAndroid) ...[
            _sectionHeader('📱 Android USB Printer'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Connect your thermal printer via USB OTG cable, then scan.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.usb),
              label: const Text('Scan USB Printers'),
              onPressed: _scanUsbPrinters,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            if (_foundUsbPrinters.isNotEmpty)
              DropdownButtonFormField<Printer>(
                items: _foundUsbPrinters
                    .map((p) => DropdownMenuItem<Printer>(
                          value: p,
                          child: Text('${p.name ?? 'Printer'} — ${p.vendorId}'),
                        ))
                    .toList(),
                onChanged: (Printer? p) {
                  if (p == null) return;
                  setState(() => _selectedUsbPrinter = p);
                  PrintConfig.usbVendorId =
                      int.tryParse(p.vendorId ?? '0') ?? 0;
                  PrintConfig.usbProductId =
                      int.tryParse(p.productId ?? '0') ?? 0;
                },
              ),
            if (PrintConfig.usbVendorId != 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '✅ Saved: vendor=${PrintConfig.usbVendorId} product=${PrintConfig.usbProductId}',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
          ],

          // ── Auto Print (unchanged) ────────────────────
          _sectionHeader('⚡ Auto Print'),
          _toggle(
            label: 'Auto Print KOT',
            subtitle: 'Print KOT when new order arrives',
            value: _autoPrint,
            onChanged: (v) => setState(() => _autoPrint = v),
          ),
          _toggle(
            label: 'Auto Print Bill',
            subtitle: 'Print bill on manual_print event',
            value: _autoPrintBill,
            onChanged: (v) => setState(() => _autoPrintBill = v),
          ),

          const SizedBox(height: 32),

          // ── Save button (unchanged) ───────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save & Reconnect',
                  style: TextStyle(fontSize: 16)),
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Helpers (all unchanged) ───────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.tealAccent,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool numeric = false,
    List<TextInputFormatter>? inputFormatters,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
            filled: true,
          ),
        ),
      );

  Widget _tokenField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _authTokenCtrl,
          obscureText: _obscureToken,
          decoration: InputDecoration(
            labelText: 'Auth Token (Bearer)',
            hintText: 'FLwtm4SQ2nVv...',
            prefixIcon: const Icon(Icons.key),
            border: const OutlineInputBorder(),
            filled: true,
            suffixIcon: IconButton(
              icon:
                  Icon(_obscureToken ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
            ),
          ),
        ),
      );

  Widget _toggle({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Card(
        child: SwitchListTile(
          title: Text(label),
          subtitle: Text(subtitle),
          value: value,
          onChanged: onChanged,
        ),
      );
}
