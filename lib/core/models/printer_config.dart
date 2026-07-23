import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum PrinterType { lan, wifi, bluetooth, usb }

class PrinterConfig {
  final String id;
  final String label;
  final PrinterType type;
  final String? ipAddress;
  final int port;
  final String? macAddress;
  final int? vendorId;
  final int? productId;
  final PaperSize paperSize;
  final String? windowsPrinterName;

  /// Kitchen stations this printer handles (e.g. {'KDS', 'BAR', 'PIZZA'}).
  /// Used by [PrinterRouter] to route KOT / cancel-KOT jobs.
  /// Leave empty if this printer only handles bills.
  final Set<String> handledStations;

  /// If true, this printer receives bill print jobs.
  final bool handlesBill;

  const PrinterConfig({
    required this.id,
    required this.label,
    required this.type,
    this.ipAddress,
    this.port = 9100,
    this.macAddress,
    this.vendorId,
    this.productId,
    this.paperSize = PaperSize.mm80,
    this.windowsPrinterName,
    this.handledStations = const {},
    this.handlesBill = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'type': type.name,
    'ipAddress': ipAddress,
    'port': port,
    'macAddress': macAddress,
    'vendorId': vendorId,
    'productId': productId,
    'paperSize': paperSize == PaperSize.mm80 ? '80' : '58',
    'windowsPrinterName': windowsPrinterName,
    'handledStations': handledStations.toList(),
    'handlesBill': handlesBill,
  };

  factory PrinterConfig.fromMap(Map<String, dynamic> m) => PrinterConfig(
    id:                 m['id'],
    label:              m['label'],
    type:               PrinterType.values.firstWhere((e) => e.name == m['type']),
    ipAddress:          m['ipAddress'],
    port:               m['port'] ?? 9100,
    macAddress:         m['macAddress'],
    vendorId:           m['vendorId'],
    productId:          m['productId'],
    paperSize:          m['paperSize'] == '58' ? PaperSize.mm58 : PaperSize.mm80,
    windowsPrinterName: m['windowsPrinterName'],
    // Backward-compatible: old saved configs without these fields default safely
    handledStations:    Set<String>.from(
                          (m['handledStations'] as List<dynamic>? ?? [])
                            .map((e) => e.toString().toUpperCase()),
                        ),
    handlesBill:        m['handlesBill'] as bool? ?? false,
  );

  /// Returns a copy of this config with the given fields overridden.
  PrinterConfig copyWith({
    String? id,
    String? label,
    PrinterType? type,
    String? ipAddress,
    int? port,
    String? macAddress,
    int? vendorId,
    int? productId,
    PaperSize? paperSize,
    String? windowsPrinterName,
    Set<String>? handledStations,
    bool? handlesBill,
  }) => PrinterConfig(
    id:                 id                 ?? this.id,
    label:              label              ?? this.label,
    type:               type               ?? this.type,
    ipAddress:          ipAddress          ?? this.ipAddress,
    port:               port               ?? this.port,
    macAddress:         macAddress         ?? this.macAddress,
    vendorId:           vendorId           ?? this.vendorId,
    productId:          productId          ?? this.productId,
    paperSize:          paperSize          ?? this.paperSize,
    windowsPrinterName: windowsPrinterName ?? this.windowsPrinterName,
    handledStations:    handledStations    ?? this.handledStations,
    handlesBill:        handlesBill        ?? this.handlesBill,
  );
}

// ── Persistence ────────────────────────────────────────────
class PrinterConfigStorage {
  static const _key = 'printer_configs';

  static Future<void> save(List<PrinterConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = configs.map((c) => jsonEncode(c.toMap())).toList();
    await prefs.setStringList(_key, list);
  }

  static Future<List<PrinterConfig>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list  = prefs.getStringList(_key) ?? [];
    return list
        .map((s) => PrinterConfig.fromMap(jsonDecode(s)))
        .toList();
  }
}