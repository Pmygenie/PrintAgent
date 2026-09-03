// // import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// // import 'package:shared_preferences/shared_preferences.dart';

// // enum PrinterConnectionType { usb, lan }

// // class PrintConfig {
// //   static bool autoPrint = true;
// //   static int kotCopies = 1;
// //   static int billCopies = 1;
// //   static bool autoPrintBill = true;
// //   static int restaurantId = 618;
// //   static String restaurantName = "HOGWARTS";
// //   static String printerName = "POS58 Printer";
// //   static PaperSize paperSize = PaperSize.mm58;
// //   static int usbVendorId = 19267;
// //   static int usbProductId = 14384;
// //   static String empId = "002";
// //   static String apiUrl = 'https://preprod.mygenie.online';
// //   static String serverUrl = 'http://presocket.mygenie.online';
// //   static String authToken =
// //       'FLwtm4SQ2nVv8erxdlIUhTdNEzPoAhUBsZBE0UJwScW3rzFOVRx37ne6F2avDVTwbqYSHljFLsENdTvpNyd2YDIRieCPcjAGkXKkNkb1MK8TKtwANrq2Z0aZ';

// //   // ✅ NEW — multi-station set (replaces single station string)
// //   static Set<String> stations = {'KDS'};

// //   // ── Helpers ───────────────────────────────────────────
// //   static bool get hasNoStations => stations.isEmpty;

// //   static bool matchesStation(String socketStation) => stations
// //       .any((s) => s.trim().toUpperCase() == socketStation.trim().toUpperCase());

// //   // ── Load ──────────────────────────────────────────────
// //   static Future<void> load() async {
// //     final p = await SharedPreferences.getInstance();
// //     autoPrint = p.getBool('autoPrint') ?? true;
// //     autoPrintBill = p.getBool('autoPrintBill') ?? true;
// //     kotCopies = p.getInt('kotCopies') ?? 1;
// //     billCopies = p.getInt('billCopies') ?? 1;
// //     restaurantId = p.getInt('restaurantId') ?? 618;
// //     empId = p.getString('empId') ?? '002';
// //     apiUrl = p.getString('apiUrl') ?? 'https://preprod.mygenie.online';
// //     serverUrl = p.getString('serverUrl') ?? 'http://presocket.mygenie.online';
// //     authToken = p.getString('authToken') ?? '';
// //     printerName = p.getString('printerName') ?? 'Everycom-printer';
// //     restaurantName = p.getString('restaurantName') ?? 'Restaurant';
// //     usbVendorId = p.getInt('usbVendorId') ?? 0;
// //     usbProductId = p.getInt('usbProductId') ?? 0;

// //     final mmStr = p.getString('paperSize') ?? '58';
// //     paperSize = mmStr == '80' ? PaperSize.mm80 : PaperSize.mm58;

// //     // ✅ Load stations — stored as comma string e.g. 'KDS,BAR,PIZZA'
// //     final stationsStr = p.getString('stations') ?? 'KDS';
// //     stations = stationsStr
// //         .split(',')
// //         .map((s) => s.trim().toUpperCase())
// //         .where((s) => s.isNotEmpty)
// //         .toSet();
// //   }

// //   // ── Save ──────────────────────────────────────────────
// //   static Future<void> save() async {
// //     final p = await SharedPreferences.getInstance();
// //     await p.setBool('autoPrint', autoPrint);
// //     await p.setBool('autoPrintBill', autoPrintBill);
// //     await p.setInt('kotCopies', kotCopies);
// //     await p.setInt('billCopies', billCopies);
// //     await p.setInt('restaurantId', restaurantId);
// //     await p.setString('empId', empId);
// //     await p.setString('apiUrl', apiUrl);
// //     await p.setString('serverUrl', serverUrl);
// //     await p.setString('authToken', authToken);
// //     await p.setString('printerName', printerName);
// //     await p.setString('restaurantName', restaurantName);
// //     await p.setString('paperSize', paperSize == PaperSize.mm80 ? '80' : '58');
// //     await p.setInt('usbVendorId', usbVendorId);
// //     await p.setInt('usbProductId', usbProductId);

// //     // ✅ Save stations as comma string
// //     await p.setString('stations', stations.join(','));
// //   }

// //   static bool get isConfigured =>
// //       serverUrl.isNotEmpty && authToken.isNotEmpty && printerName.isNotEmpty;
// // }

// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// enum PrinterConnectionType { usb, lan }

