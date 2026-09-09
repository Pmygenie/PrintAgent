import 'dart:async';

import 'package:uuid/uuid.dart';
import 'restaurant_order.dart';

enum PrintJobStatus { pending, printing, done, failed }
enum PrintType { kot, bill, cancelKot }

class PrintJob {
  final String id;
  final PrintType type;
  final String printerId;
  final RestaurantOrder order;
  PrintJobStatus status;
  int retries;

  // ✅ NEW — which station this KOT is for (null = bill or all items)
  // e.g. 'BAR', 'KDS', 'PIZZA'
  final String? stationLabel;

  final Completer<void> _settled = Completer<void>();

  /// Resolves once the job reaches a terminal state: printed, failed after all
  /// retries, or abandoned because its queue was disposed / had no printer.
  /// Never completes with an error — waiters only care that it is finished.
  Future<void> get completed => _settled.future;

  /// Idempotent: safe to call from every terminal path.
  void markSettled() {
    if (!_settled.isCompleted) _settled.complete();
  }

  PrintJob({
    required this.type,
    required this.printerId,
    required this.order,
    this.status = PrintJobStatus.pending,
    this.retries = 0,
    this.stationLabel, // ✅ optional — only set for station-filtered KOTs
  }) : id = const Uuid().v4();
}