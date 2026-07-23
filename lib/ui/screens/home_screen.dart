import 'dart:async';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printer_agent/ui/screens/print_style_screen.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/printer_config.dart';
import 'package:printer_agent/core/profile/restaurant_profile_api.dart';
import 'package:printer_agent/core/profile/restaurant_profile_repository.dart';
import 'package:printer_agent/core/profile/restaurant_profile_store.dart';
import 'package:printer_agent/ui/screens/diagnostics_screen.dart';
import 'package:printer_agent/ui/screens/settings_screen.dart';
import '../../core/queue/print_queue_manager.dart';
import '../../core/router/printer_router.dart';
import '../../core/socket/windows_socket_service.dart';

class HomeScreen extends StatefulWidget {
  final WindowsSocketService? windowsSocket;
  final PrintQueueManager? queueManager;

  const HomeScreen({
    super.key,
    required this.windowsSocket,
    required this.queueManager,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WindowsSocketService? _socketService;
  PrintQueueManager?    _queueManager;

  StreamSubscription? _queueSub;
  StreamSubscription? _socketStatusSub;
  StreamSubscription? _socketLogSub;

  final List<String> _logs = [];
  bool   _connected   = false;
  bool   _isRefreshingProfile = false;
  int    _queueLength = 0;
  String _lastPrint   = '—';

  // ── Profile refresh ──────────────────────────────────────────────────────
  Future<void> _refreshRestaurantProfile() async {
    if (_isRefreshingProfile) return;
    setState(() => _isRefreshingProfile = true);

    try {
      final token = PrintConfig.authToken;
      if (token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auth token not found')),
        );
        return;
      }

      final repo = RestaurantProfileRepository(
        api:   RestaurantProfileApi(),
        store: RestaurantProfileStore(),
      );

      final profile = await repo.refresh(token: token);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profile != null && profile.isNotEmpty
                ? 'Restaurant profile refreshed successfully'
                : 'Profile refresh completed, but no data found',
          ),
        ),
      );

      if (profile != null && profile.isNotEmpty) {
        print('Restaurant profile reSynced: ${profile.restaurantName}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isRefreshingProfile = false);
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _socketService = widget.windowsSocket;
    _queueManager  = widget.queueManager;
    _setupListeners();
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    _socketStatusSub?.cancel();
    _socketLogSub?.cancel();
    _socketService?.disconnect();
    _queueManager?.dispose();
    super.dispose();
  }

  // ── Log helpers ──────────────────────────────────────────────────────────
  String _ts() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}:'
        '${n.second.toString().padLeft(2, '0')}';
  }

  void _addLog(String msg) {
    setState(() {
      _logs.insert(0, '[${_ts()}]  $msg');
      if (_logs.length > 100) _logs.removeRange(80, _logs.length);
    });
  }

  void _clearLogs() => setState(() => _logs.clear());

  void _copyLogs() {
    if (_logs.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Listeners ────────────────────────────────────────────────────────────
  void _setupListeners() {
    _queueSub?.cancel();
    _socketStatusSub?.cancel();
    _socketLogSub?.cancel();

    // Queue status from ALL printers (merged stream with per-printer labels)
    _queueSub = _queueManager?.statusStream.listen((msg) {
      String displayMsg = msg;
      if (msg.contains('DONE')) {
        final upper = msg.toUpperCase();
        if (upper.contains('KOT')) {
          displayMsg = '$msg  (KOT copies: ${PrintConfig.kotCopies})';
        } else {
          displayMsg = '$msg  (Bill copies: ${PrintConfig.billCopies})';
        }
      }
      _addLog(displayMsg);
      setState(() {
        if (msg.contains('DONE')) {
          final parts = msg.split('|');
          _lastPrint  = parts.length > 2 ? parts[2].trim() : '—';
          _queueLength = _queueManager?.totalLength ?? 0;
        }
        if (msg.contains('QUEUED')) {
          _queueLength = _queueManager?.totalLength ?? 0;
        }
      });
    });

    _socketStatusSub = _socketService?.statusStream.listen((connected) {
      setState(() => _connected = connected);
    });

    _socketLogSub = _socketService?.logStream.listen(_addLog);
  }

  // ── Reconnect — rebuild everything from saved configs ────────────────────
  Future<void> _reconnect() async {
    _socketService?.disconnect();
    _queueManager?.dispose();

    final savedPrinters = await PrinterConfigStorage.load();
    final printers = savedPrinters.isNotEmpty
        ? savedPrinters
        : [_buildFallbackConfig()];

    final newQueueManager = PrintQueueManager()..registerAll(printers);
    final newRouter       = PrinterRouter(printers);
    final newSocket       = WindowsSocketService(newQueueManager, newRouter)..connect();

    if (!mounted) return;
    setState(() {
      _socketService = newSocket;
      _queueManager  = newQueueManager;
    });

    _addLog('♻️ Reconnected — ${printers.length} printer(s) registered');
    _setupListeners();
  }

  /// Fallback single printer built from global PrintConfig settings.
  PrinterConfig _buildFallbackConfig() {
    final paperSize = PrintConfig.is80mm ? PaperSize.mm80 : PaperSize.mm58;
    if (PrintConfig.connectionType == PrinterConnectionType.lan) {
      return PrinterConfig(
        id: 'kitchen_printer', label: 'Kitchen Printer',
        type: PrinterType.lan,
        ipAddress: PrintConfig.lanIp, port: PrintConfig.lanPort,
        paperSize: paperSize,
        handledStations: PrintConfig.stations, handlesBill: true,
      );
    }
    if (PrintConfig.connectionType == PrinterConnectionType.bluetooth) {
      return PrinterConfig(
        id: 'kitchen_printer', label: 'Kitchen Printer',
        type: PrinterType.bluetooth,
        macAddress: PrintConfig.macAddress,
        paperSize: paperSize,
        handledStations: PrintConfig.stations, handlesBill: true,
      );
    }
    return PrinterConfig(
      id: 'kitchen_printer', label: 'Kitchen Printer',
      type: PrinterType.usb,
      windowsPrinterName: PrintConfig.printerName,
      vendorId: PrintConfig.usbVendorId,
      productId: PrintConfig.usbProductId,
      paperSize: paperSize,
      handledStations: PrintConfig.stations, handlesBill: true,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🖨️ Print Agent'),
        actions: [
          IconButton(
            onPressed: _isRefreshingProfile ? null : _refreshRestaurantProfile,
            icon: _isRefreshingProfile
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Restaurant Config',
          ),
          IconButton(
            icon: const Icon(Icons.format_paint),
            tooltip: 'Print Templates & Styles',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PrintStyleScreen(onSaved: _reconnect)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  onSaved:      _reconnect,
                  queueManager: _queueManager,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Diagnostics',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DiagnosticsScreen(
                  queueManager: _queueManager,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── Status Cards ─────────────────────────────────
          Row(children: [
            _statusCard(
              'Socket',
              _connected ? '🟢 Connected' : '🔴 Disconnected',
              _connected ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            _statusCard('Queue', '🖨️ $_queueLength jobs', Colors.orange),
            const SizedBox(width: 8),
            _statusCard('Last', '✅ $_lastPrint', Colors.teal),
          ]),

          const SizedBox(height: 16),

          // ── Live Log ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🪵 Live Log',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (_logs.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _copyLogs,
                      icon: const Icon(Icons.copy, size: 16, color: Colors.blueAccent),
                      label: const Text(
                        'Copy',
                        style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _clearLogs,
                      icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.redAccent),
                      label: const Text(
                        'Clear',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
            ],
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
                        'Waiting for events...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
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

  Widget _statusCard(String title, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}