// class PrintConfig {
//   static bool autoPrint = true;
//   static int kotCopies = 1;
//   static int billCopies = 1;
//   static bool autoPrintBill = true;
//   static bool usePdfPrintingOnWindows = true;
//   static bool usePdfForBillsOnly = false;
//   static int restaurantId = 618;
//   static String restaurantName = "HOGWARTS";
//   static String printerName = "POS58 Printer";
//   static bool is80mm = false;
//   static int usbVendorId = 19267;
//   static int usbProductId = 14384;
//   static String empId = "002";
//   static String apiUrl = 'https://preprod.mygenie.online';
//   static String serverUrl = 'http://presocket.mygenie.online';
//   static String authToken =
//       'FLwtm4SQ2nVv8erxdlIUhTdNEzPoAhUBsZBE0UJwScW3rzFOVRx37ne6F2avDVTwbqYSHljFLsENdTvpNyd2YDIRieCPcjAGkXKkNkb1MK8TKtwANrq2Z0aZ';

//   // ✅ NEW — LAN fields
//   static PrinterConnectionType connectionType = PrinterConnectionType.usb;
//   static String lanIp = '';
//   static int lanPort = 9100;

//   static Set<String> stations = {'KDS'};

//   // ── Helpers ───────────────────────────────────────────
//   static bool get hasNoStations => stations.isEmpty;

//   static bool matchesStation(String socketStation) => stations
//       .any((s) => s.trim().toUpperCase() == socketStation.trim().toUpperCase());

//   // ── Load ──────────────────────────────────────────────
//   static Future<void> load() async {
//     final p = await SharedPreferences.getInstance();
//     autoPrint = p.getBool('autoPrint') ?? true;
//     autoPrintBill = p.getBool('autoPrintBill') ?? true;
//     kotCopies = p.getInt('kotCopies') ?? 1;
//     billCopies = p.getInt('billCopies') ?? 1;
//     restaurantId = p.getInt('restaurantId') ?? 618;
//     empId = p.getString('empId') ?? '002';
//     apiUrl = p.getString('apiUrl') ?? 'https://preprod.mygenie.online';
//     serverUrl = p.getString('serverUrl') ?? 'http://presocket.mygenie.online';
//     authToken = p.getString('authToken') ?? '';
//     printerName = p.getString('printerName') ?? 'Everycom-printer';
//     restaurantName = p.getString('restaurantName') ?? 'Restaurant';
//     usbVendorId = p.getInt('usbVendorId') ?? 0;
//     usbProductId = p.getInt('usbProductId') ?? 0;
//     usePdfPrintingOnWindows = p.getBool('usePdfPrintingOnWindows') ?? false;
//     usePdfForBillsOnly = p.getBool('usePdfForBillsOnly') ?? false;
//     is80mm = p.getBool('is80mm') ?? false;

//     final stationsStr = p.getString('stations') ?? 'KDS';
//     stations = stationsStr
//         .split(',')
//         .map((s) => s.trim().toUpperCase())
//         .where((s) => s.isNotEmpty)
//         .toSet();

//     // ✅ NEW — Load LAN
//     connectionType = PrinterConnectionType.values.byName(
//       p.getString('connectionType') ?? 'usb',
//     );
//     lanIp = p.getString('lanIp') ?? '';
//     lanPort = p.getInt('lanPort') ?? 9100;
//   }

//   // ── Save ──────────────────────────────────────────────
//   static Future<void> save() async {
//     final p = await SharedPreferences.getInstance();
//     await p.setBool('autoPrint', autoPrint);
//     await p.setBool('autoPrintBill', autoPrintBill);
//     await p.setInt('kotCopies', kotCopies);
//     await p.setInt('billCopies', billCopies);
//     await p.setInt('restaurantId', restaurantId);
//     await p.setString('empId', empId);
//     await p.setString('apiUrl', apiUrl);
//     await p.setString('serverUrl', serverUrl);
//     await p.setString('authToken', authToken);
//     await p.setString('printerName', printerName);
//     await p.setString('restaurantName', restaurantName);
//     await p.setBool('is80mm', is80mm);
//     await p.setInt('usbVendorId', usbVendorId);
//     await p.setInt('usbProductId', usbProductId);
//     await p.setString('stations', stations.join(','));
//     await p.setBool('usePdfPrintingOnWindows', usePdfPrintingOnWindows);
//     await p.setBool('usePdfForBillsOnly', usePdfForBillsOnly);

//     // ✅ NEW — Save LAN
//     await p.setString('connectionType', connectionType.name);
//     await p.setString('lanIp', lanIp);
//     await p.setInt('lanPort', lanPort);
//   }

//   static bool get isConfigured =>
//       serverUrl.isNotEmpty && authToken.isNotEmpty && printerName.isNotEmpty;
// }

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ UPDATED — Added bluetooth
enum PrinterConnectionType { usb, lan, bluetooth }

/// Agent paper size. 58/80mm are thermal receipts; A4 is a full-page bill PDF.
enum AgentPaperSize { mm58, mm80, a4 }

