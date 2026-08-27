import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/print_style_config.dart';
import 'package:printer_agent/core/models/printer_config.dart';

/// Maps the JSON `data` payload of the `printer-agent-config` endpoint onto
/// the app's existing local configuration models.
///
/// Only fields that already have a concrete home in [PrintConfig],
/// [PrinterConfig] or [PrintStyleConfig] are mapped. Anything else present
/// in the API response (e.g. restaurant contact details, footer text,
/// per-restaurant "preferred printer type") is intentionally ignored — no
/// new fields or UI are introduced by this integration.
class PrinterAgentConfigMapper {
  PrinterAgentConfigMapper._();

  // ── settings_config → PrintConfig / PrinterConfig ─────────────────────────

  /// Applies `settings_config` onto [PrintConfig] statics and returns the
  /// mapped printer list. Callers are responsible for persisting both
  /// (`PrintConfig.save()` / `PrinterConfigStorage.save()`).
  static List<PrinterConfig> applySettingsConfig(
    Map<String, dynamic> settingsConfig,
  ) {
    // Note: apiUrl / socketUrl are intentionally NOT mapped from
    // `server_configuration` here — they are hardcoded in AppConstants, the
    // sole source of truth, and can no longer be overridden by this sync.

    // Note: auth token is intentionally NOT mapped from `api_authentication`
    // here — it now comes exclusively from the Login screen (see
    // AuthLoginApi / LoginScreen), never from this config sync or manual
    // entry in Settings.

    final restaurantCfg = _map(settingsConfig['restaurant_configuration']);
    // restaurantId is intentionally NOT set here — it must only ever come
    // from the restaurant profile API (see RestaurantProfileRepository).
    PrintConfig.empId = _str(restaurantCfg['employee_id'], PrintConfig.empId);

    final restaurantInfo = _map(settingsConfig['restaurant_information']);
    PrintConfig.restaurantName = _str(restaurantInfo['restaurant_name'], PrintConfig.restaurantName);

    final billFooter = _map(settingsConfig['bill_footer']);
    PrintConfig.billFooterText =
        _str(billFooter['footer_text'], PrintConfig.billFooterText);

    final paperSettings = _map(settingsConfig['paper_settings']);
    PrintConfig.is80mm = _paperIs80mm(paperSettings['paper_size'], PrintConfig.is80mm);

    final copies = _map(settingsConfig['print_copies']);
    PrintConfig.billCopies = _int(copies['bill_copy_count'], PrintConfig.billCopies);
    PrintConfig.kotCopies = _int(copies['kot_copy_count'], PrintConfig.kotCopies);

    final autoPrinting = _map(settingsConfig['auto_printing']);
    PrintConfig.autoPrintBill = _yesNo(autoPrinting['auto_print_bill'], PrintConfig.autoPrintBill);
    PrintConfig.autoPrint = _yesNo(autoPrinting['auto_print_kot'], PrintConfig.autoPrint);
    PrintConfig.autoSettle = _yesNo(autoPrinting['auto_settle'], PrintConfig.autoSettle);
    PrintConfig.scanOrderAutoPrint = _yesNo(autoPrinting['scan_order_auto_print'], PrintConfig.scanOrderAutoPrint);
    PrintConfig.aggregatorAutoKot = _yesNo(autoPrinting['aggregator_auto_kot'], PrintConfig.aggregatorAutoKot);
    PrintConfig.aggregatorAutoBill = _yesNo(autoPrinting['aggregator_auto_bill'], PrintConfig.aggregatorAutoBill);
    final stage = _str(autoPrinting['aggregator_auto_bill_stage'], PrintConfig.aggregatorAutoBillStage);
    PrintConfig.aggregatorAutoBillStage =
        (stage == 'Acknowledged' || stage == 'Food Ready') ? stage : PrintConfig.aggregatorAutoBillStage;

    final billDisplay = _map(settingsConfig['bill_display_options']);
    PrintConfig.showItemDateOn80mm = _yesNo(billDisplay['show_item_date_on_80mm'], PrintConfig.showItemDateOn80mm);

    final qr = _map(settingsConfig['qr_codes']);
    PrintConfig.upiQrEnabled = _yesNo(qr['upi_qr_enabled'], PrintConfig.upiQrEnabled);
    PrintConfig.upiId = _str(qr['upi_id'], PrintConfig.upiId);
    PrintConfig.upiDynamicEnabled = _yesNo(qr['upi_dynamic_enabled'], PrintConfig.upiDynamicEnabled);
    PrintConfig.feedbackQrEnabled = _yesNo(qr['feedback_qr_enabled'], PrintConfig.feedbackQrEnabled);
    PrintConfig.feedbackQrUrl = _str(qr['feedback_qr_url'], PrintConfig.feedbackQrUrl);

    final windowsOptions = _map(settingsConfig['windows_options']);
    PrintConfig.usePdfPrintingOnWindows =
        _yesNo(windowsOptions['use_pdf_printing_on_windows'], PrintConfig.usePdfPrintingOnWindows);
    PrintConfig.usePdfForBillsOnly =
        _yesNo(windowsOptions['use_pdf_for_bills_only'], PrintConfig.usePdfForBillsOnly);

    return _mapPrinters(settingsConfig['printers']);
  }

