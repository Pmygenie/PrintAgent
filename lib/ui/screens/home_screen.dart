import 'dart:io';
import 'dart:async';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/printer_config.dart';
import 'package:printer_agent/core/printer/printer_manager.dart';
import 'package:printer_agent/core/profile/restaurant_profile_api.dart';
import 'package:printer_agent/core/profile/restaurant_profile_repository.dart';
import 'package:printer_agent/core/profile/restaurant_profile_store.dart';
import 'package:printer_agent/ui/screens/diagnostics_screen.dart';
import 'package:printer_agent/ui/screens/settings_screen.dart';
import '../../core/queue/print_queue.dart';
import '../../core/socket/windows_socket_service.dart';
import '../../core/models/restaurant_order.dart';

class HomeScreen extends StatefulWidget {
  final WindowsSocketService? windowsSocket;
  final PrintQueue? queue;

  const HomeScreen({
    super.key,
    required this.windowsSocket,
    required this.queue,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WindowsSocketService? _socketService;
  PrintQueue? _queue;

  StreamSubscription? _queueSub;
  StreamSubscription? _socketStatusSub;
  StreamSubscription? _socketLogSub;

  final List<String> _logs = [];
  bool _connected = false;
  bool _isRefreshingProfile = false;
  int _queueLength = 0;
  String _lastPrint = '—';

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
        api: RestaurantProfileApi(),
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
      if (mounted) {
        setState(() => _isRefreshingProfile = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _socketService = widget.windowsSocket;
    _queue = widget.queue;
    _setupListeners();
  }

  // ✅ NEW — single method to add log with hard cap
  void _addLog(String msg) {
    setState(() {
      _logs.insert(0, msg);
      if (_logs.length > 100) {
        _logs.removeRange(80, _logs.length); // trim to 80 when hits 100
      }
    });
  }

  // ✅ NEW — clear all logs
  void _clearLogs() {
    setState(() => _logs.clear());
  }

  // void _setupListeners() {
  //   // Queue status
  //   _queue?.statusStream.listen((msg) {
  //     _addLog(msg); // ✅ use _addLog
  //     setState(() {
  //       if (msg.startsWith('DONE')) {
  //         final parts = msg.split('|');
  //         _lastPrint = parts.length > 2 ? '#${parts[2]}' : '—';
  //         _queueLength = _queue?.length ?? 0;
  //       }
  //       if (msg.startsWith('QUEUED')) {
  //         _queueLength = _queue?.length ?? 0;
  //       }
  //     });
  //   });

  //   // Socket status
  //   _socketService?.statusStream.listen((connected) {
  //     setState(() => _connected = connected);
  //   });

  //   // Socket logs
  //   _socketService?.logStream.listen((msg) {
  //     _addLog(msg); // ✅ use _addLog
  //   });
  // }

  void _setupListeners() {
    // Cancel old ones first
    _queueSub?.cancel();
    _socketStatusSub?.cancel();
    _socketLogSub?.cancel();

    _queueSub = _queue?.statusStream.listen((msg) {
      _addLog(msg);
      setState(() {
        if (msg.startsWith('DONE')) {
          final parts = msg.split('|');
          _lastPrint = parts.length > 2 ? '#${parts[2]}' : '—';
          _queueLength = _queue?.length ?? 0;
        }
        if (msg.startsWith('QUEUED')) {
          _queueLength = _queue?.length ?? 0;
        }
      });
    });

    _socketStatusSub = _socketService?.statusStream.listen((connected) {
      setState(() => _connected = connected);
    });

    _socketLogSub = _socketService?.logStream.listen((msg) {
      _addLog(msg);
    });
  }

  // void _reconnect() {
  //   _socketService?.disconnect();
  //   _queue?.dispose();

  //   final config = Platform.isAndroid
  //       ? PrinterConfig(
  //           id: 'kitchen_printer',
  //           label: 'Kitchen Printer',
  //           type: PrinterType.usb,
  //           vendorId: PrintConfig.usbVendorId, // ✅ Android
  //           productId: PrintConfig.usbProductId,
  //           paperSize: PrintConfig.paperSize,
  //         )
  //       : PrinterConfig(
  //           id: 'kitchen_printer',
  //           label: 'Kitchen Printer',
  //           type: PrinterType.usb,
  //           windowsPrinterName: PrintConfig.printerName, // ✅ Windows
  //           paperSize: PrintConfig.paperSize,
  //         );

  //   final manager = PrinterManager()..registerPrinter(config);
  //   final newQueue = PrintQueue(manager);
  //   final newSocket = WindowsSocketService(newQueue)..connect();

  //   setState(() {
  //     _socketService = newSocket;
  //     _queue = newQueue;
  //   });

  //   _addLog('♻️ Reconnected with new settings');
  //   _setupListeners();
  // }

  void _reconnect() {
    _socketService?.disconnect();
    _queue?.dispose();

    // ✅ use connectionType — same logic as _buildDefaultPrinterConfig
    final config = PrintConfig.connectionType == PrinterConnectionType.lan
        ? PrinterConfig(
            id: 'kitchen_printer',
            label: 'Kitchen Printer',
            type: PrinterType.lan,
            ipAddress: PrintConfig.lanIp,
            port: PrintConfig.lanPort,
            paperSize: PrintConfig.paperSize,
          )
        : Platform.isAndroid
            ? PrinterConfig(
                id: 'kitchen_printer',
                label: 'Kitchen Printer',
                type: PrinterType.usb,
                vendorId: PrintConfig.usbVendorId,
                productId: PrintConfig.usbProductId,
                paperSize: PrintConfig.paperSize,
              )
            : PrinterConfig(
                id: 'kitchen_printer',
                label: 'Kitchen Printer',
                type: PrinterType.usb,
                windowsPrinterName: PrintConfig.printerName,
                paperSize: PrintConfig.paperSize,
              );

    final manager = PrinterManager()..registerPrinter(config);
    final newQueue = PrintQueue(manager);
    final newSocket = WindowsSocketService(newQueue)..connect();

    setState(() {
      _socketService = newSocket;
      _queue = newQueue;
    });

    _addLog('♻️ Reconnected with new settings');
    _setupListeners();
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    _socketStatusSub?.cancel();
    _socketLogSub?.cancel();
    _socketService?.disconnect();
    _queue?.dispose();
    super.dispose();
  }

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
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Restaurant Config',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  onSaved: _reconnect,
                  queue: _queue,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Diagnostics',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DiagnosticsScreen())),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── Status Cards ──────────────────────────────
          Row(children: [
            _statusCard(
                'Socket',
                _connected ? '🟢 Connected' : '🔴 Disconnected',
                _connected ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            _statusCard('Queue', '🖨️ $_queueLength jobs', Colors.orange),
            const SizedBox(width: 8),
            _statusCard('Last', '✅ $_lastPrint', Colors.teal),
          ]),

          const SizedBox(height: 16),

          // ── Live Log ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🪵 Live Log',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (_logs.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearLogs, // ✅ clear button
                  icon: const Icon(Icons.delete_sweep,
                      size: 16, color: Colors.redAccent),
                  label: const Text('Clear',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
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
                      child: Text('Waiting for events...',
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