class PrintConfig {
  static bool autoPrint = true;
  static int kotCopies = 1;
  static int billCopies = 1;
  static bool autoPrintBill = true;
  static bool autoSettle = false;
  static bool aggregatorAutoKot = false;
  static bool aggregatorAutoBill = false;
  static String aggregatorAutoBillStage = 'Acknowledged';
  static bool scanOrderAutoPrint = false;
  static bool usePdfPrintingOnWindows = true;
  static bool usePdfForBillsOnly = false;
  static bool showItemDateOn80mm = false;
  static int restaurantId = 1;
  static String restaurantName = "MyGenie";
  static String printerName = "POS58 Printer";
  static AgentPaperSize paperSize = AgentPaperSize.mm58;
  static int usbVendorId = 19267;
  static int usbProductId = 14384;
  static String empId = "002";
  // apiUrl / serverUrl removed — see AppConstants, the sole source of truth.
  static String authToken = '';

  // ✅ UPDATED — Network and Bluetooth fields
  static PrinterConnectionType connectionType = PrinterConnectionType.usb;
  static String lanIp = '';
  static int lanPort = 9100;
  static String macAddress = '';

  static Set<String> stations = {'KDS'};

  // ✅ NEW — QR code config (bill only, never on aggregator/KOT)
  static bool feedbackQrEnabled = false;
  static String feedbackQrUrl = '';
  static bool upiQrEnabled = false;
  static bool upiDynamicEnabled = false;
  static String upiId = '';

  /// Bill/KOT bottom line from printer-agent-config `bill_footer.footer_text`.
  static String billFooterText = 'Powered by MyGenie';

  /// Resolved footer line — API text, or default if blank.
  static String get poweredByFooter {
    final t = billFooterText.trim();
    return t.isNotEmpty ? t : 'Powered by MyGenie';
  }

  // ── Helpers ───────────────────────────────────────────
  static bool get hasNoStations => stations.isEmpty;

  static bool get isA4 => paperSize == AgentPaperSize.a4;

  /// Thermal width flag used by ESC/POS, bitmap, and 58/80 PDF.
  /// A4 bills use a separate layout; KOTs still print as 80mm when A4 is selected.
  static bool get is80mm => paperSize != AgentPaperSize.mm58;

  static String _paperSizeToPref(AgentPaperSize size) {
    switch (size) {
      case AgentPaperSize.a4:
        return 'a4';
      case AgentPaperSize.mm80:
        return '80';
      case AgentPaperSize.mm58:
        return '58';
    }
  }

  static AgentPaperSize _paperSizeFromPref(SharedPreferences p) {
    final stored = p.getString('paperSize');
    if (stored != null) {
      switch (stored) {
        case 'a4':
          return AgentPaperSize.a4;
        case '80':
          return AgentPaperSize.mm80;
        case '58':
          return AgentPaperSize.mm58;
      }
    }
    return (p.getBool('is80mm') ?? false)
        ? AgentPaperSize.mm80
        : AgentPaperSize.mm58;
  }

  /// Feedback QR payload — uses configured URL, else falls back to the
  /// standard MyGenie feedback link with the numeric order id.
  static String feedbackQrData(int orderId) {
    return feedbackQrUrl.trim().isNotEmpty
        ? feedbackQrUrl.trim()
        : 'https://order.mygenie.online/feedback?orderId=$orderId';
  }

  /// UPI payment QR payload — static (`am=0`) or dynamic (bill total in `am`).
  static String upiQrDataForBill(Map<String, dynamic> bill) {
    double d(String key) =>
        double.tryParse(bill[key]?.toString() ?? '0') ?? 0.0;

    final grantAmount = d('grant_amount');
    final paymentAmount = d('payment_amount');
    final associatedOrders = bill['associated_orders'] as List<dynamic>?;
    final isRoomOrder = associatedOrders != null && associatedOrders.isNotEmpty;
    // final totalAmount = isRoomOrder ? paymentAmount : grantAmount;
    final totalAmount = grantAmount;

    final amount = upiDynamicEnabled ? totalAmount.toStringAsFixed(2) : '0';
    return 'upi://pay?pa=$upiId&pn=&am=$amount&tn=';
  }

  static bool matchesStation(String socketStation) => stations
      .any((s) => s.trim().toUpperCase() == socketStation.trim().toUpperCase());