  static List<PrinterConfig> _mapPrinters(dynamic rawPrinters) {
    if (rawPrinters is! List || rawPrinters.isEmpty) return [];

    final result = <PrinterConfig>[];
    for (final raw in rawPrinters) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);

      final stations = <String>{};
      final handled = p['handled_stations'];
      if (handled is List) {
        stations.addAll(handled.map((e) => e.toString().toUpperCase()));
      }

      result.add(PrinterConfig(
        id: _str(p['id'], 'printer_agent_${result.length + 1}'),
        label: _str(p['label'], 'Printer ${result.length + 1}'),
        type: _printerTypeFromApi(p['type'], PrinterType.usb),
        ipAddress: p['lan_ip_address']?.toString(),
        port: _int(p['lan_port'], 9100),
        macAddress: p['bluetooth_mac_address']?.toString(),
        vendorId: p['vendor_id'] == null ? null : _int(p['vendor_id'], 0),
        productId: p['product_id'] == null ? null : _int(p['product_id'], 0),
        paperSize: _paperSizeFromApi(p['paper_size'], PaperSize.mm80),
        windowsPrinterName: p['usb_printer_name']?.toString(),
        handledStations: stations,
        handlesBill: p['handles_bill'] == true,
      ));
    }
    return result;
  }

  // ── style_config → PrintStyleConfig ───────────────────────────────────────

  /// Builds a new [PrintStyleConfig] from `style_config`, falling back to
  /// [PrintStyleConfig.defaults] for anything missing or unparseable.
  static PrintStyleConfig mapStyleConfig(Map<String, dynamic> styleConfig) {
    final def = PrintStyleConfig.defaults();

    final global = _map(styleConfig['global_settings']);
    final globalWindows = _map(global['windows']);
    final globalAndroid = _map(global['android']);
    final pageMargins = _map(globalWindows['page_margins_mm']);
    final logoSizeWin = _map(globalWindows['logo_size_mm']);
    final qrSizeWin = _map(globalWindows['qr_size_mm']);

    final billStyle = _map(styleConfig['bill_print_style']);
    final restaurantHeader = _map(billStyle['restaurant_header']);
    final billInfo = _map(billStyle['bill_information']);
    final billItemTable = _map(billStyle['item_table']);
    final amountSection = _map(billStyle['amount_section']);
    final deliverySection = _map(billStyle['delivery_section']);
    final roomSection = _map(billStyle['room_section']);
    final footerSection = _map(billStyle['footer']);

    final kotStyle = _map(styleConfig['kot_print_style']);
    final kotHeader = _map(kotStyle['kot_header']);
    final kotInfo = _map(kotStyle['kot_information']);
    final kotItemTable = _map(kotStyle['item_table']);
    final kotNotesSection = _map(kotStyle['notes']);

    return PrintStyleConfig(
      restaurantName: _item(restaurantHeader, 'restaurant_name', def.restaurantName),
      restaurantAddress: _item(restaurantHeader, 'restaurant_address', def.restaurantAddress),
      restaurantPhone: _item(restaurantHeader, 'restaurant_phone', def.restaurantPhone),
      restaurantGst: _item(restaurantHeader, 'gst_number', def.restaurantGst),
      restaurantFssai: _item(restaurantHeader, 'fssai_number', def.restaurantFssai),
      billInfoRow1: _item(billInfo, 'row_1', def.billInfoRow1),
      billInfoRow2: _item(billInfo, 'row_2', def.billInfoRow2),
      billInfoRow3: _item(billInfo, 'row_3', def.billInfoRow3),
      billInfoRow4: _item(billInfo, 'row_4', def.billInfoRow4),
      billTableHeader: _item(billItemTable, 'table_header', def.billTableHeader),
      billTableContent: _item(billItemTable, 'table_content', def.billTableContent),
      billTableQty: _item(billItemTable, 'table_qty', def.billTableQty),
      billTableMeta: _item(billItemTable, 'table_meta', def.billTableMeta),
      orderNote: _item(billItemTable, 'notes', def.orderNote),
      billAmountLine: _item(amountSection, 'amount_breakdown', def.billAmountLine),
      billTotal: _item(amountSection, 'total', def.billTotal),
      billGrandTotal: _item(amountSection, 'grand_total', def.billGrandTotal),
      billPaidBy: _item(amountSection, 'paid_by', def.billPaidBy),
      deliveryHeader: _item(deliverySection, 'delivery_header', def.deliveryHeader),
      deliveryContent: _item(deliverySection, 'delivery_content', def.deliveryContent),
      roomHeader: _item(roomSection, 'room_header', def.roomHeader),
      roomContent: _item(roomSection, 'room_content', def.roomContent),
      footer: _item(footerSection, 'footer_text', def.footer),
      kotTitle: _item(kotHeader, 'kot_title', def.kotTitle),
      cancelKotTitle: _item(kotHeader, 'cancel_kot_title', def.cancelKotTitle),
      kotOrderInfo1: _item(kotInfo, 'row_1', def.kotOrderInfo1),
      kotOrderInfo2: _item(kotInfo, 'row_2', def.kotOrderInfo2),
      kotOrderInfo3: _item(kotInfo, 'row_3', def.kotOrderInfo3),
      kotOrderInfo4: _item(kotInfo, 'row_4', def.kotOrderInfo4),
      kotTableHeader: _item(kotItemTable, 'table_header', def.kotTableHeader),
      kotTableContent: _item(kotItemTable, 'table_content', def.kotTableContent),
      kotNote: _item(kotNotesSection, 'notes', def.kotNote),
      fontFamily: _str(global['font_family'], def.fontFamily),
      dividerStyle: _str(global['divider_line_style'], def.dividerStyle),
      marginTopMm: _double(pageMargins['top'], def.marginTopMm),
      marginBottomMm: _double(pageMargins['bottom'], def.marginBottomMm),
      marginLeftMm: _double(pageMargins['left'], def.marginLeftMm),
      marginRightMm: _double(pageMargins['right'], def.marginRightMm),
      logoWidthMm: _double(logoSizeWin['width'], def.logoWidthMm),
      logoHeightMm: _double(logoSizeWin['height'], def.logoHeightMm),
      upiQrSizeMm: _double(qrSizeWin['upi'], def.upiQrSizeMm),
      feedbackQrSizeMm: _double(qrSizeWin['feedback'], def.feedbackQrSizeMm),
      escLogoSizeMm: _double(globalAndroid['logo_size_mm'], def.escLogoSizeMm),
      escUpiQrSizeMm: _double(globalAndroid['upi_qr_size_mm'], def.escUpiQrSizeMm),
      escFeedbackQrSizeMm: _double(globalAndroid['feedback_qr_size_mm'], def.escFeedbackQrSizeMm),
    );
  }

  static PrintStyleItem _item(
    Map<String, dynamic> section,
    String key,
    PrintStyleItem fallback,
  ) {
    final entry = _map(section[key]);
    final windows = _map(entry['windows']);
    final android = _map(entry['android']);
    return PrintStyleItem(
      size58: _double(windows['font_size_58mm'], fallback.size58),
      size80: _double(windows['font_size_80mm'], fallback.size80),
      isBold: _yesNo(windows['bold'], fallback.isBold),
      escSize58: _int(android['font_size_58mm'], fallback.escSize58).clamp(1, 8),
      escSize80: _int(android['font_size_80mm'], fallback.escSize80).clamp(1, 8),
      escBold: _yesNo(android['bold'], fallback.escBold),
    );
  }

  // ── Shared parsing helpers ─────────────────────────────────────────────────

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static bool _yesNo(dynamic value, bool fallback) {
    if (value is bool) return value;
    final s = value?.toString().trim().toLowerCase();
    if (s == 'yes') return true;
    if (s == 'no') return false;
    return fallback;
  }

  static String _str(dynamic value, String fallback, {bool protectEmpty = false}) {
    if (value == null) return fallback;
    final s = value.toString();
    if (protectEmpty && s.trim().isEmpty) return fallback;
    return s;
  }

  static int _int(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static double _double(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static bool _paperIs80mm(dynamic value, bool fallback) {
    final s = value?.toString().toLowerCase() ?? '';
    if (s.contains('80')) return true;
    if (s.contains('58')) return false;
    return fallback;
  }

  static PaperSize _paperSizeFromApi(dynamic value, PaperSize fallback) {
    final s = value?.toString().toLowerCase() ?? '';
    if (s.contains('80')) return PaperSize.mm80;
    if (s.contains('58')) return PaperSize.mm58;
    return fallback;
  }

  static PrinterType _printerTypeFromApi(dynamic value, PrinterType fallback) {
    final s = value?.toString().trim().toLowerCase() ?? '';
    if (s.contains('usb')) return PrinterType.usb;
    if (s.contains('lan')) return PrinterType.lan;
    if (s.contains('bluetooth')) return PrinterType.bluetooth;
    return fallback;
  }
}
