// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// enum PrinterConnectionType { usb, lan }

// class PrintConfig {
//   static bool autoPrint = true;
//   static int kotCopies = 1;
//   static int billCopies = 1;
//   static bool autoPrintBill = true;
//   static int restaurantId = 618;
//   static String restaurantName = "HOGWARTS";
//   static String printerName = "POS58 Printer";
//   static PaperSize paperSize = PaperSize.mm58;
//   static int usbVendorId = 19267;
//   static int usbProductId = 14384;
//   static String empId = "002";
//   static String apiUrl = 'https://preprod.mygenie.online';
//   static String serverUrl = 'http://presocket.mygenie.online';
//   static String authToken =
//       'FLwtm4SQ2nVv8erxdlIUhTdNEzPoAhUBsZBE0UJwScW3rzFOVRx37ne6F2avDVTwbqYSHljFLsENdTvpNyd2YDIRieCPcjAGkXKkNkb1MK8TKtwANrq2Z0aZ';

//   // ✅ NEW — multi-station set (replaces single station string)
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

//     final mmStr = p.getString('paperSize') ?? '58';
//     paperSize = mmStr == '80' ? PaperSize.mm80 : PaperSize.mm58;

//     // ✅ Load stations — stored as comma string e.g. 'KDS,BAR,PIZZA'
//     final stationsStr = p.getString('stations') ?? 'KDS';
//     stations = stationsStr
//         .split(',')
//         .map((s) => s.trim().toUpperCase())
//         .where((s) => s.isNotEmpty)
//         .toSet();
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
//     await p.setString('paperSize', paperSize == PaperSize.mm80 ? '80' : '58');
//     await p.setInt('usbVendorId', usbVendorId);
//     await p.setInt('usbProductId', usbProductId);

//     // ✅ Save stations as comma string
//     await p.setString('stations', stations.join(','));
//   }

//   static bool get isConfigured =>
//       serverUrl.isNotEmpty && authToken.isNotEmpty && printerName.isNotEmpty;
// }


import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterConnectionType { usb, lan }

class PrintConfig {
  static bool autoPrint = true;
  static int kotCopies = 1;
  static int billCopies = 1;
  static bool autoPrintBill = true;
  static int restaurantId = 618;
  static String restaurantName = "HOGWARTS";
  static String printerName = "POS58 Printer";
  static PaperSize paperSize = PaperSize.mm58;
  static int usbVendorId = 19267;
  static int usbProductId = 14384;
  static String empId = "002";
  static String apiUrl = 'https://preprod.mygenie.online';
  static String serverUrl = 'http://presocket.mygenie.online';
  static String authToken =
      'FLwtm4SQ2nVv8erxdlIUhTdNEzPoAhUBsZBE0UJwScW3rzFOVRx37ne6F2avDVTwbqYSHljFLsENdTvpNyd2YDIRieCPcjAGkXKkNkb1MK8TKtwANrq2Z0aZ';

  // ✅ NEW — LAN fields
  static PrinterConnectionType connectionType = PrinterConnectionType.usb;
  static String lanIp   = '';
  static int    lanPort = 9100;

  static Set<String> stations = {'KDS'};

  // ── Helpers ───────────────────────────────────────────
  static bool get hasNoStations => stations.isEmpty;

  static bool matchesStation(String socketStation) => stations
      .any((s) => s.trim().toUpperCase() == socketStation.trim().toUpperCase());

  // ── Load ──────────────────────────────────────────────
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    autoPrint     = p.getBool('autoPrint') ?? true;
    autoPrintBill = p.getBool('autoPrintBill') ?? true;
    kotCopies     = p.getInt('kotCopies') ?? 1;
    billCopies    = p.getInt('billCopies') ?? 1;
    restaurantId  = p.getInt('restaurantId') ?? 618;
    empId         = p.getString('empId') ?? '002';
    apiUrl        = p.getString('apiUrl') ?? 'https://preprod.mygenie.online';
    serverUrl     = p.getString('serverUrl') ?? 'http://presocket.mygenie.online';
    authToken     = p.getString('authToken') ?? '';
    printerName   = p.getString('printerName') ?? 'Everycom-printer';
    restaurantName= p.getString('restaurantName') ?? 'Restaurant';
    usbVendorId   = p.getInt('usbVendorId') ?? 0;
    usbProductId  = p.getInt('usbProductId') ?? 0;

    final mmStr = p.getString('paperSize') ?? '58';
    paperSize = mmStr == '80' ? PaperSize.mm80 : PaperSize.mm58;

    final stationsStr = p.getString('stations') ?? 'KDS';
    stations = stationsStr
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toSet();

    // ✅ NEW — Load LAN
    connectionType = PrinterConnectionType.values.byName(
      p.getString('connectionType') ?? 'usb',
    );
    lanIp   = p.getString('lanIp') ?? '';
    lanPort = p.getInt('lanPort') ?? 9100;
  }

  // ── Save ──────────────────────────────────────────────
  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('autoPrint', autoPrint);
    await p.setBool('autoPrintBill', autoPrintBill);
    await p.setInt('kotCopies', kotCopies);
    await p.setInt('billCopies', billCopies);
    await p.setInt('restaurantId', restaurantId);
    await p.setString('empId', empId);
    await p.setString('apiUrl', apiUrl);
    await p.setString('serverUrl', serverUrl);
    await p.setString('authToken', authToken);
    await p.setString('printerName', printerName);
    await p.setString('restaurantName', restaurantName);
    await p.setString('paperSize', paperSize == PaperSize.mm80 ? '80' : '58');
    await p.setInt('usbVendorId', usbVendorId);
    await p.setInt('usbProductId', usbProductId);
    await p.setString('stations', stations.join(','));

    // ✅ NEW — Save LAN
    await p.setString('connectionType', connectionType.name);
    await p.setString('lanIp', lanIp);
    await p.setInt('lanPort', lanPort);
  }

  static bool get isConfigured =>
      serverUrl.isNotEmpty && authToken.isNotEmpty && printerName.isNotEmpty;
}