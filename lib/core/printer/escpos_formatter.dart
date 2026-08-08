// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import '../models/print_job.dart';
// import '../models/restaurant_order.dart';
// import '../config/print_config.dart'; // ✅ import PrintConfig

// class EscPosFormatter {
//   static Future<List<int>> format(PrintJob job) async {
//     final profile   = await CapabilityProfile.load();
//     // ✅ Use paperSize from PrintConfig — not hardcoded mm58
//     final generator = Generator(PrintConfig.paperSize, profile);
//     List<int> bytes = [];

//     if (job.type == PrintType.kot) {
//       bytes += _buildKot(generator, job.order, job.stationLabel);
//     } else {
//       bytes += _buildBill(generator, job.order);
//     }

//     bytes += generator.cut();
//     return bytes;
//   }

//   // ✅ Dynamic width — 32 for 58mm, 48 for 80mm
//   static int get _width => PrintConfig.paperSize == PaperSize.mm80 ? 48 : 32;

//   // ✅ Dynamic truncate limits
//   static int get _itemNameBillWidth  => _width == 48 ? 28 : 18;
//   static int get _itemNameKotWidth   => _width == 48 ? 30 : 20;

//   // ── BILL ──────────────────────────────────────────────
//   static List<int> _buildBill(Generator g, RestaurantOrder o) {
//     List<int> b = [];

//     b += g.hr(ch: '=');
//     b += g.text(
//       o.restaurantName.toUpperCase(),
//       styles: const PosStyles(bold: true, align: PosAlign.center),
//     );
//     b += g.hr(ch: '=');

//     b += g.row([
//       PosColumn(text: '#${o.displayOrderId}', width: 6,
//           styles: const PosStyles(bold: true)),
//       PosColumn(text: o.tableDisplay, width: 6,
//           styles: const PosStyles(align: PosAlign.right)),
//     ]);
//     b += g.text(_formatDate(o.receivedAt));
//     b += g.hr(ch: '-');

//     b += g.row([
//       PosColumn(text: 'ITEM', width: 8, styles: const PosStyles(bold: true)),
//       PosColumn(text: 'QTY', width: 2,
//           styles: const PosStyles(bold: true, align: PosAlign.center)),
//       PosColumn(text: 'AMT', width: 2,
//           styles: const PosStyles(bold: true, align: PosAlign.right)),
//     ]);
//     b += g.hr(ch: '-');

//     double total = 0;
//     for (final item in o.items) {
//       final amt = item.price * item.quantity;
//       total    += amt;

//       b += g.row([
//         PosColumn(text: _truncate(item.name, _itemNameBillWidth), width: 8),
//         PosColumn(text: '${item.quantity}', width: 2,
//             styles: const PosStyles(align: PosAlign.center)),
//         PosColumn(text: amt.toStringAsFixed(0), width: 2,
//             styles: const PosStyles(align: PosAlign.right)),
//       ]);

//       if (item.note.isNotEmpty) {
//         b += g.text('  > ${item.note}',
//             styles: const PosStyles(underline: true));
//       }
//     }

//     b += g.hr(ch: '=');
//     b += g.row([
//       PosColumn(text: 'TOTAL', width: 6,
//           styles: const PosStyles(bold: true,
//               height: PosTextSize.size2, width: PosTextSize.size2)),
//       PosColumn(text: 'Rs.${total.toStringAsFixed(0)}', width: 6,
//           styles: const PosStyles(bold: true, align: PosAlign.right,
//               height: PosTextSize.size2, width: PosTextSize.size2)),
//     ]);
//     b += g.hr(ch: '=');

//     b += g.text('Thank you! Visit Again',
//         styles: const PosStyles(align: PosAlign.center));

//     return b;
//   }

//   // ── KOT ───────────────────────────────────────────────
//   static List<int> _buildKot(Generator g, RestaurantOrder o, String? stationLabel) {
//     List<int> b = [];

//     b += g.hr(ch: '=');
//     b += g.text(
//       'KOT',
//       styles: const PosStyles(
//         bold: true, align: PosAlign.center,
//         height: PosTextSize.size2, width: PosTextSize.size2,
//       ),
//     );

//     if (stationLabel != null && stationLabel.isNotEmpty) {
//       b += g.hr(ch: '-');
//       b += g.text(
//         '[ $stationLabel ]',
//         styles: const PosStyles(
//           bold:   true,
//           align:  PosAlign.center,
//           height: PosTextSize.size2,
//           width:  PosTextSize.size2,
//         ),
//       );
//     }

//     b += g.hr(ch: '=');

//     b += g.row([
//       PosColumn(text: '#${o.displayOrderId}', width: 6,
//           styles: const PosStyles(bold: true)),
//       // ✅ tableDisplay fits on one line now — no wrapping
//       PosColumn(text: _truncate(o.tableDisplay, _width == 48 ? 22 : 14), width: 6,
//           styles: const PosStyles(align: PosAlign.right)),
//     ]);
//     b += g.row([
//       PosColumn(text: 'Waiter: ${o.waiterName}', width: 8),
//       PosColumn(text: _formatTime(o.receivedAt), width: 4,
//           styles: const PosStyles(align: PosAlign.right)),
//     ]);
//     b += g.hr(ch: '-');

//     for (final item in o.items) {
//       b += g.row([
//         PosColumn(
//           text:   '${item.quantity}x ${_truncate(item.name, _itemNameKotWidth)}',
//           width:  10,
//           styles: const PosStyles(bold: true),
//         ),
//         PosColumn(
//           text:   'Rs.${item.price.toStringAsFixed(0)}',
//           width:  2,
//           styles: const PosStyles(align: PosAlign.right),
//         ),
//       ]);
//       if (item.note.isNotEmpty) {
//         b += g.text('  > ${item.note}',
//             styles: const PosStyles(underline: true));
//       }
//     }

//     b += g.hr(ch: '=');
//     return b;
//   }

//   // ── Helpers ───────────────────────────────────────────
//   static String _truncate(String text, int maxLen) {
//     if (text.length <= maxLen) return text;
//     return '${text.substring(0, maxLen - 2)}..';
//   }

//   static String _formatDate(DateTime dt) =>
//       '${dt.day.toString().padLeft(2, '0')}/'
//       '${dt.month.toString().padLeft(2, '0')}/'
//       '${dt.year} '
//       '${dt.hour.toString().padLeft(2, '0')}:'
//       '${dt.minute.toString().padLeft(2, '0')}';

