import 'dart:async';
import '../models/printer_config.dart';
import '../models/print_job.dart';
import '../printer/ble_session_registry.dart';
import '../printer/printer_manager.dart';
import 'print_queue.dart';

/// Manages one independent [PrintQueue] per physical printer.
///
/// Jobs are routed to the correct queue via [route]. Each queue runs
/// concurrently — a failure or jam on one printer never blocks another.
///
/// All per-printer status events are merged into [statusStream] with a
/// label prefix so the UI can display which printer is doing what.
class PrintQueueManager {
  final Map<String, PrintQueue> _queues = {};
  final Map<String, String> _labels = {};

  final _statusController = StreamController<String>.broadcast();

  /// Merged status stream from all registered printer queues.
  /// Each message is prefixed with the printer label, e.g.:
  ///   "[Kitchen Printer] =====> DONE | ..."
  Stream<String> get statusStream => _statusController.stream;

  /// Total number of pending jobs across all queues.
  int get totalLength => _queues.values.fold(0, (sum, q) => sum + q.length);

  /// Number of pending jobs for a specific printer.
  int lengthFor(String printerId) => _queues[printerId]?.length ?? 0;

  // ── Registration ────────────────────────────────────────────────────────

  /// Registers a printer and creates its dedicated queue.
  /// If a queue for this printer ID already exists it is disposed and replaced.
  void registerPrinter(PrinterConfig config) {
    // Dispose old queue if re-registering (e.g. on reconnect)
    _queues[config.id]?.dispose();

    final manager = PrinterManager()..registerPrinter(config);
    final queue   = PrintQueue(manager);

    // Pipe status events with the printer label prepended
    queue.statusStream.listen((msg) {
      final labeled = '[${config.label}] $msg';
      print(labeled);
      if (!_statusController.isClosed) {
        _statusController.add(labeled);
      }
    });

    _queues[config.id]  = queue;
    _labels[config.id]  = config.label;
    print('[QueueManager] ✅ Registered: ${config.label} (${config.id})');
  }

  /// Registers all printers in the list.
  void registerAll(List<PrinterConfig> configs) {
    for (final c in configs) {
      registerPrinter(c);
    }
  }

  // ── Routing ─────────────────────────────────────────────────────────────

  /// Routes a [PrintJob] to the queue of [job.printerId].
  /// Logs a warning if no queue is found for that ID.
  void route(PrintJob job) {
    final queue = _queues[job.printerId];
    if (queue == null) {
      print('[QueueManager] ❌ No queue for printerId="${job.printerId}" — job dropped');
      return;
    }
    queue.addJob(job);
  }

  // ── Accessors ────────────────────────────────────────────────────────────

  /// Returns the queue for a specific printer (used by diagnostics screen).
  PrintQueue? queueFor(String printerId) => _queues[printerId];

  /// All registered printer IDs.
  List<String> get printerIds => _queues.keys.toList();

  /// Label for a given printer ID.
  String labelFor(String printerId) => _labels[printerId] ?? printerId;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Disposes all queues and closes the merged status stream.
  /// Must be called before creating a new [PrintQueueManager] on reconnect.
  Future<void> dispose() async {
    await BleSessionRegistry.disconnectAll();
    for (final q in _queues.values) {
      q.dispose();
    }
    _queues.clear();
    _labels.clear();
    if (!_statusController.isClosed) {
      _statusController.close();
    }
    print('[QueueManager] 🗑️ Disposed all queues');
  }
}
