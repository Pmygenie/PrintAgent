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

  PrintJob({
    required this.type,
    required this.printerId,
    required this.order,
    this.status = PrintJobStatus.pending,
    this.retries = 0,
    this.stationLabel, // ✅ optional — only set for station-filtered KOTs
  }) : id = const Uuid().v4();
}