//   static String _formatTime(DateTime dt) =>
//       '${dt.hour.toString().padLeft(2, '0')}:'
//       '${dt.minute.toString().padLeft(2, '0')}';
// }

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:printer_agent/core/profile/restaurant_profile_model.dart';
import 'package:printer_agent/core/profile/restaurant_profile_service.dart';
import 'package:printer_agent/core/services/print_style_service.dart';
import '../models/print_job.dart';
import '../models/order_item.dart';
import '../models/print_style_config.dart';
import '../models/restaurant_order.dart';
import '../config/print_config.dart';

class EscPosFormatter {
  static late PrintStyleConfig _style;

  static Future<List<int>> format(PrintJob job) async {
    _style = await PrintStyleService.getConfig();
    final profile = await CapabilityProfile.load();
    final currentPaperSize =
        PrintConfig.is80mm ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(currentPaperSize, profile);

    List<int> bytes = [];

    // Left margin via GS L command (203 DPI → 8 dots/mm)
    final leftDots = (_style.marginLeftMm * 8).round();
    if (leftDots > 0) {
      bytes += [0x1D, 0x4C, leftDots & 0xFF, (leftDots >> 8) & 0xFF];
    }

    // Top margin: empty feed lines (standard thermal line ≈ 3.5 mm)
    final topLines = (_style.marginTopMm / 3.5).round();
    if (topLines > 0) bytes += generator.emptyLines(topLines);

    if (job.type == PrintType.kot) {
      bytes += _buildKot(generator, job.order, job.stationLabel);
    } else if (job.type == PrintType.cancelKot) {
      bytes += _buildCancelKot(generator, job.order, job.stationLabel);
    } else {
      final restaurantProfile = await RestaurantProfileService.getProfile();
      img.Image? logoImage = await _fetchEscLogo(restaurantProfile);
      // Resize to configured width (203 DPI: 1mm ≈ 8 dots); height auto-scales.
      if (logoImage != null) {
        final targetWidthDots =
            (_style.escLogoSizeMm * 8).round().clamp(50, 400);
        logoImage = img.copyResize(logoImage, width: targetWidthDots);
      }

      final isAggregator = job.order.billData['is_aggregator'] == true;
      final upiQrImage = (!isAggregator &&
              PrintConfig.upiQrEnabled &&
              PrintConfig.upiId.trim().isNotEmpty)
          ? _buildQrBitmap(PrintConfig.upiQrDataForBill(job.order.billData),
              _style.escUpiQrSizeMm)
          : null;
      final feedbackQrImage = (!isAggregator && PrintConfig.feedbackQrEnabled)
          ? _buildQrBitmap(PrintConfig.feedbackQrData(job.order.orderId),
              _style.escFeedbackQrSizeMm)
          : null;

      bytes += _buildBill(generator, job.order, restaurantProfile, logoImage,
          upiQrImage, feedbackQrImage);
    }

    // Bottom margin
    final bottomLines = (_style.marginBottomMm / 3.5).round();
    if (bottomLines > 0) bytes += generator.emptyLines(bottomLines);

    bytes += generator.cut();
    return bytes;
  }

  // ─────────────────────────────────────────────────────
  // WIDTH CONSTANTS
  // 58mm → 32 chars | 80mm → 42 chars
  // ─────────────────────────────────────────────────────
  // static int get _width => PrintConfig.paperSize == PaperSize.mm80 ? 48 : 32;
  static int get _width => PrintConfig.is80mm ? 48 : 32;

  static int get _itemNameBillWidth => _width == 42 ? 24 : 16;
  static int get _itemNameKotWidth => _width == 42 ? 26 : 18;
  static int get _tableDisplayWidth => _width == 42 ? 18 : 12;
  static int get _waiterNameWidth => _width == 42 ? 24 : 16;
  static int get _padding => _width == 42 ? 2 : 1;
  static int get _innerWidth => _width - _padding; // right side stays open

  static PosTextSize _posTextSize(int size) {
    switch (size.clamp(1, 8)) {
      case 2:
        return PosTextSize.size2;
      case 3:
        return PosTextSize.size3;
      case 4:
        return PosTextSize.size4;
      case 5:
        return PosTextSize.size5;
      case 6:
        return PosTextSize.size6;
      case 7:
        return PosTextSize.size7;
      case 8:
        return PosTextSize.size8;
      default:
        return PosTextSize.size1;
    }
  }

  /// Renders [data] as a black-on-white QR bitmap sized to [sizeMm].
  ///
  /// The native `GS ( k` QR command is unsupported by many thermal printers —
  /// they echo the command parameters as text instead — so the symbol is drawn
  /// as pixels and sent through the same `ESC *` path used for the logo.
  /// Modules are painted at an integer scale so they stay pure black/white:
  /// resampling would blur the edges past the printer's luminance threshold.
  static img.Image? _buildQrBitmap(String data, double sizeMm) {
    if (data.trim().isEmpty) return null;
    try {
      final code = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final matrix = QrImage(code);

      const quietModules = 4; // mandatory white border, else scanners fail
      final totalModules = matrix.moduleCount + quietModules * 2;
      final maxDots = PrintConfig.is80mm ? 576 : 384;
      final targetDots = (sizeMm * 8).round().clamp(80, maxDots);
      final scale = (targetDots ~/ totalModules).clamp(1, 12);
      final sideDots = totalModules * scale;

      final bitmap = img.Image(width: sideDots, height: sideDots);
      img.fill(bitmap, color: img.ColorRgb8(255, 255, 255));
      final black = img.ColorRgb8(0, 0, 0);

      for (var row = 0; row < matrix.moduleCount; row++) {
        for (var col = 0; col < matrix.moduleCount; col++) {
          if (!matrix.isDark(row, col)) continue;
          final x = (col + quietModules) * scale;
          final y = (row + quietModules) * scale;
          img.fillRect(
            bitmap,
            x1: x,
            y1: y,
            x2: x + scale - 1,
            y2: y + scale - 1,
            color: black,
          );
        }
      }
      return bitmap;
    } catch (_) {
      return null;
    }
  }

  static PosStyles _escStyle(
    PrintStyleItem item, {
    PosAlign align = PosAlign.left,
    bool underline = false,
    bool? boldOverride,
  }) {
    final size = PrintConfig.is80mm ? item.escSize80 : item.escSize58;
    final posSize = _posTextSize(size);
    return PosStyles(
      align: align,
      bold: boldOverride ?? item.escBold,
      underline: underline,
      height: posSize,
      width: posSize,
    );
  }

  static bool _sameEscStyle(PrintStyleItem first, PrintStyleItem second) {
    final firstSize = PrintConfig.is80mm ? first.escSize80 : first.escSize58;
    final secondSize = PrintConfig.is80mm ? second.escSize80 : second.escSize58;
    return firstSize == secondSize && first.escBold == second.escBold;
  }

