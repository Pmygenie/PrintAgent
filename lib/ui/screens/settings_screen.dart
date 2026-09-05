import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:printer_agent/core/models/printer_config.dart';
import 'package:printer_agent/core/printer/bluetooth_address.dart';
import 'package:printer_agent/core/queue/print_queue_manager.dart';
import 'package:printer_agent/core/services/printer_agent_config_sync_service.dart';
import 'package:printer_agent/ui/screens/diagnostics_screen.dart';
import '../../core/config/print_config.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onSaved;
  final PrintQueueManager? queueManager;

  const SettingsScreen({
    super.key,
    required this.onSaved,
    this.queueManager,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Server / Identity controllers ────────────────────────────────────────
  final _restaurantIdCtrl   = TextEditingController();
  final _empIdCtrl          = TextEditingController();
  final _authTokenCtrl      = TextEditingController();
  final _restaurantNameCtrl = TextEditingController();
  final _billFooterCtrl     = TextEditingController();
  final _kotCopiesCtrl      = TextEditingController();
  final _billCopiesCtrl     = TextEditingController();
  final _feedbackQrUrlCtrl  = TextEditingController();
  final _upiIdCtrl          = TextEditingController();

  // ── Global print toggles ─────────────────────────────────────────────────
  bool _autoPrint     = true;
  bool _autoPrintBill = true;
  bool _autoPrintCancelKot = true;
  bool _autoSettle = false;
  bool _aggregatorAutoKot  = false;
  bool _aggregatorAutoBill = false;
  String _aggregatorAutoBillStage = 'Acknowledged';
  bool _scanOrderAutoPrint = false;
  bool _kotSeparateTicket = false;
  bool _obscureToken  = true;
  AgentPaperSize _paperSize = AgentPaperSize.mm58;
  bool _usePdfPrintingOnWindows = true;
  bool _showItemDateOn80mm = false;
  bool _feedbackQrEnabled = false;
  bool _upiQrEnabled = false;
  bool _upiDynamicEnabled = false;

  // ── Multi-printer list (the core new state) ───────────────────────────────
  List<PrinterConfig> _printers = [];

  // ── Remote config sync (blocks the form until the first sync attempt of
  // the session finishes, success or failure) ───────────────────────────────
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Best-effort: on failure this just leaves local SharedPreferences
    // values (already the fallback) untouched.
    await PrinterAgentConfigSyncService.sync();
    if (!mounted) return;
    _loadGlobalValues();
    await _loadSavedPrinters();
    if (!mounted) return;
    setState(() => _isSyncing = false);
  }

  @override
  void dispose() {
    _restaurantIdCtrl.dispose();
    _empIdCtrl.dispose();
    _authTokenCtrl.dispose();
    _restaurantNameCtrl.dispose();
    _billFooterCtrl.dispose();
    _kotCopiesCtrl.dispose();
    _billCopiesCtrl.dispose();
    _feedbackQrUrlCtrl.dispose();
    _upiIdCtrl.dispose();
    super.dispose();
  }

  // ── Load ─────────────────────────────────────────────────────────────────
  void _loadGlobalValues() {
    _restaurantIdCtrl.text    = PrintConfig.restaurantId.toString();
    _empIdCtrl.text           = PrintConfig.empId;
    _authTokenCtrl.text       = PrintConfig.authToken;
    _restaurantNameCtrl.text  = PrintConfig.restaurantName;
    _billFooterCtrl.text      = PrintConfig.poweredByFooter;
    _kotCopiesCtrl.text       = PrintConfig.kotCopies.toString();
    _billCopiesCtrl.text      = PrintConfig.billCopies.toString();
    _autoPrint                = PrintConfig.autoPrint;
    _autoPrintBill            = PrintConfig.autoPrintBill;
    _autoPrintCancelKot       = PrintConfig.autoPrintCancelKot;
    _autoSettle               = PrintConfig.autoSettle;
    _aggregatorAutoKot        = PrintConfig.aggregatorAutoKot;
    _aggregatorAutoBill       = PrintConfig.aggregatorAutoBill;
    _aggregatorAutoBillStage  = PrintConfig.aggregatorAutoBillStage;
    _scanOrderAutoPrint       = PrintConfig.scanOrderAutoPrint;
    _kotSeparateTicket        = PrintConfig.kotSeparateTicket;
    _paperSize                = PrintConfig.paperSize;
    _usePdfPrintingOnWindows  = PrintConfig.usePdfPrintingOnWindows;
    _showItemDateOn80mm       = PrintConfig.showItemDateOn80mm;
    _feedbackQrEnabled        = PrintConfig.feedbackQrEnabled;
    _feedbackQrUrlCtrl.text   = PrintConfig.feedbackQrUrl;
    _upiQrEnabled             = PrintConfig.upiQrEnabled;
    _upiDynamicEnabled        = PrintConfig.upiDynamicEnabled;
    _upiIdCtrl.text           = PrintConfig.upiId;
  }

  Future<void> _loadSavedPrinters() async {
    final saved = await PrinterConfigStorage.load();
    if (mounted) {
      setState(() {
        _printers = saved.isNotEmpty ? saved : [];
      });
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_empIdCtrl.text.isEmpty) {
      _showError('Emp ID is required');
      return;
    }

    if (_printers.isEmpty) {
      _showError('Add at least one printer before saving');
      return;
    }

    if (_upiQrEnabled && _upiIdCtrl.text.trim().isEmpty) {
      _showError('UPI ID is required when UPI QR is enabled');
      return;
    }

    // Write global config to memory
    // Restaurant ID is no longer editable here — it comes exclusively from
    // the restaurant profile API (see RestaurantProfileRepository) and is
    // only displayed read-only above.
    PrintConfig.empId                    = _empIdCtrl.text.trim();
    // Socket URL / API URL are no longer editable here — they are hardcoded
    // in AppConstants, the sole source of truth (see app_constants.dart).
    // Auth token is no longer editable here — it comes exclusively from
    // Login (see LoginScreen) and is only displayed read-only below.
    PrintConfig.restaurantName           = _restaurantNameCtrl.text.trim();
    PrintConfig.kotCopies                = int.tryParse(_kotCopiesCtrl.text) ?? 1;
    PrintConfig.billCopies               = int.tryParse(_billCopiesCtrl.text) ?? 1;
    PrintConfig.autoPrint                = _autoPrint;
    PrintConfig.autoPrintBill            = _autoPrintBill;
    PrintConfig.autoPrintCancelKot       = _autoPrintCancelKot;
    PrintConfig.autoSettle               = _autoSettle;
    PrintConfig.aggregatorAutoKot        = _aggregatorAutoKot;
    PrintConfig.aggregatorAutoBill       = _aggregatorAutoBill;
    PrintConfig.aggregatorAutoBillStage  = _aggregatorAutoBillStage;
    PrintConfig.scanOrderAutoPrint       = _scanOrderAutoPrint;
    PrintConfig.kotSeparateTicket        = _kotSeparateTicket;
    PrintConfig.paperSize                = _paperSize;
    PrintConfig.usePdfPrintingOnWindows  = _usePdfPrintingOnWindows;
    PrintConfig.showItemDateOn80mm       = _showItemDateOn80mm;
    PrintConfig.feedbackQrEnabled        = _feedbackQrEnabled;
    PrintConfig.feedbackQrUrl            = _feedbackQrUrlCtrl.text.trim();
    PrintConfig.upiQrEnabled             = _upiQrEnabled;
    PrintConfig.upiDynamicEnabled        = _upiDynamicEnabled;
    PrintConfig.upiId                    = _upiIdCtrl.text.trim();

    // Derive legacy single-printer fields from first printer for backward compat
    final first = _printers.first;
    PrintConfig.connectionType = first.type == PrinterType.lan
        ? PrinterConnectionType.lan
        : first.type == PrinterType.bluetooth
            ? PrinterConnectionType.bluetooth
            : PrinterConnectionType.usb;
    PrintConfig.lanIp              = first.ipAddress ?? '';
    PrintConfig.lanPort            = first.port;
    PrintConfig.macAddress         = first.macAddress ?? '';
    PrintConfig.printerName        = first.windowsPrinterName ?? '';
    PrintConfig.usbVendorId        = first.vendorId ?? 0;
    PrintConfig.usbProductId       = first.productId ?? 0;
    PrintConfig.stations           = _printers.expand((p) => p.handledStations).toSet();

    await PrintConfig.save();
    await PrinterConfigStorage.save(_printers);

    widget.onSaved();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Saved! ${_printers.length} printer(s) configured'),
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

  void _copyToken() {
    if (PrintConfig.authToken.isEmpty) return;
    Clipboard.setData(ClipboardData(text: PrintConfig.authToken));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token copied to clipboard'), duration: Duration(seconds: 2)),
    );
  }

  // ── Add / Edit printer ────────────────────────────────────────────────────
  void _showAddPrinterSheet({PrinterConfig? existing, int? editIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PrinterFormSheet(
        is80mm:       _paperSize != AgentPaperSize.mm58,
        initial:      existing,
        onConfirmed:  (cfg) {
          setState(() {
            if (editIndex != null) {
              _printers[editIndex] = cfg;
            } else {
              _printers.add(cfg);
            }
          });
        },
      ),
    );
  }

  void _removePrinter(int index) {
    setState(() => _printers.removeAt(index));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Settings'),
        actions: [
          TextButton.icon(
            icon:  const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
            onPressed: _isSyncing ? null : _save,
          ),
        ],
      ),
      body: _isSyncing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Account ─────────────────────────────────────────────────────
          _sectionHeader('🔐 Account'),
          _tokenField(),
          const SizedBox(height: 16),

          // ── Identity ────────────────────────────────────────────────────
          _sectionHeader('🏪 Identity'),
          _field(controller: _restaurantIdCtrl, label: 'Restaurant ID (from Profile)',
              hint: '1', icon: Icons.restaurant, numeric: true, readOnly: true),
          _field(controller: _empIdCtrl, label: 'Employee ID (printer_agent_id)',
              hint: '002', icon: Icons.badge),
          _field(controller: _restaurantNameCtrl, label: 'Restaurant Name',
              hint: 'Hogwarts', icon: Icons.storefront),
          _field(controller: _billFooterCtrl, label: 'Bill Footer',
              hint: 'Powered by MyGenie', icon: Icons.notes, readOnly: true),
          const SizedBox(height: 16),

          // ── Printers (dynamic list) ──────────────────────────────────────
          _sectionHeader('🖨️ Printers'),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Add one printer per physical device. Assign stations (KDS, BAR, PIZZA…) '
              'and/or enable "Handles Bill" so the router knows where to send each job.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),

          if (_printers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade700),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'No printers configured yet. Tap + Add Printer below.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._printers.asMap().entries.map((entry) {
              final index  = entry.key;
              final config = entry.value;
              return _PrinterCard(
                config:   config,
                index:    index,
                onEdit:   () => _showAddPrinterSheet(existing: config, editIndex: index),
                onDelete: () => _removePrinter(index),
              );
            }),

          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showAddPrinterSheet(),
            icon:  const Icon(Icons.add),
            label: const Text('Add Printer'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 24),

          // ── Paper & Copies ───────────────────────────────────────────────
          _sectionHeader('📄 Paper & Copies'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<AgentPaperSize>(
              value: _paperSize,
              decoration: const InputDecoration(
                labelText: 'Paper Size (applied to all printers)',
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
                filled: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: AgentPaperSize.mm58,
                  child: Text('58mm — Small receipt'),
                ),
                DropdownMenuItem(
                  value: AgentPaperSize.mm80,
                  child: Text('80mm — Wide receipt'),
                ),
                DropdownMenuItem(
                  value: AgentPaperSize.a4,
                  child: Text('A4 — Full page bill'),
                ),
              ],
              onChanged: (v) => setState(() {
                _paperSize = v ?? AgentPaperSize.mm58;
              }),
            ),
          ),
          _field(controller: _billCopiesCtrl, label: 'Bill Copies',
              hint: '1', icon: Icons.content_copy, numeric: true),
          const SizedBox(height: 8),
          _field(controller: _kotCopiesCtrl, label: 'KOT Copies',
              hint: '1', icon: Icons.content_copy, numeric: true),
          const SizedBox(height: 16),

          // ── Windows PDF ─────────────────────────────────────────────────
          if (Platform.isWindows) ...[
            _sectionHeader('🪟 Windows Options'),
            _toggle(
              label:    'Use PDF Printing on Windows',
              subtitle: 'Send receipts as PDF via the Windows print spooler',
              value:    _usePdfPrintingOnWindows,
              onChanged: (v) => setState(() => _usePdfPrintingOnWindows = v),
            ),
            const SizedBox(height: 16),
          ],

          // ── Auto Print ───────────────────────────────────────────────────
          _sectionHeader('⚡ Auto Print'),
          _toggle(
            label:    'Auto Print KOT',
            subtitle: 'Print KOT automatically when a new order arrives',
            value:    _autoPrint,
            onChanged: (v) => setState(() => _autoPrint = v),
          ),
          _toggle(
            label:    'Auto Print Cancel KOT',
            subtitle: 'Print Cancel KOT when items are cancelled (normal POS)',
            value:    _autoPrintCancelKot,
            onChanged: (v) => setState(() => _autoPrintCancelKot = v),
          ),
          _toggle(
            label:    'Auto Print Bill',
            subtitle: 'Print bill on manually_print bill event',
            value:    _autoPrintBill,
            onChanged: (v) => setState(() => _autoPrintBill = v),
          ),
          _toggle(
            label:    'Auto Settle',
            subtitle: 'Print bill on new-order when billing_auto_bill_print and print_bill_status are Yes',
            value:    _autoSettle,
            onChanged: (v) => setState(() => _autoSettle = v),
          ),
          _toggle(
            label:    'Scan Order Auto Print',
            subtitle: 'Print KOT automatically for scanned (scan-new-order) orders',
            value:    _scanOrderAutoPrint,
            onChanged: (v) => setState(() => _scanOrderAutoPrint = v),
          ),
          _toggle(
            label:    'KOT separate ticket',
            subtitle: 'Print each countable KOT item as its own ticket',
            value:    _kotSeparateTicket,
            onChanged: (v) => setState(() => _kotSeparateTicket = v),
          ),
          const SizedBox(height: 16),

          // ── Aggregator Auto Print ────────────────────────────────────────
          _sectionHeader('📦 Aggregator Auto Print'),
          _toggle(
            label:    'Aggregator Auto KOT',
            subtitle: 'Print KOT when aggregator order is Acknowledged',
            value:    _aggregatorAutoKot,
            onChanged: (v) => setState(() => _aggregatorAutoKot = v),
          ),
          _toggle(
            label:    'Aggregator Auto Bill',
            subtitle: 'Print Bill when aggregator order reaches selected stage',
            value:    _aggregatorAutoBill,
            onChanged: (v) => setState(() => _aggregatorAutoBill = v),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                value: _aggregatorAutoBillStage,
                decoration: const InputDecoration(
                  labelText: 'Aggregator Auto Bill Stage',
                  border: InputBorder.none,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Acknowledged',
                    child: Text('Acknowledged'),
                  ),
                  DropdownMenuItem(
                    value: 'Food Ready',
                    child: Text('Food Ready'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _aggregatorAutoBillStage = v);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Bill Display Options ─────────────────────────────────────────
          _sectionHeader('🗓️ Bill Display Options'),
          _toggle(
            label:    'Show Food Item Date on Bill',
            subtitle: 'Print item ordered date (80mm bill only)',
            value:    _showItemDateOn80mm,
            onChanged: (v) => setState(() => _showItemDateOn80mm = v),
          ),
          const SizedBox(height: 16),

          // ── QR Codes (bill only, never on aggregator/KOT) ────────────────
          _sectionHeader('📱 QR Codes'),
          _toggle(
            label:    'UPI Payment QR',
            subtitle: 'Print a scan-to-pay QR on the bill',
            value:    _upiQrEnabled,
            onChanged: (v) => setState(() => _upiQrEnabled = v),
          ),
          if (_upiQrEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _upiIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID',
                        hintText: 'restaurant@upi',
                        prefixIcon: Icon(Icons.qr_code),
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Dynamic', style: TextStyle(fontSize: 11)),
                      Switch(
                        value: _upiDynamicEnabled,
                        onChanged: (v) =>
                            setState(() => _upiDynamicEnabled = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          _toggle(
            label:    'Feedback QR',
            subtitle: 'Print a scan-for-feedback QR on the bill',
            value:    _feedbackQrEnabled,
            onChanged: (v) => setState(() => _feedbackQrEnabled = v),
          ),
          if (_feedbackQrEnabled)
            _field(controller: _feedbackQrUrlCtrl, label: 'Feedback URL (optional)',
                hint: 'Leave blank to use the default MyGenie feedback link',
                icon: Icons.link),
          const SizedBox(height: 32),

          // ── Save button ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon:    const Icon(Icons.save),
              label:   const Text('Save & Reconnect', style: TextStyle(fontSize: 16)),
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(
      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent,
    )),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool numeric = false,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(), filled: true,
      ),
    ),
  );

  /// Read-only — the auth token now comes exclusively from Login and can no
  /// longer be edited or pasted here. Shown for visibility/debugging only.
  Widget _tokenField() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _authTokenCtrl,
      obscureText: _obscureToken,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Auth Token (from Login)',
        prefixIcon: const Icon(Icons.key),
        border: const OutlineInputBorder(), filled: true,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_obscureToken ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy',
              onPressed: _copyToken,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _toggle({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Card(
    child: SwitchListTile(
      title: Text(label),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Printer card — shows one configured printer with edit/delete
// ════════════════════════════════════════════════════════════════════════════
class _PrinterCard extends StatelessWidget {
  final PrinterConfig config;
  final int           index;
  final VoidCallback  onEdit;
  final VoidCallback  onDelete;

  const _PrinterCard({
    required this.config,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final connectionDetail = _connectionDetail();
    final allStations      = [
      ...config.handledStations,
      if (config.handlesBill) 'BILL',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_typeIcon(config.type), color: Colors.tealAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    config.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.tealAccent),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  tooltip: 'Remove',
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${config.type.name.toUpperCase()}  •  $connectionDetail',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            if (allStations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: allStations.map((s) => Chip(
                  label: Text(s, style: const TextStyle(fontSize: 11)),
                  backgroundColor: s == 'BILL'
                      ? Colors.orange.withOpacity(0.2)
                      : Colors.teal.withOpacity(0.2),
                  side: BorderSide(
                    color: s == 'BILL' ? Colors.orange : Colors.teal,
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '⚠️ No stations assigned — this printer will never receive jobs',
                  style: TextStyle(color: Colors.orange.shade300, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _connectionDetail() {
    switch (config.type) {
      case PrinterType.lan:
      case PrinterType.wifi:
        return '${config.ipAddress ?? '—'}:${config.port}';
      case PrinterType.bluetooth:
        return BluetoothAddress.displayMac(config.macAddress ?? '—');
      case PrinterType.usb:
        if (Platform.isWindows) return config.windowsPrinterName ?? '—';
        return 'vendor=${config.vendorId} product=${config.productId}';
    }
  }

  IconData _typeIcon(PrinterType t) {
    switch (t) {
      case PrinterType.lan:
      case PrinterType.wifi:   return Icons.wifi;
      case PrinterType.bluetooth: return Icons.bluetooth;
      case PrinterType.usb:    return Icons.usb;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Add / Edit printer bottom sheet
// ════════════════════════════════════════════════════════════════════════════
class _PrinterFormSheet extends StatefulWidget {
  final bool          is80mm;
  final PrinterConfig? initial;
  final ValueChanged<PrinterConfig> onConfirmed;

  const _PrinterFormSheet({
    required this.is80mm,
    required this.onConfirmed,
    this.initial,
  });

  @override
  State<_PrinterFormSheet> createState() => _PrinterFormSheetState();
}

class _PrinterFormSheetState extends State<_PrinterFormSheet> {
  final _labelCtrl       = TextEditingController();
  final _ipCtrl          = TextEditingController();
  final _portCtrl        = TextEditingController(text: '9100');
  final _printerNameCtrl = TextEditingController();
  final _macCtrl         = TextEditingController();
  final _stationCtrl     = TextEditingController();

  PrinterConnectionType _connType    = PrinterConnectionType.usb;
  bool                  _handlesBill = false;
  Set<String>           _stations    = {};
  BluetoothMode?        _bluetoothMode;

  List<Printer> _foundPrinters = [];
  Printer?      _selectedPrinter;
  bool          _scanning      = false;
  bool          _isTestingLan  = false;
  String?       _lanTestResult;
  bool          _lanTestSuccess = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _labelCtrl.text       = init.label;
      _handlesBill          = init.handlesBill;
      _stations             = Set.from(init.handledStations);

      if (init.type == PrinterType.lan || init.type == PrinterType.wifi) {
        _connType         = PrinterConnectionType.lan;
        _ipCtrl.text      = init.ipAddress ?? '';
        _portCtrl.text    = init.port.toString();
      } else if (init.type == PrinterType.bluetooth) {
        _connType         = PrinterConnectionType.bluetooth;
        _macCtrl.text     = BluetoothAddress.displayMac(init.macAddress ?? '');
        _bluetoothMode    = init.bluetoothMode;
      } else {
        _connType = PrinterConnectionType.usb;
        _printerNameCtrl.text = init.windowsPrinterName ?? '';
      }
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _printerNameCtrl.dispose();
    _macCtrl.dispose();
    _stationCtrl.dispose();
    super.dispose();
  }

  void _addStation() {
    final val = _stationCtrl.text.trim().toUpperCase();
    if (val.isEmpty) return;
    setState(() {
      _stations.add(val);
      _stationCtrl.clear();
    });
  }

  void _removeStation(String s) => setState(() => _stations.remove(s));

  Future<void> _scanPrinters() async {
    // USB only — Bluetooth uses Diagnostics (see _scanBluetoothPrinters)
    setState(() { _scanning = true; _foundPrinters.clear(); });
    try {
      final plugin = FlutterThermalPrinter.instance;
      await plugin.getPrinters(connectionTypes: [ConnectionType.USB]);
      plugin.devicesStream.listen((list) {
        if (mounted) {
          setState(() {
            _foundPrinters = list
                .where((p) => p.connectionType == ConnectionType.USB)
                .toList();
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _scanning = false);
    }
  }

  /// Opens Diagnostics on Bluetooth tab → discover → test → return MAC.
  Future<void> _scanBluetoothPrinters() async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<BluetoothScanResult>(
      MaterialPageRoute(
        builder: (_) => const DiagnosticsScreen(
          initialMode: DiagnosticConnectionType.bluetooth,
          autoStartDiscover: true,
          returnResult: true,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _macCtrl.text = BluetoothAddress.displayMac(result.macAddress);
      _bluetoothMode = result.mode;
    });
  }

  Future<void> _testLan() async {
    final ip   = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text) ?? 9100;
    if (ip.isEmpty) return;
    setState(() { _isTestingLan = true; _lanTestResult = null; });
    try {
      final s = await Socket.connect(ip, port, timeout: const Duration(seconds: 3));
      await s.close();
      setState(() { _lanTestSuccess = true; _lanTestResult = '✅ Reachable at $ip:$port'; });
    } catch (_) {
      setState(() { _lanTestSuccess = false; _lanTestResult = '❌ Cannot reach $ip:$port'; });
    } finally {
      setState(() => _isTestingLan = false);
    }
  }

  void _confirm() {
    if (_labelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Printer label is required'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_stations.isEmpty && !_handlesBill) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Assign at least one station or enable "Handles Bill"'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paperSize = widget.is80mm ? PaperSize.mm80 : PaperSize.mm58;
    final id        = widget.initial?.id
        ?? 'printer_${DateTime.now().millisecondsSinceEpoch}';

    PrinterConfig config;
    switch (_connType) {
      case PrinterConnectionType.lan:
        config = PrinterConfig(
          id: id, label: _labelCtrl.text.trim(),
          type: PrinterType.lan,
          ipAddress: _ipCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text) ?? 9100,
          paperSize: paperSize,
          handledStations: _stations, handlesBill: _handlesBill,
        );
        break;
      case PrinterConnectionType.bluetooth:
        config = PrinterConfig(
          id: id, label: _labelCtrl.text.trim(),
          type: PrinterType.bluetooth,
          macAddress: BluetoothAddress.extractPrinterMac(_macCtrl.text.trim()) ??
              _macCtrl.text.trim(),
          bluetoothMode: _bluetoothMode ?? BluetoothMode.ble,
          paperSize: paperSize,
          handledStations: _stations, handlesBill: _handlesBill,
        );
        break;
      case PrinterConnectionType.usb:
        config = PrinterConfig(
          id: id, label: _labelCtrl.text.trim(),
          type: PrinterType.usb,
          windowsPrinterName: _printerNameCtrl.text.trim(),
          vendorId:  _selectedPrinter != null
              ? (int.tryParse(_selectedPrinter!.vendorId ?? '0') ?? 0)
              : widget.initial?.vendorId,
          productId: _selectedPrinter != null
              ? (int.tryParse(_selectedPrinter!.productId ?? '0') ?? 0)
              : widget.initial?.productId,
          paperSize: paperSize,
          handledStations: _stations, handlesBill: _handlesBill,
        );
        break;
    }

    widget.onConfirmed(config);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  widget.initial == null ? 'Add Printer' : 'Edit Printer',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Label
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Printer Label',
                hintText: 'e.g. Kitchen, Bar Counter, Billing',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(), filled: true,
              ),
            ),
            const SizedBox(height: 14),

            // Connection type
            SegmentedButton<PrinterConnectionType>(
              segments: const [
                ButtonSegment(value: PrinterConnectionType.usb,       label: Text('USB'),       icon: Icon(Icons.usb)),
                ButtonSegment(value: PrinterConnectionType.lan,       label: Text('LAN'),       icon: Icon(Icons.wifi)),
                ButtonSegment(value: PrinterConnectionType.bluetooth, label: Text('Bluetooth'), icon: Icon(Icons.bluetooth)),
              ],
              selected: {_connType},
              onSelectionChanged: (v) => setState(() {
                _connType = v.first;
                _foundPrinters.clear();
                _lanTestResult = null;
              }),
            ),
            const SizedBox(height: 14),

            // ── USB ───────────────────────────────────────────────────────
            if (_connType == PrinterConnectionType.usb) ...[
              if (Platform.isWindows) ...[
                TextField(
                  controller: _printerNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Windows Printer Name',
                    hintText: 'Everycom-printer',
                    prefixIcon: Icon(Icons.print),
                    border: OutlineInputBorder(), filled: true,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Match exactly what appears in Windows Devices & Printers',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _scanning ? null : _scanPrinters,
                  icon: _scanning
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.usb),
                  label: Text(_scanning ? 'Scanning...' : 'Scan USB Printers'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                ),
                if (_foundPrinters.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Printer>(
                    decoration: const InputDecoration(labelText: 'Select Printer',
                        border: OutlineInputBorder(), filled: true),
                    items: _foundPrinters.map((p) => DropdownMenuItem<Printer>(
                      value: p,
                      child: Text('${p.name ?? 'Printer'} — ${p.vendorId}'),
                    )).toList(),
                    onChanged: (p) => setState(() => _selectedPrinter = p),
                  ),
                ],
                if (_selectedPrinter != null) ...[
                  const SizedBox(height: 6),
                  Text('✅ vendor=${_selectedPrinter!.vendorId} product=${_selectedPrinter!.productId}',
                      style: const TextStyle(color: Colors.green, fontSize: 12)),
                ],
              ],
            ],

            // ── LAN ───────────────────────────────────────────────────────
            if (_connType == PrinterConnectionType.lan) ...[
              TextField(
                controller: _ipCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(
                  labelText: 'IP Address', hintText: '192.168.1.100',
                  prefixIcon: Icon(Icons.router),
                  border: OutlineInputBorder(), filled: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _portCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port', hintText: '9100',
                  prefixIcon: Icon(Icons.settings_ethernet),
                  border: OutlineInputBorder(), filled: true,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isTestingLan ? null : _testLan,
                icon: _isTestingLan
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_find),
                label: Text(_isTestingLan ? 'Testing...' : 'Test Connection'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
              ),
              if (_lanTestResult != null) ...[
                const SizedBox(height: 6),
                Text(
                  _lanTestResult!,
                  style: TextStyle(color: _lanTestSuccess ? Colors.green : Colors.red, fontSize: 12),
                ),
              ],
            ],

            // ── Bluetooth ─────────────────────────────────────────────────
            if (_connType == PrinterConnectionType.bluetooth) ...[
              ElevatedButton.icon(
                onPressed: _scanBluetoothPrinters,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Scan Bluetooth Printers'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  backgroundColor: Colors.blueAccent,
                ),
              ),
              if (_macCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('✅ MAC: ${_macCtrl.text}',
                    style: const TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            // ── Stations ──────────────────────────────────────────────────
            const Text('Kitchen Stations', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Items whose station field matches one of these will be routed here for KOT printing.',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 8),

            if (_stations.isNotEmpty)
              Wrap(
                spacing: 6, runSpacing: 4,
                children: _stations.map((s) => Chip(
                  label: Text(s),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => _removeStation(s),
                  backgroundColor: Colors.teal.withOpacity(0.2),
                  side: const BorderSide(color: Colors.teal),
                )).toList(),
              ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stationCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Station Name',
                      hintText: 'KDS / BAR / PIZZA',
                      border: OutlineInputBorder(), filled: true,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addStation(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addStation,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Handles Bill ──────────────────────────────────────────────
            Card(
              child: SwitchListTile(
                title: const Text('Handles Bill'),
                subtitle: const Text('Bill print jobs will be routed to this printer'),
                value: _handlesBill,
                onChanged: (v) => setState(() => _handlesBill = v),
              ),
            ),
            const SizedBox(height: 20),

            // ── Confirm ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _confirm,
                icon:  const Icon(Icons.check),
                label: Text(widget.initial == null ? 'Add Printer' : 'Update Printer'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
