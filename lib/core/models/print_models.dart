enum PrintJobType { kot, bill }

enum PrinterType { lan, wifi, bluetooth, usb }

enum PaperKind { mm58, mm80 }

class PrintJob {
  PrintJob({
    required this.jobId,
    required this.eventType,
    required this.orderId,
    required this.restaurantId,
    required this.status,
    required this.type,
    this.createdAt,
    this.attempts = 0,
  });

  final String jobId;
  final String eventType;
  final int orderId;
  final int restaurantId;
  final int status;
  final PrintJobType type;
  final DateTime? createdAt;
  int attempts;
}

class PrinterConfig {
  PrinterConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.paperKind,
    required this.role,
    this.host,
    this.port = 9100,
    this.macAddress,
    this.vendorId,
    this.productId,
  });

  final String id;
  final String name;
  final PrinterType type;
  final PaperKind paperKind;
  final String role;

  final String? host;
  final int port;
  final String? macAddress;
  final int? vendorId;
  final int? productId;
}