  // ─────────────────────────────────────────────────────
  // ALIGNMENT HELPER
  // Pads left + right to fill full _width
  // ─────────────────────────────────────────────────────
  //  Updated — accepts custom width, defaults to _width
  static String _alignLR(String left, String right, [int? width]) {
    final w = width ?? _width;
    final spaces = w - left.length - right.length;
    return '$left${' ' * (spaces > 1 ? spaces : 1)}$right';
  }

  static String _alignRightLabelValue(
    String label,
    String value, {
    int? blockWidth,
    int valueWidth = 7,
  }) {
    final bw = blockWidth ?? (_width == 42 ? 28 : 24);
    final int labelWidth = bw - valueWidth - 2;
    final safeLabel = _truncate(label, labelWidth);
    final inner =
        '${safeLabel.padRight(labelWidth)}: ${value.padLeft(valueWidth)}';
    return inner.padLeft(_width);
  }

  // ── Logo helpers ─────────────────────────────────────────────────
  static String _resolveLogoUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = PrintConfig.apiUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/$path';
  }

  static Future<img.Image?> _fetchEscLogo(
      RestaurantProfileModel profile) async {
    final rawPath =
        profile.billLogo.isNotEmpty ? profile.billLogo : profile.restaurantLogo;
    final url = _resolveLogoUrl(rawPath);
    if (url.isEmpty) return null;
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return img.decodeImage(res.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  static List<int> _buildBill(
    Generator g,
    RestaurantOrder o,
    RestaurantProfileModel profile,
    img.Image? logoImage,
    img.Image? upiQrImage,
    img.Image? feedbackQrImage,
  ) {
    List<int> b = [];

    final restaurantName = profile.restaurantName.isNotEmpty
        ? profile.restaurantName
        : o.restaurantName;
    final restaurantAddress = profile.restaurantAddress;
    final restaurantEmail = profile.restaurantEmail;
    final restaurantPhone = profile.restaurantPhone;
    final restaurantGstNo = profile.gstCode;
    final restaurantLogo =
        profile.billLogo.isNotEmpty ? profile.billLogo : profile.restaurantLogo;
    final restaurantFssai = profile.fssai;

    final String lineEquals = '=' * _width;
    final String lineDashes = '-' * _width;
    final String gap = ' ' * _width;

    // ── Header ──
    final bill = o.billData;

    double d(String key) =>
        double.tryParse(bill[key]?.toString() ?? '0') ?? 0.0;

    final custName = bill['cust_name']?.toString().trim() ?? '';
    final custPhone = bill['cust_phone']?.toString().trim() ?? '';
    final custGstName = bill['cust_gst_name']?.toString().trim() ?? '';
    final custGstNumber = bill['cust_gst']?.toString().trim() ?? '';
    final orderType = bill['order_type']?.toString().trim() ?? '';
    final tableName = bill['table_name']?.toString().trim() ?? '';
    final waiterName = bill['waiter_name']?.toString().trim() ?? '';
    final orderNote = bill['order_note']?.toString().trim() ?? '';

    String centerLabel() {
      if (orderType == 'pos' || orderType == 'dinein') {
        return tableName.toUpperCase();
      }
      return orderType.replaceAll('_', ' ').toUpperCase();
    }

    // b += g.text(
    //   lineEquals,
    //   styles: const PosStyles(align: PosAlign.center, bold: true),
    // );

    // ── Logo ──
    if (logoImage != null) {
      b += g.image(logoImage, align: PosAlign.center);
      b += g.feed(1);
    }

    b += g.text(
      restaurantName.toUpperCase(),
      styles: _escStyle(_style.restaurantName, align: PosAlign.center),
    );

    if (restaurantAddress.isNotEmpty) {
      b += g.text(
        restaurantAddress,
        styles: _escStyle(_style.restaurantAddress, align: PosAlign.center),
      );
    }

    // if (restaurantEmail.isNotEmpty) {
    //   b += g.text(
    //     restaurantEmail,
    //     styles: const PosStyles(align: PosAlign.center),
    //   );
    // }

    if (restaurantPhone.isNotEmpty) {
      b += g.text(
        'Ph: $restaurantPhone',
        styles: _escStyle(_style.restaurantPhone, align: PosAlign.center),
      );
    }

    if (restaurantGstNo.isNotEmpty) {
      b += g.text(
        'GST No: $restaurantGstNo',
        styles: _escStyle(_style.restaurantGst, align: PosAlign.center),
      );
    }

    if (restaurantFssai.isNotEmpty) {
      b += g.text(
        'Fssai No: $restaurantFssai',
        styles: _escStyle(_style.restaurantFssai, align: PosAlign.center),
      );
    }

    b += g.text(
      lineEquals,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    // ── Order info ── (unchanged)

    for (final row in _buildWrapped3ColRow(
      'Bill NO. ${o.displayOrderId}',
      waiterName,
      _formatDate(o.receivedAt),
    )) {
      b += g.text(
        row,
        styles: _escStyle(_style.billInfoRow1, align: PosAlign.center),
      );
    }

    // customer info row
    if (custName.isNotEmpty ||
        centerLabel().trim().isNotEmpty ||
        custPhone.isNotEmpty) {
      for (final row in _buildWrapped3ColRow(
        custName,
        centerLabel(),
        custPhone,
      )) {
        b += g.text(
          row,
          styles: _escStyle(_style.billInfoRow2, align: PosAlign.center),
        );
      }
    }

    if (custGstName.isNotEmpty || custGstNumber.isNotEmpty) {
      for (final row in _buildWrapped3ColRow(
        custGstName,
        '',
        custGstNumber,
      )) {
        b += g.text(
          row,
          styles: _escStyle(_style.billInfoRow3, align: PosAlign.center),
        );
      }
    }

    if (o.dailyToken.isNotEmpty) {
      for (final row in _buildWrapped3ColRow(
        '',
        'T-${o.dailyToken}',
        '',
      )) {
        b += g.text(
          row,
          styles: _escStyle(_style.billInfoRow4, align: PosAlign.center),
        );
      }
    }

    b += g.text(lineDashes,
        styles: const PosStyles(align: PosAlign.center, bold: true));
    // ── Table Header ──  full width columns
    final bool show80mmDate =
        PrintConfig.is80mm && PrintConfig.showItemDateOn80mm;
    final int amtWidth = _width == 42 ? 10 : 8;
    final int qtyWidth = _width == 42 ? 7 : 6;
    final int dateWidth = show80mmDate ? 6 : 0; // "9-Jul" = 5 chars + 1 pad
    final int itemWidth = _width - qtyWidth - amtWidth - dateWidth;

    b += g.text(
      _padR('ITEM', itemWidth) +
          _padC('QTY', qtyWidth) +
          _padL('AMT', amtWidth) +
          (show80mmDate ? _padL('DATE', dateWidth) : ''),
      styles: _escStyle(_style.billTableHeader, align: PosAlign.center),
    );
    b += g.text(lineDashes,
        styles: const PosStyles(align: PosAlign.center, bold: true));

    // ── Items loop ── complementary + variations + add-ons
    for (final item in OrderItem.mergedForBill(o.items)) {
      if (item.foodStatus == 3) continue;

      final double unitPrice =
          (item.itemUnit.isNotEmpty && item.itemUnitPrice > 0
                  ? item.itemUnitPrice
                  : item.price) +
              item.variationTotal +
              item.addonTotal;

      final amt = unitPrice * item.quantity;

      final isComp = item.complementary?.toString().toLowerCase() == 'yes';

      final qtyDisplay = item.itemUnit.isNotEmpty
          ? '${_formatQty(item.quantity)}${item.itemUnit}'
          : _formatQty(item.quantity);

      final displayName = isComp ? '${item.name} (Comp)' : item.name;

      final itemNameLines = _wrapText(displayName, itemWidth);

      final dateStr = show80mmDate ? _escItemDate(item.createdAt) : '';

      if (_sameEscStyle(_style.billTableContent, _style.billTableQty)) {
        b += g.text(
          _padR(itemNameLines.first, itemWidth) +
              _padC(qtyDisplay, qtyWidth) +
              _padL(_formatMoney(amt), amtWidth) +
              (show80mmDate ? _padL(dateStr, dateWidth) : ''),
          styles: _escStyle(_style.billTableContent),
        );
      } else {
        b += g.row([
          PosColumn(
            text: itemNameLines.first,
            width: show80mmDate ? 7 : 8,
            styles: _escStyle(_style.billTableContent),
          ),
          PosColumn(
            text: qtyDisplay,
            width: show80mmDate ? 1 : 2,
            styles: _escStyle(_style.billTableQty, align: PosAlign.center),
          ),
          PosColumn(
            text: _formatMoney(amt),
            width: 2,
            styles: _escStyle(_style.billTableContent, align: PosAlign.right),
          ),
          if (show80mmDate)
            PosColumn(
              text: dateStr,
              width: 2,
              styles: _escStyle(_style.billTableContent, align: PosAlign.right),
            ),
        ]);
      }

      for (int i = 1; i < itemNameLines.length; i++) {
        b += g.text(
          _padR(itemNameLines[i], itemWidth),
          styles: _escStyle(_style.billTableContent),
        );
      }

      if (item.variations.isNotEmpty) {
        for (final variation in item.variations) {
          final wrapped = _wrapIndented(
            '+ $variation',
            itemWidth - 2,
            itemWidth - 4,
            '  ',
          );
          for (int i = 0; i < wrapped.length; i++) {
            b += g.text(
              i == 0 ? ' ${wrapped[i]}' : '   ${wrapped[i]}',
              styles: _escStyle(_style.billTableMeta),
            );
          }
        }
      }

      if (item.addons.isNotEmpty) {
        for (final addon in item.addons) {
          final wrapped = _wrapIndented(
            '+ $addon',
            itemWidth - 2,
            itemWidth - 4,
            '  ',
          );
          for (int i = 0; i < wrapped.length; i++) {
            b += g.text(
              i == 0 ? ' ${wrapped[i]}' : '   ${wrapped[i]}',
              styles: _escStyle(_style.billTableMeta),
            );
          }
        }
      }
    }
    // ════════════════════════════════════════════════════
    // ORDER NOTE SECTION
    // ════════════════════════════════════════════════════

    if (orderNote != '') {
      b += g.text(lineDashes,
          styles: const PosStyles(align: PosAlign.center, bold: true));
      b += g.text('Notes : $orderNote',
          styles: _escStyle(_style.orderNote, align: PosAlign.center));
    }

    // ════════════════════════════════════════════════════
    // PRICE BREAKDOWN SECTION
    // ════════════════════════════════════════════════════
    // final bill = o.billData;

    // double d(String key) =>
    //     double.tryParse(bill[key]?.toString() ?? '0') ?? 0.0;

    final itemTotal = d('order_item_total') ?? 0;
    final serviceCharge = d('service_charge_amount');
    final deliveryCharge = d('delivery_charge');
    final tip = d('tip_amount');
    final subTotal = d('order_subtotal');
    final gstTax = d('gst_tax');
    final vatTax = d('vat_tax');
    final packingCharge = d('packing_charge') ?? 0;
    final grantAmount = d('grant_amount');
    final paymentAmount = d('payment_amount');
    final roomAdvance = d('room_advance_pay');
    final roomPending = d('room_remaining_pay');
    final roundOff = d('');
    final isAggregator = bill['is_aggregator'] == true;
    final paymentStatus = bill['payment_status']?.toString() ?? '';
    final paymentMethod = bill['payment_method']?.toString() ?? '';
    final walletAmount =
        double.tryParse(bill['wallet_used_amount']?.toString() ?? '0') ?? 0.0;
    final loyaltyAmount =
        double.tryParse(bill['loyalty_discount_amount']?.toString() ?? '0') ??
            0.0;
    final couponCode = bill['coupon_code']?.toString() ?? '';
    final discountAmount =
        double.tryParse(bill['discount_amount']?.toString() ?? '0') ?? 0.0;
    final associatedOrders = bill['associated_orders'] as List<dynamic>?;
    final isRoomOrder = associatedOrders != null && associatedOrders.isNotEmpty;

    String payLabel() {
      if (paymentStatus == 'unpaid' && paymentMethod == 'pending') {
        return '(Unpaid)';
      }
      // Capitalize first letter of payment_method
      final method = paymentMethod.isNotEmpty
          ? paymentMethod[0].toUpperCase() + paymentMethod.substring(1)
          : '';
      return '(Paid by $method)';
    }

    b += g.text(lineEquals,
        styles: const PosStyles(align: PosAlign.center, bold: true));

    // // Item Total — always
    // b += g.text(_alignLR('Item Total', itemTotal.toStringAsFixed(2)));

    // // Service Charge — if > 0
    // if (serviceCharge > 0) {
    //   b += g.text(_alignLR('Service Charge', serviceCharge.toStringAsFixed(2)));
    // }

    // // Delivery Charge — if > 0
    // if (deliveryCharge > 0) {
    //   b += g
    //       .text(_alignLR('Delivery Charge', deliveryCharge.toStringAsFixed(2)));
    // }

    // // Tip — if > 0
    // if (tip > 0) {
    //   b += g.text(_alignLR('Tip', tip.toStringAsFixed(2)));
    // }

    // // Sub Total — always
    // b += g.text(_alignLR('Sub Total', subTotal.toStringAsFixed(2)));

    // // CGST + SGST — if gst_tax > 0
    // if (gstTax > 0) {
    //   final half = gstTax / 2;
    //   b += g.text(_alignLR('CGST', half.toStringAsFixed(2)));
    //   b += g.text(_alignLR('SGST', half.toStringAsFixed(2)));
    // }

    // // VAT — if > 0
    // if (vatTax > 0) {
    //   b += g.text(_alignLR('VAT', vatTax.toStringAsFixed(2)));
    // }
    b += g.text(
      _alignRightLabelValue('Item Total', itemTotal.toStringAsFixed(2)),
      styles: _escStyle(_style.billAmountLine),
    );

    if (serviceCharge > 0) {
      b += g.text(
        _alignRightLabelValue(
            'Service Charge', serviceCharge.toStringAsFixed(2)),
        styles: _escStyle(_style.billAmountLine),
      );
    }

    if (deliveryCharge > 0) {
      b += g.text(
        _alignRightLabelValue(
            'Delivery Charge', deliveryCharge.toStringAsFixed(2)),
        styles: _escStyle(_style.billAmountLine),
      );
    }

    if (discountAmount > 0) {
      b += g.text(
        _alignRightLabelValue('Discount', discountAmount.toString()),
        styles: _escStyle(_style.billAmountLine),
      );
    }

    if (packingCharge > 0) {
      b += g.text(
        _alignRightLabelValue(
            'Packing Charge', packingCharge.toStringAsFixed(2)),
        styles: _escStyle(_style.billAmountLine),
      );
    }

    if (couponCode != '') {
      b += g.text(
        _alignRightLabelValue('Coupon Code', couponCode.toString()),
        styles: _escStyle(_style.billAmountLine),
      );
    }

    if (loyaltyAmount > 0) {
      b += g.text(
        _alignRightLabelValue('Loyalty', loyaltyAmount.toString()),
        styles: _escStyle(_style.billAmountLine),
      );
    }

    if (walletAmount > 0) {
      b += g.text(
        _alignRightLabelValue('Wallet', walletAmount.toString()),
        styles: _escStyle(_style.billAmountLine),
      );
    }

    if (tip > 0) {
      b += g.text(
        _alignRightLabelValue('Tip', tip.toStringAsFixed(2)),
        styles: _escStyle(_style.billAmountLine),
      );
    }

    if (!isAggregator) {
      b += g.text(
        _alignRightLabelValue('Sub Total', subTotal.toStringAsFixed(2)),
        styles: _escStyle(_style.billAmountLine),
      );
    }

    if (gstTax > 0) {
      if (isAggregator) {
        b += g.text(
          _alignRightLabelValue('GST', gstTax.toStringAsFixed(2)),
          styles: _escStyle(_style.billAmountLine),
        );
      } else {
        final half = gstTax / 2;
        b += g.text(
          _alignRightLabelValue('CGST', half.toStringAsFixed(2)),
          styles: _escStyle(_style.billAmountLine),
        );
        b += g.text(
          _alignRightLabelValue('SGST', half.toStringAsFixed(2)),
          styles: _escStyle(_style.billAmountLine),
        );
      }
    }

    if (vatTax > 0) {
      b += g.text(
        _alignRightLabelValue('VAT', vatTax.toStringAsFixed(2)),
        styles: _escStyle(_style.billAmountLine),
      );
    }

    b += g.text(lineDashes,
        styles: const PosStyles(align: PosAlign.center, bold: true));

    // Total — room = payment_amount, normal = grant_amount
    final totalAmount = isRoomOrder ? paymentAmount : grantAmount;
    final paymentLabel = isRoomOrder || isAggregator ? '' : payLabel();
    if (paymentLabel.isEmpty ||
        _sameEscStyle(_style.billTotal, _style.billPaidBy)) {
      final totalLabel = paymentLabel.isEmpty ? 'TOTAL' : 'TOTAL $paymentLabel';
      b += g.text(
        _alignLR(totalLabel, _formatMoney(totalAmount ?? 0)),
        styles: _escStyle(_style.billTotal, align: PosAlign.center),
      );
    } else {
      b += g.text(
        _alignLR('TOTAL', _formatMoney(totalAmount ?? 0)),
        styles: _escStyle(_style.billTotal, align: PosAlign.center),
      );
      b += g.text(
        paymentLabel,
        styles: _escStyle(_style.billPaidBy, align: PosAlign.left),
      );
    }

    // ── Delivery Details — only for delivery orders ───────
    if (bill['order_type']?.toString() == 'delivery') {
      b += g.text(lineDashes,
          styles: const PosStyles(align: PosAlign.center, bold: true));
      b += g.text('-- Delivery Details --',
          styles: _escStyle(_style.deliveryHeader, align: PosAlign.center));
      b += g.text(lineDashes,
          styles: const PosStyles(align: PosAlign.center, bold: true));

      final custName = bill['delivery_cust_name']?.toString() ?? '';
      final phone = bill['delivery_cust_phone']?.toString() ?? '';
      final addrType = bill['delivery_address_type']?.toString() ?? '';
      final addr = bill['delivery_cust_address']?.toString() ?? '';
      final pincode = bill['delivery_cust_pincode']?.toString() ?? '';

      String row(String label, String value) {
        final labelPart = '${label.padRight(10)}: ';
        final maxValueWidth = _width - labelPart.length;

        if (value.length <= maxValueWidth) return '$labelPart$value';

        final indent = ' ' * labelPart.length;
        final buffer = StringBuffer();
        var remaining = value;
        bool first = true;

        while (remaining.isNotEmpty) {
          final chunk = remaining.length <= maxValueWidth
              ? remaining
              : remaining.substring(0, maxValueWidth);
          remaining = remaining.length <= maxValueWidth
              ? ''
              : remaining.substring(maxValueWidth);
          buffer.write(first ? '$labelPart$chunk' : '\n$indent$chunk');
          first = false;
        }

        return buffer.toString();
      }

      if (custName.isNotEmpty) {
        b += g.text(row('Name', custName),
            styles: _escStyle(_style.deliveryContent));
      }
      if (phone.isNotEmpty) {
        b += g.text(row('Phone', phone),
            styles: _escStyle(_style.deliveryContent));
      }
      if (addrType.isNotEmpty) {
        b += g.text(row('Add. Type', addrType),
            styles: _escStyle(_style.deliveryContent));
      }
      if (addr.isNotEmpty) {
        b += g.text(row('Address', addr),
            styles: _escStyle(_style.deliveryContent));
      }
      if (pincode.isNotEmpty) {
        b += g.text(row('Pincode', pincode),
            styles: _escStyle(_style.deliveryContent));
      }
    }

    // ── Previous Room Bill — only for room orders ─────────
    if (isRoomOrder) {
      b += g.text(lineDashes,
          styles: const PosStyles(align: PosAlign.center, bold: true));
      b += g.text(
        '-- Previous Room Bill --',
        styles: _escStyle(_style.roomHeader, align: PosAlign.center),
      );
      b += g.text(lineDashes,
          styles: const PosStyles(align: PosAlign.center, bold: true));

      for (final assoc in associatedOrders) {
        final aMap = assoc as Map<String, dynamic>;
        final aId = aMap['restaurant_order_id']?.toString() ?? '';
        final aAmt =
            double.tryParse(aMap['order_amount']?.toString() ?? '0') ?? 0.0;
        b += g.text(
          _alignLR('Order ID #$aId', aAmt.toStringAsFixed(2)),
          styles: _escStyle(_style.roomContent),
        );
      }

      b += g.text(lineDashes,
          styles: const PosStyles(align: PosAlign.center, bold: true));

      b += g.text(
        _alignRightLabelValue('Room Advance', roomAdvance.toStringAsFixed(2)),
        styles: _escStyle(_style.billAmountLine),
      );
      b += g.text(
        _alignRightLabelValue('Room Pending', roomPending.toStringAsFixed(2)),
        styles: _escStyle(_style.billAmountLine),
      );

      b += g.text(lineDashes,
          styles: const PosStyles(align: PosAlign.center, bold: true));

      b += g.text(
        _alignLR('GRAND TOTAL ${payLabel()}',
            'Rs.${grantAmount.toStringAsFixed(0)}'),
        styles: _escStyle(_style.billGrandTotal, align: PosAlign.center),
      );
    }

    // ── QR Codes — bill only, never on aggregator orders ──
    if (upiQrImage != null) {
      b += g.text(lineDashes,
          styles: const PosStyles(align: PosAlign.center, bold: true));
      b += g.image(upiQrImage, align: PosAlign.center);
      b += g.text('Scan to Pay',
          styles: _escStyle(_style.footer, align: PosAlign.center));
    }

    if (feedbackQrImage != null) {
      b += g.text(lineDashes,
          styles: const PosStyles(align: PosAlign.center, bold: true));
      b += g.image(feedbackQrImage, align: PosAlign.center);
      b += g.text('Scan for Feedback',
          styles: _escStyle(_style.footer, align: PosAlign.center));
    }

    // ── Footer ───────────────────────────────────────────
    b += g.text(lineEquals,
        styles: const PosStyles(align: PosAlign.center, bold: true));
    if (profile.footerText.isNotEmpty)
      b += g.text(
        profile.footerText,
        styles: _escStyle(_style.footer, align: PosAlign.center),
      );
    b += g.text(
      'Powered by MyGenie',
      styles: _escStyle(
        _style.footer,
        align: PosAlign.center,
        boldOverride: true,
      ),
    );

    return b;
  }

  // ─────────────────────────────────────────────────────
  // KOT
  // ─────────────────────────────────────────────────────
  static List<int> _buildKot(
    Generator g,
    RestaurantOrder o,
    String? stationLabel,
  ) {
    List<int> b = [];
    final lineEq = '=' * _width;
    final lineDash = '-' * _width;

    final station = stationLabel?.trim().toUpperCase() ?? '';
    final title = station.isNotEmpty ? 'KOT [ $station ]' : 'KOT';

    final srWidth = _width == 42 ? 4 : 3;
    final qtyWidth = _width == 42 ? 6 : 5;
    final itemWidth = _width - srWidth - qtyWidth;

    final waiterLine = o.waiterName.length > _width
        ? _truncate(o.waiterName, _width - 9)
        : o.waiterName;

    final safeCustomerName = (o.userCustName ?? '').trim();
    final safeCustomerPhone = (o.userCustPhone ?? '').trim();

    for (final line in _wrapTitle(title)) {
      b += g.text(
        line,
        styles: _escStyle(_style.kotTitle, align: PosAlign.center),
      );
    }

    b += g.text(
      lineEq,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    for (final row in _buildWrapped3ColRow(
      'Order No:#${o.displayOrderId}',
      waiterLine,
      _formatDate(o.receivedAt),
    )) {
      b += g.text(
        row,
        styles: _escStyle(_style.kotOrderInfo1, align: PosAlign.center),
      );
    }

    String centerLabel() {
      final type = o.orderType.trim().toLowerCase();
      final table = (o.tableName ?? '').trim();
      if (type == 'pos' || type == 'dinein') {
        return table.isNotEmpty ? table.toUpperCase() : 'WC';
      }
      return o.orderType.trim().replaceAll('_', ' ').toUpperCase();
    }

    final centerText = centerLabel();

    if (centerText.isNotEmpty) {
      for (final row in _buildWrapped3ColRow(
        '',
        centerText,
        '',
      )) {
        b += g.text(
          row,
          styles: _escStyle(_style.kotOrderInfo2, align: PosAlign.center),
        );
      }
    }

    if (safeCustomerName.isNotEmpty || safeCustomerPhone.isNotEmpty) {
      for (final row in _buildWrapped3ColRow(
        safeCustomerName,
        '',
        safeCustomerPhone,
      )) {
        b += g.text(
          row,
          styles: _escStyle(_style.kotOrderInfo3, align: PosAlign.center),
        );
      }
    }

    if (o.dailyToken.isNotEmpty) {
      for (final row in _buildWrapped3ColRow(
        '',
        'T-${o.dailyToken}',
        '',
      )) {
        b += g.text(
          row,
          styles: _escStyle(_style.kotOrderInfo4, align: PosAlign.center),
        );
      }
    }

    b += g.text(
      lineDash,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    b += g.text(
      _padR('SR', srWidth) +
          _padR(' ITEM', itemWidth) +
          _padL('QTY  ', qtyWidth),
      styles: _escStyle(_style.kotTableHeader),
    );

    b += g.text(
      lineDash,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    int srNo = 1;

    for (final item in o.items) {
      if (item.foodStatus == 3) {
        continue;
      }

      final sr = '${srNo++}.';
      final qtyString = item.itemUnit.isNotEmpty
          ? '${_formatQty(item.quantity)}${item.itemUnit}'
          : _formatQty(item.quantity);
      final qty = '$qtyString  ';
      final itemNameLines = _wrapText(item.name.trim(), itemWidth);

      b += g.text(
        _padR(sr, srWidth) +
            _padR(itemNameLines.first, itemWidth) +
            _padL(qty, qtyWidth),
        styles: _escStyle(_style.kotTableContent),
      );

      for (int i = 1; i < itemNameLines.length; i++) {
        b += g.text(
          _padR('', srWidth) + _padR(itemNameLines[i], itemWidth),
          styles: _escStyle(_style.kotTableContent),
        );
      }

      if (item.variations.isNotEmpty) {
        final grouped = _groupKotModifiers(item.variations, '-');
        for (final line in grouped) {
          final wrapped = _wrapIndented(
            line,
            _width - 5,
            _width - 6,
            '     ',
          );
          for (int i = 0; i < wrapped.length; i++) {
            b += g.text(
              i == 0 ? '   ${wrapped[i]}' : wrapped[i],
              styles: _escStyle(_style.kotTableContent, boldOverride: false),
            );
          }
        }
      }

      if (item.addons.isNotEmpty) {
        final grouped = _groupKotModifiers(item.addons, '+');
        for (final line in grouped) {
          final wrapped = _wrapIndented(
            line,
            _width - 5,
            _width - 6,
            '     ',
          );
          for (int i = 0; i < wrapped.length; i++) {
            b += g.text(
              i == 0 ? '   ${wrapped[i]}' : wrapped[i],
              styles: _escStyle(_style.kotTableContent, boldOverride: false),
            );
          }
        }
      }

      if (item.note.isNotEmpty) {
        final wrapped = _wrapIndented(
          'Note: ${item.note.trim()}',
          _width - 4,
          _width - 7,
          '      ',
        );

        for (int i = 0; i < wrapped.length; i++) {
          b += g.text(
            i == 0 ? '   ${wrapped[i]}' : wrapped[i],
            styles: _escStyle(_style.kotTableContent, boldOverride: false),
          );
        }
      }
    }
    if (o.orderNote.trim().isNotEmpty) {
      b += g.text(
        lineDash,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      b += g.text(
        _padC('Notes: ${_truncate(o.orderNote.trim(), _width - 8)}', _width),
        styles: _escStyle(_style.kotNote),
      );
    }

    b += g.text(
      lineEq,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    b += g.text(
      _padC('Powered by MyGenie', _width),
      styles: _escStyle(
        _style.footer,
        align: PosAlign.left,
        boldOverride: true,
      ),
    );

    return b;
  }

  // ─────────────────────────────────────────────────────
  // CANCEL KOT
  // Identical to KOT but with CANCEL header
  // ─────────────────────────────────────────────────────
  static List<int> _buildCancelKot(
    Generator g,
    RestaurantOrder o,
    String? stationLabel,
  ) {
    List<int> b = [];
    final lineEq = '=' * _width;
    final lineDash = '-' * _width;

    final station = stationLabel?.trim().toUpperCase() ?? '';
    final title = station.isNotEmpty ? 'CANCEL KOT [ $station ]' : 'CANCEL';

    final srWidth = _width == 42 ? 4 : 3;
    final qtyWidth = _width == 42 ? 6 : 5;
    final itemWidth = _width - srWidth - qtyWidth;

    final waiterLine = o.waiterName.length > _width
        ? _truncate(o.waiterName, _width - 9)
        : o.waiterName;

    final safeCustomerName = (o.userCustName ?? '').trim();
    final safeCustomerPhone = (o.userCustPhone ?? '').trim();

    final cancelTitleSize = PrintConfig.is80mm
        ? _style.cancelKotTitle.escSize80
        : _style.cancelKotTitle.escSize58;
    final cancelTitleWidth =
        (_width / cancelTitleSize.clamp(1, 8)).floor().clamp(1, _width);
    for (final line in _wrapText(title.trim(), cancelTitleWidth)) {
      b += g.text(
        line,
        styles: _escStyle(_style.cancelKotTitle, align: PosAlign.center),
      );
    }

    // for (final line in _wrapTitle(title)) {
    //   b += g.text(
    //     line,
    //     styles: _escStyle(_style.cancelKotTitle, align: PosAlign.center),
    //   );
    // }

    b += g.text(
      lineEq,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    for (final row in _buildWrapped3ColRow(
      'Order No:#${o.displayOrderId}',
      waiterLine,
      _formatDate(o.receivedAt),
    )) {
      b += g.text(
        row,
        styles: _escStyle(_style.kotOrderInfo1, align: PosAlign.center),
      );
    }

    String centerLabel() {
      final type = o.orderType.trim().toLowerCase();
      final table = (o.tableName ?? '').trim();
      if (type == 'pos' || type == 'dinein') {
        return table.isNotEmpty ? table.toUpperCase() : 'WC';
      }
      return o.orderType.trim().replaceAll('_', ' ').toUpperCase();
    }

    final centerText = centerLabel();

    if (centerText.isNotEmpty) {
      for (final row in _buildWrapped3ColRow(
        '',
        centerText,
        '',
      )) {
        b += g.text(
          row,
          styles: _escStyle(_style.kotOrderInfo2, align: PosAlign.center),
        );
      }
    }

    if (safeCustomerName.isNotEmpty || safeCustomerPhone.isNotEmpty) {
      for (final row in _buildWrapped3ColRow(
        safeCustomerName,
        '',
        safeCustomerPhone,
      )) {
        b += g.text(
          row,
          styles: _escStyle(_style.kotOrderInfo3, align: PosAlign.center),
        );
      }
    }

    if (o.dailyToken.isNotEmpty) {
      for (final row in _buildWrapped3ColRow(
        '',
        'T-${o.dailyToken}',
        '',
      )) {
        b += g.text(
          row,
          styles: _escStyle(_style.kotOrderInfo4, align: PosAlign.center),
        );
      }
    }

    b += g.text(
      lineDash,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    b += g.text(
      _padR('SR', srWidth) +
          _padR(' ITEM', itemWidth) +
          _padL('QTY  ', qtyWidth),
      styles: _escStyle(_style.kotTableHeader),
    );

    b += g.text(
      lineDash,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    int srNo = 1;

    for (final item in o.items) {
      final sr = '${srNo++}.';
      final qtyString = item.itemUnit.isNotEmpty
          ? '${_formatQty(item.quantity)}${item.itemUnit}'
          : _formatQty(item.quantity);
      final qty = '${qtyString}  ';
      final itemNameLines = _wrapText(item.name.trim(), itemWidth);

      b += g.text(
        _padR(sr, srWidth) +
            _padR(itemNameLines.first, itemWidth) +
            _padL(qty, qtyWidth),
        styles: _escStyle(_style.kotTableContent),
      );

      for (int i = 1; i < itemNameLines.length; i++) {
        b += g.text(
          _padR('', srWidth) + _padR(itemNameLines[i], itemWidth),
          styles: _escStyle(_style.kotTableContent),
        );
      }

      if (item.variations.isNotEmpty) {
        final grouped = _groupKotModifiers(item.variations, '-');
        for (final line in grouped) {
          final wrapped = _wrapIndented(
            line,
            _width - 5,
            _width - 6,
            '     ',
          );
          for (int i = 0; i < wrapped.length; i++) {
            b += g.text(
              i == 0 ? '   ${wrapped[i]}' : wrapped[i],
              styles: _escStyle(_style.kotTableContent, boldOverride: false),
            );
          }
        }
      }

      if (item.addons.isNotEmpty) {
        final grouped = _groupKotModifiers(item.addons, '+');
        for (final line in grouped) {
          final wrapped = _wrapIndented(
            line,
            _width - 5,
            _width - 6,
            '     ',
          );
          for (int i = 0; i < wrapped.length; i++) {
            b += g.text(
              i == 0 ? '   ${wrapped[i]}' : wrapped[i],
              styles: _escStyle(_style.kotTableContent, boldOverride: false),
            );
          }
        }
      }

      if (item.note.isNotEmpty) {
        final wrapped = _wrapIndented(
          'Note: ${item.note.trim()}',
          _width - 4,
          _width - 7,
          '      ',
        );

        for (int i = 0; i < wrapped.length; i++) {
          b += g.text(
            i == 0 ? '   ${wrapped[i]}' : wrapped[i],
            styles: _escStyle(_style.kotTableContent, boldOverride: false),
          );
        }
      }
    }

    b += g.text(
      lineEq,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    b += g.text(
      _padC('Powered by MyGenie', _width),
      styles: _escStyle(
        _style.footer,
        align: PosAlign.left,
        boldOverride: true,
      ),
    );

    return b;
  }

  // ─────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────
  static String _truncate(String text, int maxLen) =>
      text.length <= maxLen ? text : '${text.substring(0, maxLen - 2)}..';

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  static String _formatQty(double qty) =>
      qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();

  /// 1 → "1", 0.6 → "0.6", 1.50 → "1.5" (no trailing zeros).
  static String _formatMoney(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
  // Left-pad (right aligned) — for AMT
  static String _padL(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    return text.padLeft(width);
  }

// Date formatter for 80mm bill DATE column — returns "9-Jul" style
  static const _escMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static String _escItemDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day}-${_escMonths[dt.month - 1]}';
  }

// Right-pad (left aligned) — for ITEM NAME
  static String _padR(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    return text.padRight(width);
  }

// Center-pad — for QTY
  static String _padC(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    final totalPad = width - text.length;
    final left = totalPad ~/ 2;
    final right = totalPad - left;
    return ' ' * left + text + ' ' * right;
  }

  static String _stripKotPrice(String text) {
    return text
        .replaceAll(RegExp(r'\s*\(\+\s*\d+(?:\.\d+)?\s*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _groupKotModifiers(
    List<String> values,
    String marker,
  ) {
    final grouped = <String, List<String>>{};
    final plain = <String>[];

    for (final raw in values) {
      final clean = _stripKotPrice(raw);
      if (clean.isEmpty) continue;

      final idx = clean.indexOf(':');
      if (idx > 0) {
        final key = clean.substring(0, idx).trim();
        final value = clean.substring(idx + 1).trim();
        if (value.isEmpty) continue;
        grouped.putIfAbsent(key, () => []).add(value);
      } else {
        plain.add(clean);
      }
    }

    final lines = <String>[];

    grouped.forEach((key, vals) {
      lines.add('$marker $key: ${vals.join(', ')}');
    });

    for (final p in plain) {
      lines.add('$marker $p');
    }

    return lines;
  }

  static String _strikeText(String input) {
    const overlay = '\u0336';
    return input.split('').map((ch) => '$ch$overlay').join();
  }

  static List<String> _wrapText(String text, int width) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return [''];

    final words = clean.split(' ');
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      if (current.isEmpty) {
        if (word.length <= width) {
          current = word;
        } else {
          for (int i = 0; i < word.length; i += width) {
            lines.add(word.substring(
                i, i + width > word.length ? word.length : i + width));
          }
        }
      } else if ((current.length + 1 + word.length) <= width) {
        current = '$current $word';
      } else {
        lines.add(current);
        if (word.length <= width) {
          current = word;
        } else {
          for (int i = 0; i < word.length; i += width) {
            final part = word.substring(
                i, i + width > word.length ? word.length : i + width);
            if (part.length == width) {
              lines.add(part);
            } else {
              current = part;
            }
          }
        }
      }
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }

    return lines;
  }

  static List<String> _wrapIndented(
      String text, int firstWidth, int nextWidth, String indent) {
    final wrapped = _wrapText(text, firstWidth);
    if (wrapped.isEmpty) return [''];

    final lines = <String>[wrapped.first];
    for (int i = 1; i < wrapped.length; i++) {
      final extra = _wrapText(wrapped[i], nextWidth);
      for (final line in extra) {
        lines.add('$indent$line');
      }
    }
    return lines;
  }

  static List<String> _buildWrapped3ColRow(
    String left,
    String center,
    String right,
  ) {
    final leftWidth = _width ~/ 3;
    final centerWidth = _width ~/ 3;
    final rightWidth = _width - leftWidth - centerWidth;

    final leftLines = _wrapText(left, leftWidth);
    final centerLines = _wrapText(center, centerWidth);
    final rightLines = _wrapText(right, rightWidth);

    final maxLines = [
      leftLines.length,
      centerLines.length,
      rightLines.length,
    ].reduce((a, b) => a > b ? a : b);

    final rows = <String>[];

    for (int i = 0; i < maxLines; i++) {
      final l = i < leftLines.length ? leftLines[i] : '';
      final c = i < centerLines.length ? centerLines[i] : '';
      final r = i < rightLines.length ? rightLines[i] : '';

      rows.add(
        _padR(l, leftWidth) + _padC(c, centerWidth) + _padL(r, rightWidth),
      );
    }

    return rows;
  }

  static int get _titleWidth => (_width / 2).floor();

  static List<String> _wrapTitle(String text) {
    return _wrapText(text.trim(), _titleWidth);
  }
}
