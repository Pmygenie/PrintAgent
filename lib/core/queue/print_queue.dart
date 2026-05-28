import 'dart:async';
import 'dart:collection';
import '../models/print_job.dart';
import '../printer/printer_manager.dart';

class PrintQueue {
  final Queue<PrintJob> _queue = Queue();
  final PrinterManager _manager;
  bool _isProcessing = false;

  PrinterManager get manager => _manager;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;
  int get length => _queue.length;

  PrintQueue(this._manager);

  void addJob(PrintJob job) {
    _queue.add(job);
    _emit('=====> QUEUED | ${job.id} | Order Id -${job.order.displayOrderId}');
    _processNext();
  }

  Future<void> _processNext() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;
    final job = _queue.first;

    try {
      job.status = PrintJobStatus.printing;
      _emit('=====> PRINTING | ${job.id} | Order Id - ${job.order.displayOrderId}');
      await _manager.print(job);
      job.status = PrintJobStatus.done;
      _queue.removeFirst();
      _emit('=====> DONE | ${job.id} | Order Id - ${job.order.displayOrderId}');
    } catch (e, stackTrace) {
      // ← add stackTrace
      // ✅ NOW we can see the real error
      print('❌ PRINT ERROR: $e');
      print('❌ STACK: $stackTrace');
      _emit('=====> ERROR | Order Id - ${job.order.displayOrderId} | $e'); // ← show in UI log

      if (job.retries < 3) {
        job.retries++;
        job.status = PrintJobStatus.pending;
        _emit('=====> RETRY | ${job.retries} | Order Id - ${job.order.displayOrderId}');
        await Future.delayed(const Duration(seconds: 2));
      } else {
        job.status = PrintJobStatus.failed;
        _queue.removeFirst();
        _emit('=====> FAILED | ${job.id} | Order Id - ${job.order.displayOrderId}');
      }
    } finally {
      _isProcessing = false;
      _processNext();
    }
  }

  void _emit(String msg) {
    print('[Queue] $msg');
    _statusController.add(msg);
  }

  void dispose() => _statusController.close();
}
