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
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'label': label,
    'type': type.name,
    'ipAddress': ipAddress, 'port': port,
    'macAddress': macAddress,
    'vendorId': vendorId, 'productId': productId,
    'paperSize': paperSize == PaperSize.mm80 ? '80' : '58',
    'windowsPrinterName': windowsPrinterName,
  };

  factory PrinterConfig.fromMap(Map<String, dynamic> m) => PrinterConfig(
    id:        m['id'],
    label:     m['label'],
    type:      PrinterType.values.firstWhere((e) => e.name == m['type']),
    ipAddress: m['ipAddress'],
    port:      m['port'] ?? 9100,
    macAddress: m['macAddress'],
    vendorId:  m['vendorId'],
    productId: m['productId'],
    paperSize: m['paperSize'] == '58' ? PaperSize.mm58 : PaperSize.mm80,
    windowsPrinterName:  m['windowsPrinterName'],
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