  // ── Load ──────────────────────────────────────────────
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    autoPrint = p.getBool('autoPrint') ?? true;
    autoPrintBill = p.getBool('autoPrintBill') ?? true;
    autoSettle = p.getBool('autoSettle') ?? false;
    aggregatorAutoKot = p.getBool('aggregatorAutoKot') ?? false;
    aggregatorAutoBill = p.getBool('aggregatorAutoBill') ?? false;
    aggregatorAutoBillStage =
        p.getString('aggregatorAutoBillStage') ?? 'Acknowledged';
    if (aggregatorAutoBillStage != 'Acknowledged' &&
        aggregatorAutoBillStage != 'Food Ready') {
      aggregatorAutoBillStage = 'Acknowledged';
    }
    scanOrderAutoPrint = p.getBool('scanOrderAutoPrint') ?? false;
    kotCopies = p.getInt('kotCopies') ?? 1;
    billCopies = p.getInt('billCopies') ?? 1;
    restaurantId = p.getInt('restaurantId') ?? 618;
    empId = p.getString('empId') ?? '002';
    authToken = p.getString('authToken') ?? '';
    printerName = p.getString('printerName') ?? 'Everycom-printer';
    restaurantName = p.getString('restaurantName') ?? 'Restaurant';
    usbVendorId = p.getInt('usbVendorId') ?? 0;
    usbProductId = p.getInt('usbProductId') ?? 0;
    usePdfPrintingOnWindows = p.getBool('usePdfPrintingOnWindows') ?? false;
    usePdfForBillsOnly = p.getBool('usePdfForBillsOnly') ?? false;
    showItemDateOn80mm = p.getBool('showItemDateOn80mm') ?? false;
    paperSize = _paperSizeFromPref(p);

    final stationsStr = p.getString('stations') ?? 'KDS';
    stations = stationsStr
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toSet();

    // ✅ UPDATED — Load LAN and Bluetooth configs
    final typeStr = p.getString('connectionType') ?? 'usb';

    // Safely parse the enum, defaulting to USB if the string doesn't match
    connectionType = PrinterConnectionType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => PrinterConnectionType.usb,
    );

    lanIp = p.getString('lanIp') ?? '';
    lanPort = p.getInt('lanPort') ?? 9100;
    macAddress = p.getString('macAddress') ?? '';

    // ✅ NEW — Load QR code config
    feedbackQrEnabled = p.getBool('feedbackQrEnabled') ?? false;
    feedbackQrUrl = p.getString('feedbackQrUrl') ?? '';
    upiQrEnabled = p.getBool('upiQrEnabled') ?? false;
    upiDynamicEnabled = p.getBool('upiDynamicEnabled') ?? false;
    upiId = p.getString('upiId') ?? '';
    billFooterText = p.getString('billFooterText') ?? 'Powered by MyGenie';
  }

  // ── Save ──────────────────────────────────────────────
  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('autoPrint', autoPrint);
    await p.setBool('autoPrintBill', autoPrintBill);
    await p.setBool('autoSettle', autoSettle);
    await p.setBool('aggregatorAutoKot', aggregatorAutoKot);
    await p.setBool('aggregatorAutoBill', aggregatorAutoBill);
    await p.setString('aggregatorAutoBillStage', aggregatorAutoBillStage);
    await p.setBool('scanOrderAutoPrint', scanOrderAutoPrint);
    await p.setInt('kotCopies', kotCopies);
    await p.setInt('billCopies', billCopies);
    await p.setInt('restaurantId', restaurantId);
    await p.setString('empId', empId);
    await p.setString('authToken', authToken);
    await p.setString('printerName', printerName);
    await p.setString('restaurantName', restaurantName);
    await p.setString('paperSize', _paperSizeToPref(paperSize));
    await p.setBool('is80mm', paperSize != AgentPaperSize.mm58);
    await p.setInt('usbVendorId', usbVendorId);
    await p.setInt('usbProductId', usbProductId);
    await p.setString('stations', stations.join(','));
    await p.setBool('usePdfPrintingOnWindows', usePdfPrintingOnWindows);
    await p.setBool('usePdfForBillsOnly', usePdfForBillsOnly);
    await p.setBool('showItemDateOn80mm', showItemDateOn80mm);

    // ✅ UPDATED — Save LAN and Bluetooth configs
    await p.setString('connectionType', connectionType.name);
    await p.setString('lanIp', lanIp);
    await p.setInt('lanPort', lanPort);
    await p.setString('macAddress', macAddress);

    // ✅ NEW — Save QR code config
    await p.setBool('feedbackQrEnabled', feedbackQrEnabled);
    await p.setString('feedbackQrUrl', feedbackQrUrl);
    await p.setBool('upiQrEnabled', upiQrEnabled);
    await p.setBool('upiDynamicEnabled', upiDynamicEnabled);
    await p.setString('upiId', upiId);
    await p.setString('billFooterText', billFooterText);
  }

  static bool get isConfigured =>
      authToken.isNotEmpty && printerName.isNotEmpty;
}
