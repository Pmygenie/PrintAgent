import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart' show FontWeight, TextAlign;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printer_agent/core/models/print_style_config.dart';
import 'package:printer_agent/core/printer/receipt_text_renderer.dart';
import 'package:printer_agent/core/services/print_style_service.dart';
import 'package:printing/printing.dart';
import 'package:printer_agent/core/profile/restaurant_profile_model.dart';
import 'package:printer_agent/core/profile/restaurant_profile_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/print_config.dart';
import '../config/app_constants.dart';
import '../models/order_item.dart';
import '../models/print_job.dart';
import '../models/restaurant_order.dart';

class PdfFormatter {
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static late PrintStyleConfig _style;

  static double _fontSize(PrintStyleItem item) {
    return _is80mm ? item.size80 : item.size58;
  }

  static Future<void> _ensureFonts() async {
    _regularFont = null;
    _boldFont = null;

    // _regularFont ??= pw.Font.ttf(
    //   await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    // );
    // _boldFont ??= pw.Font.ttf(
    //   await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    // );

    switch (_style.fontFamily) {
      case 'Roboto':
        _regularFont = await PdfGoogleFonts.robotoRegular();
        _boldFont = await PdfGoogleFonts.robotoBold();
        break;
      case 'Poppins':
        _regularFont = await PdfGoogleFonts.poppinsRegular();
        _boldFont = await PdfGoogleFonts.poppinsBold();
        break;
      case 'Ubuntu':
        _regularFont = await PdfGoogleFonts.ubuntuRegular();
        _boldFont = await PdfGoogleFonts.ubuntuBold();
        break;
      case 'Open Sans':
        _regularFont = await PdfGoogleFonts.openSansRegular();
        _boldFont = await PdfGoogleFonts.openSansBold();
        break;
      case 'Lato':
        _regularFont = await PdfGoogleFonts.latoRegular();
        _boldFont = await PdfGoogleFonts.latoBold();
        break;
      case 'Oswald':
        _regularFont = await PdfGoogleFonts.oswaldRegular();
        _boldFont = await PdfGoogleFonts.oswaldBold();
        break;
      case 'Helvetica (Sans Serif)':
        _regularFont = pw.Font.helvetica();
        _boldFont = pw.Font.helveticaBold();
        break;
      case 'Times New Roman':
        _regularFont = pw.Font.times();
        _boldFont = pw.Font.timesBold();
        break;
      case 'Courier':
        _regularFont = pw.Font.courier();
        _boldFont = pw.Font.courierBold();
        break;
      case 'Gujarati':
     _regularFont = await PdfGoogleFonts.hindVadodaraRegular();
_boldFont = await PdfGoogleFonts.hindVadodaraBold();
        break;
      case 'Montserrat':
      default:
        _regularFont = await PdfGoogleFonts.montserratRegular();
        _boldFont = await PdfGoogleFonts.montserratBold();
        break;
    }
  }

  static Future<Uint8List> format(PrintJob job) async {
    _style = await PrintStyleService.getConfig();
    await _ensureFonts();
    ReceiptTextRenderer.clearCache();

    final pdf = pw.Document();

    switch (job.type) {
      case PrintType.kot:
        pdf.addPage(await _buildKotPage(job.order, job.stationLabel));
        break;

      case PrintType.cancelKot:
        pdf.addPage(await _buildCancelKotPage(job.order, job.stationLabel));
        break;

      case PrintType.bill:
        final restaurantProfile = await RestaurantProfileService.getProfile();
        final logoImage = await _fetchLogoImage(restaurantProfile);
        final isAggregator = job.order.billData['is_aggregator'] == true;
        final upiQrImage = (!isAggregator &&
                PrintConfig.upiQrEnabled &&
                PrintConfig.upiId.trim().isNotEmpty)
            ? await _generateQrImage(
                PrintConfig.upiQrDataForBill(job.order.billData))
            : null;
        final feedbackQrImage = (!isAggregator && PrintConfig.feedbackQrEnabled)
            ? await _generateQrImage(
                PrintConfig.feedbackQrData(job.order.orderId))
            : null;
        pdf.addPage(await _buildBillPage(job.order, restaurantProfile,
            logoImage, upiQrImage, feedbackQrImage));
        break;
    }

    return pdf.save();
  }

  /// Proof-of-concept PDF: English via [pw.Text], Gujarati conjunct via image.
  // static Future<Uint8List> generateGujaratiPocPdf() async {
  //   ReceiptTextRenderer.clearCache();
  //   final pdf = pw.Document();

  //   final chops = await ReceiptTextRenderer.buildReceiptText(
  //     'ચોપ્સ',
  //     fontSize: 14,
  //     fontWeight: FontWeight.bold,
  //     textAlign: TextAlign.left,
  //     pdfStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
  //     maxWidth: 140,
  //   );

  //   final mixed = await ReceiptTextRenderer.buildReceiptText(
  //     'Burger - ચોપ્સ',
  //     fontSize: 12,
  //     fontWeight: FontWeight.normal,
  //     textAlign: TextAlign.left,
  //     pdfStyle: pw.TextStyle(fontSize: 12),
  //     maxWidth: 140,
  //   );

  //   pdf.addPage(
  //     pw.Page(
  //       pageFormat: PdfPageFormat.roll57,
  //       build: (_) => pw.Column(
  //         crossAxisAlignment: pw.CrossAxisAlignment.start,
  //         children: [
  //           pw.Text('POC — Gujarati image vs pw.Text',
  //               style: pw.TextStyle(
  //                   fontSize: 10, fontWeight: pw.FontWeight.bold)),
  //           pw.SizedBox(height: 8),
  //           pw.Text('Burger', style: const pw.TextStyle(fontSize: 14)),
  //           pw.SizedBox(height: 8),
  //           chops,
  //           pw.SizedBox(height: 8),
  //           mixed,
  //         ],
  //       ),
  //     ),
  //   );

  //   return pdf.save();
  // }

  // ── Logo fetch ────────────────────────────────────────────────────
  /// Resolves a logo path to a full URL (handles both absolute and relative).
  static String _resolveLogoUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = AppConstants.apiUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/$path';
  }

  /// Downloads the logo and returns a [pw.MemoryImage], or null on failure.
  static Future<pw.MemoryImage?> _fetchLogoImage(
      RestaurantProfileModel profile) async {
    final rawPath =
        profile.billLogo.isNotEmpty ? profile.billLogo : profile.restaurantLogo;
    final url = _resolveLogoUrl(rawPath);
    if (url.isEmpty) return null;
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(res.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  // ── QR code generation ───────────────────────────────────────────
  /// Rasterises [data] to a 300×300 PNG for embedding via [pw.MemoryImage].
  /// Returns null if the payload can't be encoded (e.g. too long).
  static Future<pw.MemoryImage?> _generateQrImage(String data) async {
    if (data.trim().isEmpty) return null;
    try {
      final validation = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );
      if (validation.status != QrValidationStatus.valid ||
          validation.qrCode == null) {
        return null;
      }
      final painter = QrPainter.withQr(
        qr: validation.qrCode!,
        gapless: true,
      );
      final imageData = await painter.toImageData(300);
      if (imageData == null) return null;
      return pw.MemoryImage(imageData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // CORE LAYOUT ENGINE
  // ═══════════════════════════════════════════════════════════════════

  static bool get _is80mm => PrintConfig.is80mm;

  /// Usable content width in PDF points (page width minus margins).
  static double get _contentWidthPt {
    final widthMm = _is80mm ? 72.0 : 48.0;
    return widthMm * PdfPageFormat.mm -
        _style.marginLeftMm * PdfPageFormat.mm -
        _style.marginRightMm * PdfPageFormat.mm;
  }

  /// Bill ITEM column (flex 6 of 15, or 5 of 17 with date).
  static double get _billItemNameMaxWidth {
    final withDate = _is80mm && PrintConfig.showItemDateOn80mm;
    final nameFlex = withDate ? 5 : 6;
    final totalFlex = withDate ? 17 : 15;
    // Extra safety on 80mm — long Gujarati names were skewing QTY/PRICE/AMT
    final pad = _is80mm ? 4.0 : 2.0;
    return (_contentWidthPt * nameFlex / totalFlex) - pad;
  }

  /// KOT item name column (flex 7 of 10 → SR:ITEM:QTY = 1:7:2).
  static double get _kotItemNameMaxWidth =>
      (_contentWidthPt * 7 / 10) - 2;

  static double get _billMetaMaxWidth =>
      _contentWidthPt - (_is80mm ? 5.0 : 6.0) - 2;

  static double get _kotMetaMaxWidth =>
      _contentWidthPt - (_is80mm ? 20.0 : 8.0) - 2;

  /// Page format with configurable margins.
  /// Height is infinite — thermal printers cut at content end.
  static PdfPageFormat get _pageFormat {
    final widthMm = _is80mm ? 72.0 : 48.0;
    log('widthMm $widthMm');

    return PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      800,
      marginLeft: _style.marginLeftMm * PdfPageFormat.mm,
      marginRight: _style.marginRightMm * PdfPageFormat.mm,
      marginTop: _style.marginTopMm * PdfPageFormat.mm,
      marginBottom: _style.marginBottomMm * PdfPageFormat.mm,
    );
  }

  // ─── Item date formatter ──────────────────────────────────────────
  // Returns "9-Jul" style — used in 80mm bill DATE column only.
  static const _months = [
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
  static String _itemDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day}-${_months[dt.month - 1]}';
  }

  // ─── Responsive font sizes ────────────────────────────────────────

  static double get _titleSize => _is80mm ? 14 : 11;

  // ─── Responsive font sizes (Dynamically mapped to PrintStyleConfig) ───

  static double get _restuarantNameSize => _fontSize(_style.restaurantName);
  static bool get _restuarantNameBold => _style.restaurantName.isBold;

  static double get _restuarantAddressSize =>
      _fontSize(_style.restaurantAddress);
  static bool get _restuarantAddressBold => _style.restaurantAddress.isBold;

  static double get _restuarantPhoneSize => _fontSize(_style.restaurantPhone);
  static bool get _restuarantPhoneBold => _style.restaurantPhone.isBold;

  static double get _restuarantGstSize => _fontSize(_style.restaurantGst);
  static bool get _restuarantGstBold => _style.restaurantGst.isBold;

  static double get _restuarantFssaiSize => _fontSize(_style.restaurantFssai);
  static bool get _restuarantFssaiBold => _style.restaurantFssai.isBold;

  static double get _billInfo1strowSize => _fontSize(_style.billInfoRow1);
  static bool get _billInfo1strowBold => _style.billInfoRow1.isBold;

  static double get _billInfo2ndrowSize => _fontSize(_style.billInfoRow2);
  static bool get _billInfo2ndrowBold => _style.billInfoRow2.isBold;

  static double get _billInfo3rdrowSize => _fontSize(_style.billInfoRow3);
  static bool get _billInfo3rdrowBold => _style.billInfoRow3.isBold;

  static double get _billInfo4throwSize => _fontSize(_style.billInfoRow4);
  static bool get _billInfo4throwBold => _style.billInfoRow4.isBold;

  static double get _orderNoteSize => _fontSize(_style.orderNote);
  static bool get _orderNoteBold => _style.orderNote.isBold;

  static double get _billMetaTextSize => _fontSize(_style.billTableMeta);

  static double get _billTableHeaderTextSize =>
      _fontSize(_style.billTableHeader);
  static bool get _billTableHeaderTextBold => _style.billTableHeader.isBold;

  static double get _billTableContentTextSize =>
      _fontSize(_style.billTableContent);
  static bool get _billTableContentTextBold => _style.billTableContent.isBold;
  static double get _billTableQtyTextSize => _fontSize(_style.billTableQty);
  static bool get _billTableQtyTextBold => _style.billTableQty.isBold;
  static double get _billTableContentMetaTextSize =>
      _fontSize(_style.billTableMeta);
  static bool get _billTableContentMetaTextBold => _style.billTableMeta.isBold;

  static double get _billAmountLineTextSize => _fontSize(_style.billAmountLine);
  static bool get _billAmountLineTextBold => _style.billAmountLine.isBold;

  static double get _billTotalTextSize => _fontSize(_style.billTotal);
  static bool get _billTotalTextBold => _style.billTotal.isBold;

  static double get _billGrandTotalTextSize => _fontSize(_style.billGrandTotal);
  static bool get _billGrandTotalTextBold => _style.billGrandTotal.isBold;

  static double get _billPaidByTextSize => _fontSize(_style.billPaidBy);
  static bool get _billPaidByTextBold => _style.billPaidBy.isBold;

  static double get _deliveryDetailTextSize =>
      _fontSize(_style.deliveryContent);
  static bool get _deliveryDetailTextBold => _style.deliveryContent.isBold;

  static double get _deliveryDetailHeaderSize =>
      _fontSize(_style.deliveryHeader);
  static bool get _deliveryDetailHeaderBold => _style.deliveryHeader.isBold;

  static double get _roomAssociatedTextSize => _fontSize(_style.roomContent);
  static bool get _roomAssociatedTextBold => _style.roomContent.isBold;

  static double get _roomAssociatedHeaderTextSize =>
      _fontSize(_style.roomHeader);
  static bool get _roomAssociatedHeaderTextBold => _style.roomHeader.isBold;

  static bool get _simpleDividerOrDotted => _style.dividerStyle == 'Solid';

  static double get _kotNameSize => _fontSize(_style.kotTitle);
  static bool get _kotNameBold => _style.kotTitle.isBold;

  static double get _cancelKotNameSize => _fontSize(_style.cancelKotTitle);
  static bool get _cancelKotNameBold => _style.cancelKotTitle.isBold;

  static double get _kotOrderInfo1stRowTextSize =>
      _fontSize(_style.kotOrderInfo1);
  static bool get _kotOrderInfo1stRowTextBold => _style.kotOrderInfo1.isBold;

  static double get _kotOrderInfo2ndRowTextSize =>
      _fontSize(_style.kotOrderInfo2);
  static bool get _kotOrderInfo2ndRowTextBold => _style.kotOrderInfo2.isBold;

  static double get _kotOrderInfo3rdRowTextSize =>
      _fontSize(_style.kotOrderInfo3);
  static bool get _kotOrderInfo3rdRowTextBold => _style.kotOrderInfo3.isBold;

  static double get _kotOrderInfo4thRowTextSize =>
      _fontSize(_style.kotOrderInfo4);
  static bool get _kotOrderInfo4thRowTextBold => _style.kotOrderInfo4.isBold;

  static double get _kotTableHeaderTextSize => _fontSize(_style.kotTableHeader);
  static bool get _kotTableHeaderTextBold => _style.kotTableHeader.isBold;

  static double get _kotTableContentTextSize =>
      _fontSize(_style.kotTableContent);
  static bool get _kotTableContentTextBold => _style.kotTableContent.isBold;

  static double get _kotOrderNoteTextSize => _fontSize(_style.kotNote);
  static bool get _kotOrderNoteTextBold => _style.kotNote.isBold;

  static double get _footerSize => _fontSize(_style.footer);
  static bool get _footerBold => _style.footer.isBold;

  /// Wrap character limit per column in three-column rows.
  /// Mirrors EscPos: 80mm=48 total→16/col, 58mm=32 total→10/col.
  static int get _wrapCharsPerCol => _is80mm ? 20 : 18;

  // ─── Text style factory (unchanged API) ───────────────────────────

  static pw.TextStyle _text({
    double size = 10,
    bool bold = false,
  }) {
    return pw.TextStyle(
      font: bold ? _boldFont : _regularFont,
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // KOT PAGE
  // ═══════════════════════════════════════════════════════════════════

  static Future<pw.Page> _buildKotPage(
      RestaurantOrder o, String? stationLabel) async {
    final station = stationLabel?.trim().toUpperCase() ?? '';
    final title = station.isNotEmpty ? 'KOT [ $station ]' : 'KOT';

    final customerName = (o.userCustName ?? '').trim();
    final customerPhone = (o.userCustPhone ?? '').trim();
    final itemRows = await _kotItems(o);

    return pw.Page(
      pageFormat: _pageFormat,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.SizedBox(
            width: double.infinity,
            child: pw.Text(
              title,
              style: _text(size: _kotNameSize, bold: _kotNameBold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          _divider(),
          _threeColRow(
            'Order No:#${o.displayOrderId}',
            o.waiterName,
            _formatDate(o.receivedAt),
            bold: _kotOrderInfo1stRowTextBold,
            fontSize: _kotOrderInfo1stRowTextSize,
          ),
          if (_centerLabel(o).isNotEmpty)
            _threeColRow('', _centerLabel(o), '',
                bold: _kotOrderInfo2ndRowTextBold,
                fontSize: _kotOrderInfo2ndRowTextSize),
          if (customerName.isNotEmpty || customerPhone.isNotEmpty)
            _threeColRow(customerName, '', customerPhone,
                bold: _kotOrderInfo3rdRowTextBold,
                fontSize: _kotOrderInfo3rdRowTextSize),
          if (o.dailyToken.isNotEmpty)
            _threeColRow('', 'T-${o.dailyToken}', '',
                bold: _kotOrderInfo4thRowTextBold,
                fontSize: _kotOrderInfo4thRowTextSize),
          _simpleDividerOrDotted
              ? _divider(dashed: true)
              : buildDottedLine(180),
          _kotHeader(),
          _simpleDividerOrDotted
              ? _divider(dashed: true)
              : buildDottedLine(180),
          ...itemRows,
          if (o.orderNote.trim().isNotEmpty) ...[
            _simpleDividerOrDotted
                ? _divider(dashed: true)
                : buildDottedLine(180),
            pw.Text(
              'Note : ${o.orderNote.trim()}',
              style: _text(
                  size: _kotOrderNoteTextSize, bold: _kotOrderNoteTextBold),
            ),
          ],
          _divider(),
          pw.Center(
            child: pw.Text(
              'Powered by MyGenie',
              style: _text(size: _footerSize, bold: _footerBold),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CANCEL KOT PAGE
  // ═══════════════════════════════════════════════════════════════════

  static Future<pw.Page> _buildCancelKotPage(
      RestaurantOrder o, String? stationLabel) async {
    final station = stationLabel?.trim().toUpperCase() ?? '';
    final title = station.isNotEmpty ? 'CANCEL KOT [ $station ]' : 'CANCEL';

    final customerName = (o.userCustName ?? '').trim();
    final customerPhone = (o.userCustPhone ?? '').trim();
    final itemRows = await _cancelKotItems(o);

    return pw.Page(
      pageFormat: _pageFormat,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.SizedBox(
            width: double.infinity,
            child: pw.Text(
              title,
              style: _text(size: _cancelKotNameSize, bold: _cancelKotNameBold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          _divider(),
          _threeColRow(
            'Order No:#${o.displayOrderId}',
            o.waiterName,
            _formatDate(o.receivedAt),
            bold: _kotOrderInfo1stRowTextBold,
            fontSize: _kotOrderInfo1stRowTextSize,
          ),
          if (_centerLabel(o).isNotEmpty)
            _threeColRow('', _centerLabel(o), '',
                bold: _kotOrderInfo2ndRowTextBold,
                fontSize: _kotOrderInfo2ndRowTextSize),
          if (customerName.isNotEmpty || customerPhone.isNotEmpty)
            _threeColRow(customerName, '', customerPhone,
                bold: _kotOrderInfo3rdRowTextBold,
                fontSize: _kotOrderInfo3rdRowTextSize),
          if (o.dailyToken.isNotEmpty)
            _threeColRow('', 'T-${o.dailyToken}', '',
                bold: _kotOrderInfo4thRowTextBold,
                fontSize: _kotOrderInfo4thRowTextSize),
          _simpleDividerOrDotted
              ? _divider(dashed: true)
              : buildDottedLine(180),
          _kotHeader(),
          _simpleDividerOrDotted
              ? _divider(dashed: true)
              : buildDottedLine(180),
          ...itemRows,
          _divider(),
          pw.Center(
            child: pw.Text(
              'Powered by MyGenie',
              style: _text(size: _footerSize, bold: _footerBold),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BILL PAGE
  // ═══════════════════════════════════════════════════════════════════

  static Future<pw.MultiPage> _buildBillPage(
    RestaurantOrder o,
    RestaurantProfileModel profile,
    pw.MemoryImage? logoImage,
    pw.MemoryImage? upiQrImage,
    pw.MemoryImage? feedbackQrImage,
  ) async {
    final bill = o.billData;
    final itemRows = await _billItems(o);

    double d(String key) =>
        double.tryParse(bill[key]?.toString() ?? '0') ?? 0.0;

    final restaurantName = profile.restaurantName.isNotEmpty
        ? profile.restaurantName
        : o.restaurantName;
    final restaurantAddress = profile.restaurantAddress;
    final restaurantPhone = profile.restaurantPhone;
    final restaurantGstNo = profile.gstCode;
    final restaurantFssai = profile.fssai;

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

    final itemTotal = d('order_item_total');
    final serviceCharge = d('service_charge_amount');
    final deliveryCharge = d('delivery_charge');
    final tip = d('tip_amount');
    final subTotal = d('order_subtotal');
    final gstTax = d('gst_tax');
    final vatTax = d('vat_tax');
    final packingCharge = d('packing_charge');
    final grantAmount = d('grant_amount');
    final paymentAmount = d('payment_amount');
    final roomAdvance = d('room_advance_pay');
    final roomPending = d('room_remaining_pay');
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
        return 'Unpaid';
      }
      final method = paymentMethod.isNotEmpty
          ? paymentMethod[0].toUpperCase() + paymentMethod.substring(1)
          : '';
      return 'Paid by $method';
    }

    final totalAmount = isRoomOrder ? paymentAmount : grantAmount;
    // final totalLabel = isRoomOrder ? 'TOTAL' : 'TOTAL ${payLabel()}';
    final totalLabel = isRoomOrder ? 'TOTAL' : 'TOTAL';

    return pw.MultiPage(
      pageFormat: _pageFormat,
      build: (_) => [
        // ── Logo ──
        if (logoImage != null) ...[
          pw.Center(
            child: pw.Image(
              logoImage,
              width: _style.logoWidthMm * PdfPageFormat.mm,
              height: _style.logoHeightMm * PdfPageFormat.mm,
              fit: pw.BoxFit.contain,
            ),
          ),
          pw.SizedBox(height: 4),
        ],
        // ── Restaurant header ──
        pw.SizedBox(
          width: double.infinity,
          child: pw.Text(
            restaurantName.toUpperCase(),
            style: _text(size: _restuarantNameSize, bold: _restuarantNameBold),
            textAlign: pw.TextAlign.center,
          ),
        ),
        if (restaurantAddress.isNotEmpty)
          pw.Center(
            child: pw.Text(
              restaurantAddress,
              style: _text(
                  size: _restuarantAddressSize, bold: _restuarantAddressBold),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (restaurantPhone.isNotEmpty)
          pw.Center(
            child: pw.Text(
              'Ph: $restaurantPhone',
              style:
                  _text(size: _restuarantPhoneSize, bold: _restuarantPhoneBold),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (restaurantGstNo.isNotEmpty)
          pw.Center(
            child: pw.Text(
              'GST No: $restaurantGstNo',
              style: _text(size: _restuarantGstSize, bold: _restuarantGstBold),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (restaurantFssai.isNotEmpty)
          pw.Center(
            child: pw.Text(
              'Fssai No: $restaurantFssai',
              style:
                  _text(size: _restuarantFssaiSize, bold: _restuarantFssaiBold),
              textAlign: pw.TextAlign.center,
            ),
          ),

        // ── Bill info ──
        _divider(),
        ..._threeColRowWidgets('Bill NO. ${o.displayOrderId}', waiterName,
            _formatDate(o.receivedAt),
            bold: _billInfo1strowBold, fontsize: _billInfo1strowSize),
        if (custName.isNotEmpty ||
            centerLabel().isNotEmpty ||
            custPhone.isNotEmpty)
          ..._threeColRowWidgets(custName, centerLabel(), custPhone,
              bold: _billInfo2ndrowBold, fontsize: _billInfo2ndrowSize),
        if (custGstName.isNotEmpty || custGstNumber.isNotEmpty)
          ..._threeColRowWidgets(custGstName, '', custGstNumber,
              bold: _billInfo3rdrowBold, fontsize: _billInfo3rdrowSize),
        if (o.dailyToken.isNotEmpty)
          ..._threeColRowWidgets('', 'T-${o.dailyToken}', '',
              bold: _billInfo4throwBold, fontsize: _billInfo4throwSize),

        // ── Item table ──
        _simpleDividerOrDotted ? _divider(dashed: true) : buildDottedLine(180),
        ..._billTableHeader(),
        _simpleDividerOrDotted ? _divider(dashed: true) : buildDottedLine(180),
        ...itemRows,

        // ── Order note ──
        if (orderNote.isNotEmpty) ...[
          _simpleDividerOrDotted
              ? _divider(dashed: true)
              : buildDottedLine(180),
          pw.Text(
            'Note : $orderNote',
            style: _text(size: _orderNoteSize, bold: _orderNoteBold),
            textAlign: pw.TextAlign.center,
          ),
        ],

        // ── Price breakdown ──
        _simpleDividerOrDotted ? _divider() : buildDottedLine(180),

        ..._billAmountLineWidgets('Item Total', itemTotal.toStringAsFixed(2)),
        if (serviceCharge > 0)
          ..._billAmountLineWidgets(
            'Service Charge',
            serviceCharge.toStringAsFixed(2),
          ),
        if (deliveryCharge > 0)
          ..._billAmountLineWidgets(
            'Delivery Charge',
            deliveryCharge.toStringAsFixed(2),
          ),
        if (discountAmount > 0)
          ..._billAmountLineWidgets('Discount', discountAmount.toString()),
        if (packingCharge > 0)
          ..._billAmountLineWidgets(
            'Packing Charge',
            packingCharge.toStringAsFixed(2),
          ),
        if (couponCode.isNotEmpty)
          ..._billAmountLineWidgets('Coupon Code', couponCode),
        if (loyaltyAmount > 0)
          ..._billAmountLineWidgets('Loyalty', loyaltyAmount.toString()),
        if (walletAmount > 0)
          ..._billAmountLineWidgets('Wallet', walletAmount.toString()),
        if (tip > 0) ..._billAmountLineWidgets('Tip', tip.toStringAsFixed(2)),
        if (!isAggregator)
          ..._billAmountLineWidgets('Sub Total', subTotal.toStringAsFixed(2)),
        if (gstTax > 0) ...[
          if (isAggregator)
            ..._billAmountLineWidgets('Total Tax', gstTax.toStringAsFixed(2))
          else ...[
            ..._billAmountLineWidgets('CGST', (gstTax / 2).toStringAsFixed(2)),
            ..._billAmountLineWidgets('SGST', (gstTax / 2).toStringAsFixed(2)),
          ],
        ],
        if (vatTax > 0)
          ..._billAmountLineWidgets('VAT', vatTax.toStringAsFixed(2)),

        // ── Total ──
        _simpleDividerOrDotted ? _divider(dashed: true) : buildDottedLine(180),

        ..._billTotalRow(totalLabel, _formatMoney(totalAmount),
            _billTotalTextSize, _billTotalTextBold,
            subLabel: isAggregator ? null : payLabel()),

        // ── Delivery details ──
        if (bill['order_type']?.toString() == 'delivery' && !isAggregator) ...[
          _simpleDividerOrDotted
              ? _divider(dashed: true)
              : buildDottedLine(180),
          pw.Center(
            child: pw.Text(
              '-- Delivery Details --',
              style: _text(
                  size: _deliveryDetailHeaderSize,
                  bold: _deliveryDetailHeaderBold),
            ),
          ),
          _simpleDividerOrDotted
              ? _divider(dashed: true)
              : buildDottedLine(180),
          ..._deliveryDetailsWidgets(bill),
        ],

        // ── Room order details ──
        if (isRoomOrder) ...[
          _simpleDividerOrDotted
              ? _divider(dashed: true)
              : buildDottedLine(180),
          pw.Center(
            child: pw.Text(
              '-- Previous Room Bill --',
              style: _text(
                  size: _roomAssociatedHeaderTextSize,
                  bold: _roomAssociatedHeaderTextBold),
            ),
          ),
          _simpleDividerOrDotted
              ? _divider(dashed: true)
              : buildDottedLine(180),
          ..._roomOrderWidgets(
            associatedOrders,
            roomAdvance,
            roomPending,
            grantAmount,
            payLabel(),
          ),
        ],

        // ── QR codes — bill only, never on aggregator orders ──
        if (upiQrImage != null) ...[
          _simpleDividerOrDotted ? _divider(dashed: true) : buildDottedLine(180),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Image(upiQrImage,
                width: _style.upiQrSizeMm * PdfPageFormat.mm,
                height: _style.upiQrSizeMm * PdfPageFormat.mm),
          ),
          pw.Center(
            child: pw.Text('Scan to Pay',
                style: _text(size: _footerSize, bold: _footerBold)),
          ),
        ],
        if (feedbackQrImage != null) ...[
          _simpleDividerOrDotted ? _divider(dashed: true) : buildDottedLine(180),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Image(feedbackQrImage,
                width: _style.feedbackQrSizeMm * PdfPageFormat.mm,
                height: _style.feedbackQrSizeMm * PdfPageFormat.mm),
          ),
          pw.Center(
            child: pw.Text('Scan for Feedback',
                style: _text(size: _footerSize, bold: _footerBold)),
          ),
        ],

        // ── Footer ──
        _divider(),

        if (profile.footerText.isNotEmpty) ...[
          pw.SizedBox(
            width: double.infinity,
            child: pw.Text(
              profile.footerText,
              style: _text(size: _footerSize, bold: _footerBold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(
              height: 4), // ← spacing between footer text and "Powered by"
        ],

        pw.Center(
          child: pw.Text(
            'Powered by MyGenie',
            style: _text(size: _footerSize, bold: _footerBold),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARED LAYOUT HELPERS
  // ═══════════════════════════════════════════════════════════════════

  static String _centerLabel(RestaurantOrder o) {
    final type = o.orderType.trim().toLowerCase();
    final table = (o.tableName ?? '').trim();
    if (type == 'pos' || type == 'dinein') {
      return table.isNotEmpty ? table.toUpperCase() : 'WC';
    }
    return o.orderType.trim().replaceAll('_', ' ').toUpperCase();
  }

  // ─── Divider (Container border — always fills exact width) ────────

  static pw.Widget _divider({bool dashed = false}) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            width: dashed ? 0.5 : 1.0,
            color: PdfColors.black,
          ),
        ),
      ),
    );
  }

  static pw.Widget buildDottedLine(double totalWidth) {
    const double dashWidth = 5;
    const double dashSpace = 3;
    double startX = 0;
    List<pw.Widget> dashes = [];

    while (startX < 250) {
      dashes.add(
        pw.Container(
          width: dashWidth,
          height: 1,
          color: PdfColors.black,
        ),
      );
      startX += dashWidth + dashSpace;

      if (startX < 200) {
        dashes.add(pw.SizedBox(width: dashSpace));
      }
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(children: dashes),
    );
  }

  // ─── Three-column row (simple, wraps naturally via Expanded) ──────

  static pw.Widget _threeColRow(
    String left,
    String center,
    String right, {
    bool bold = false,
    double? fontSize,
  }) {
    final style = _text(size: fontSize ?? _billMetaTextSize, bold: bold);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Text(left, style: style),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            center,
            style: style,
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Expanded(
          flex: 5,
          child: pw.Text(
            right,
            style: style,
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ─── Three-column row with manual wrapping (for Bill info) ────────

  static List<pw.Widget> _threeColRowWidgets(
    String left,
    String center,
    String right, {
    bool bold = false,
    double? fontsize,
  }) {
    final wrapChars = _wrapCharsPerCol;

    final leftLines = _wrapText(left, wrapChars);
    final centerLines = _wrapText(center, wrapChars);
    final rightLines = _wrapText(right, wrapChars);

    final maxLines = [
      leftLines.length,
      centerLines.length,
      rightLines.length,
    ].reduce((a, b) => a > b ? a : b);

    final style = _text(size: fontsize ?? 7, bold: bold);
    final rows = <pw.Widget>[];

    for (int i = 0; i < maxLines; i++) {
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Text(
                i < leftLines.length ? leftLines[i] : '',
                style: style,
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                i < centerLines.length ? centerLines[i] : '',
                style: style,
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Expanded(
              flex: 5,
              child: pw.Text(
                i < rightLines.length ? rightLines[i] : '',
                style: style,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    return rows;
  }

  // ═══════════════════════════════════════════════════════════════════
  // KOT TABLE (flex-based — SR:ITEM:QTY = 1:7:2)
  // ═══════════════════════════════════════════════════════════════════

  static pw.Widget _kotHeader() {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 1,
          child: pw.Text(
            'SR',
            textAlign: pw.TextAlign.center,
            style: _text(
                size: _kotTableHeaderTextSize, bold: _kotTableHeaderTextBold),
          ),
        ),
        pw.Expanded(
          flex: 7,
          child: pw.Text(
            'ITEM',
            style: _text(
                size: _kotTableHeaderTextSize, bold: _kotTableHeaderTextBold),
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            'QTY',
            textAlign: pw.TextAlign.right,
            style: _text(
                size: _kotTableHeaderTextSize, bold: _kotTableHeaderTextBold),
          ),
        ),
        // pw.Expanded(
        //   flex: 1,
        //   child: pw.Text(
        //     '',
        //   ),
        // ),
      ],
    );
  }

  static Future<List<pw.Widget>> _kotItems(RestaurantOrder o) async {
    final rows = <pw.Widget>[];
    int sr = 1;
    final indentLeft = _is80mm ? 20.0 : 8.0;
    final contentStyle = _text(
        size: _kotTableContentTextSize, bold: _kotTableContentTextBold);

    for (final item in o.items) {
      if (item.foodStatus == 3) continue;

      final qtyDisplay = item.itemUnit.isNotEmpty
          ? '${_formatQty(item.quantity)}${item.itemUnit}'
          : _formatQty(item.quantity);

      final nameWidget = await ReceiptTextRenderer.buildReceiptText(
        item.name.trim(),
        fontSize: _kotTableContentTextSize,
        fontWeight: _kotTableContentTextBold
            ? FontWeight.bold
            : FontWeight.normal,
        pdfStyle: contentStyle,
        maxWidth: _kotItemNameMaxWidth,
      );

      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 1,
              child: pw.Text(
                '${sr++}.',
                textAlign: pw.TextAlign.center,
                style: contentStyle,
              ),
            ),
            pw.Expanded(
              flex: 7,
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: nameWidget,
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                qtyDisplay,
                textAlign: pw.TextAlign.right,
                style: contentStyle,
              ),
            ),
          ],
        ),
      );

      if (item.variations.isNotEmpty) {
        for (final v in item.variations) {
          rows.add(
            pw.Padding(
              padding: pw.EdgeInsets.only(left: indentLeft, top: 0),
              child: await ReceiptTextRenderer.buildReceiptText(
                ' - ${_stripKotPrice(v)}',
                fontSize: _kotTableContentTextSize,
                fontWeight: _kotTableContentTextBold
                    ? FontWeight.bold
                    : FontWeight.normal,
                pdfStyle: contentStyle,
                maxWidth: _kotMetaMaxWidth,
              ),
            ),
          );
        }
      }

      if (item.addons.isNotEmpty) {
        for (final a in item.addons) {
          rows.add(
            pw.Padding(
              padding: pw.EdgeInsets.only(left: indentLeft, top: 0),
              child: await ReceiptTextRenderer.buildReceiptText(
                ' + ${_stripKotPrice(a)}',
                fontSize: _kotTableContentTextSize,
                fontWeight: _kotTableContentTextBold
                    ? FontWeight.bold
                    : FontWeight.normal,
                pdfStyle: contentStyle,
                maxWidth: _kotMetaMaxWidth,
              ),
            ),
          );
        }
      }

      if (item.note.trim().isNotEmpty) {
        rows.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(left: indentLeft, top: 0),
            child: pw.Text(
              ' Note: ${item.note.trim()}',
              style: contentStyle,
            ),
          ),
        );
      }

      rows.add(pw.SizedBox(height: 2));
    }

    return rows;
  }

  static Future<List<pw.Widget>> _cancelKotItems(RestaurantOrder o) async {
    final rows = <pw.Widget>[];
    int sr = 1;
    final indentLeft = _is80mm ? 20.0 : 8.0;
    final contentStyle = _text(
        size: _kotTableContentTextSize, bold: _kotTableContentTextBold);

    for (final item in o.items) {
      final qtyDisplay = item.itemUnit.isNotEmpty
          ? '${_formatQty(item.quantity)}${item.itemUnit}'
          : _formatQty(item.quantity);

      final nameWidget = await ReceiptTextRenderer.buildReceiptText(
        item.name.trim(),
        fontSize: _kotTableContentTextSize,
        fontWeight: _kotTableContentTextBold
            ? FontWeight.bold
            : FontWeight.normal,
        pdfStyle: contentStyle,
        maxWidth: _kotItemNameMaxWidth,
      );

      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 1,
              child: pw.Text(
                '${sr++}.',
                style: contentStyle,
              ),
            ),
            pw.Expanded(
              flex: 7,
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: nameWidget,
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                qtyDisplay,
                textAlign: pw.TextAlign.right,
                style: contentStyle,
              ),
            ),
          ],
        ),
      );

      if (item.variations.isNotEmpty) {
        for (final v in item.variations) {
          rows.add(
            pw.Padding(
              padding: pw.EdgeInsets.only(left: indentLeft, top: 2),
              child: await ReceiptTextRenderer.buildReceiptText(
                '- ${_stripKotPrice(v)}',
                fontSize: _kotTableContentTextSize,
                fontWeight: _kotTableContentTextBold
                    ? FontWeight.bold
                    : FontWeight.normal,
                pdfStyle: contentStyle,
                maxWidth: _kotMetaMaxWidth,
              ),
            ),
          );
        }
      }

      if (item.addons.isNotEmpty) {
        for (final a in item.addons) {
          rows.add(
            pw.Padding(
              padding: pw.EdgeInsets.only(left: indentLeft, top: 2),
              child: await ReceiptTextRenderer.buildReceiptText(
                '+ ${_stripKotPrice(a)}',
                fontSize: _kotTableContentTextSize,
                fontWeight: _kotTableContentTextBold
                    ? FontWeight.bold
                    : FontWeight.normal,
                pdfStyle: contentStyle,
                maxWidth: _kotMetaMaxWidth,
              ),
            ),
          );
        }
      }

      if (item.note.trim().isNotEmpty) {
        rows.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(left: indentLeft, top: 2),
            child: pw.Text(
              'Note: ${item.note.trim()}',
              style: contentStyle,
            ),
          ),
        );
      }

      rows.add(pw.SizedBox(height: 2));
    }

    return rows;
  }

  // ═══════════════════════════════════════════════════════════════════
  // BILL TABLE (flex-based — ITEM:QTY:PRICE:AMT = 6:2:2:2)
  //
  // Mirroring EscPos ratio: ~50% item, ~17% qty, ~17% price, ~17% amt
  // Expanded guarantees columns ALWAYS sum to 100% — no clipping.
  // ═══════════════════════════════════════════════════════════════════

  static List<pw.Widget> _billTableHeader() {
    final textSize = _billTableHeaderTextSize;
    final textbold = _billTableHeaderTextBold;

    return [
      pw.Row(
        children: [
          pw.Expanded(
            flex: (_is80mm && PrintConfig.showItemDateOn80mm) ? 5 : 6,
            child: pw.Text(
              'ITEM',
              style: _text(size: textSize, bold: textbold),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'QTY',
              textAlign: pw.TextAlign.center,
              style: _text(size: textSize, bold: textbold),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              PrintConfig.restaurantId == 798? 'PRICE/KG' : 'PRICE',
              textAlign: pw.TextAlign.center,
              style: _text(size: textSize, bold: textbold),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'AMT',
              textAlign: pw.TextAlign.right,
              style: _text(size: textSize, bold: textbold),
            ),
          ),
          if (_is80mm && PrintConfig.showItemDateOn80mm)
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                'DATE',
                textAlign: pw.TextAlign.right,
                style: _text(size: textSize, bold: textbold),
              ),
            ),
        ],
      ),
    ];
  }

  static Future<List<pw.Widget>> _billItems(RestaurantOrder o) async {
    final rows = <pw.Widget>[];
    final textSize = _billTableContentTextSize;
    final textbold = _billTableContentTextBold;
    final metaSize = _billTableContentMetaTextSize;
    final metaBold = _billTableContentMetaTextBold;
    final indentLeft = _is80mm ? 5.0 : 6.0;
    final contentStyle = _text(size: textSize, bold: textbold);
    final metaStyle = _text(size: metaSize, bold: metaBold);

    for (final item in OrderItem.mergedForBill(o.items)) {
      if (item.foodStatus == 3) continue;

      final isComp = item.complementary?.toString().toLowerCase() == 'yes';

      final effectivePrice =
          (item.itemUnit.isNotEmpty && item.itemUnitPrice > 0)
              ? item.itemUnitPrice
              : item.price;

      // Variation items: PRICE = base + variation (addon stays out of PRICE)
      final displayUnitPrice = item.variations.isNotEmpty
          ? effectivePrice + item.variationTotal
          : effectivePrice;
      final basePrice = isComp ? 0.0 : displayUnitPrice;

      final unitTotalPrice =
          effectivePrice + item.variationTotal + item.addonTotal;
      final amt = isComp ? 0.0 : unitTotalPrice * item.quantity;

      final displayName = isComp ? '${item.name} (Comp)' : item.name;

      final qtyDisplay = item.itemUnit.isNotEmpty
          ? '${_formatQty(item.quantity)}${item.itemUnit}'
          : _formatQty(item.quantity);

      // Restaurant 798 only: gram-based items show PRICE as per-kg
      // (display only — AMT still computed from the actual per-gram price).
      final isGramUnit798 = PrintConfig.restaurantId == 798 &&
          item.itemUnit.trim().toLowerCase() == 'gm';
      final priceDisplay = isGramUnit798
          ? '${_formatMoney(basePrice * 1000)}'
          : _formatMoney(basePrice);

      final nameWidget = await ReceiptTextRenderer.buildReceiptText(
        displayName,
        fontSize: textSize,
        fontWeight: textbold ? FontWeight.bold : FontWeight.normal,
        pdfStyle: contentStyle,
        maxWidth: _billItemNameMaxWidth,
      );

      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: (_is80mm && PrintConfig.showItemDateOn80mm) ? 5 : 6,
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: nameWidget,
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                qtyDisplay,
                textAlign: pw.TextAlign.center,
                style: _text(
                  size: _billTableQtyTextSize,
                  bold: _billTableQtyTextBold,
                ),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                priceDisplay,
                textAlign: pw.TextAlign.center,
                style: contentStyle,
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                _formatMoney(amt),
                textAlign: pw.TextAlign.right,
                style: contentStyle,
              ),
            ),
            if (_is80mm && PrintConfig.showItemDateOn80mm)
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  _itemDate(item.createdAt),
                  textAlign: pw.TextAlign.right,
                  style: contentStyle,
                ),
              ),
          ],
        ),
      );

      if (item.variations.isNotEmpty) {
        for (final variation in item.variations) {
          rows.add(
            pw.Padding(
              padding: pw.EdgeInsets.only(left: indentLeft, top: 1),
              child: await ReceiptTextRenderer.buildReceiptText(
                '- $variation',
                fontSize: metaSize,
                fontWeight: metaBold ? FontWeight.bold : FontWeight.normal,
                pdfStyle: metaStyle,
                maxWidth: _billMetaMaxWidth,
              ),
            ),
          );
        }
      }

      if (item.addons.isNotEmpty) {
        for (final addon in item.addons) {
          rows.add(
            pw.Padding(
              padding: pw.EdgeInsets.only(left: indentLeft, top: 1),
              child: await ReceiptTextRenderer.buildReceiptText(
                '+ $addon',
                fontSize: metaSize,
                fontWeight: metaBold ? FontWeight.bold : FontWeight.normal,
                pdfStyle: metaStyle,
                maxWidth: _billMetaMaxWidth,
              ),
            ),
          );
        }
      }

      // if (item.note.trim().isNotEmpty) {
      //   rows.add(
      //     pw.Padding(
      //       padding: pw.EdgeInsets.only(left: indentLeft, top: 1),
      //       child: pw.Text(
      //         'Note: ${item.note.trim()}',
      //         style: _text(size: metaSize),
      //       ),
      //     ),
      //   );
      // }

      rows.add(pw.SizedBox(height: _is80mm ? 2 : 1));
    }

    return rows;
  }

  // ═══════════════════════════════════════════════════════════════════
  // SUMMARY SECTION (flex-based — spacer:label:value = 1:5:3)
  //
  // Mirrors EscPos _alignRightLabelValue: right-justified label+value
  // block with minimal left spacer.
  // ═══════════════════════════════════════════════════════════════════

  static List<pw.Widget> _billAmountLineWidgets(String label, String value) {
    final textSize = _billAmountLineTextSize;
    final textBold = _billAmountLineTextBold;

    return [
      pw.Row(
        children: [
          pw.Expanded(flex: 1, child: pw.SizedBox()),
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              '$label :',
              textAlign: pw.TextAlign.right,
              style: _text(size: textSize, bold: textBold),
            ),
          ),
          pw.SizedBox(width: 1),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: _text(size: textSize, bold: textBold),
            ),
          ),
        ],
      ),
    ];
  }

  static List<pw.Widget> _billTotalRow(
      String label, String value, double fontsize, bool bold,
      {String? subLabel}) {
    final widgets = <pw.Widget>[];

    // MAIN TOTAL ROW
    widgets.add(
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: _text(size: fontsize, bold: bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: _text(size: fontsize, bold: bold),
            ),
          ),
        ],
      ),
    );

    // SUB TEXT (like payment method)
    if (subLabel != null && subLabel.trim().isNotEmpty) {
      widgets.add(
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            subLabel,
            style: _text(size: _billPaidByTextSize, bold: _billPaidByTextBold),
          ),
        ),
      );
    }

    return widgets;
  }

  // ═══════════════════════════════════════════════════════════════════
  // DELIVERY DETAILS (flex-based — label:value = 3:7)
  // ═══════════════════════════════════════════════════════════════════

  static List<pw.Widget> _deliveryDetailsWidgets(Map<dynamic, dynamic> bill) {
    final widgets = <pw.Widget>[];

    void addRow(String label, String value) {
      if (value.trim().isEmpty) return;
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Label Column (Fixed ratio, left aligned)
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  label,
                  style: _text(
                    size: _deliveryDetailTextSize,
                    bold: _deliveryDetailTextBold,
                  ),
                ),
              ),

              // 2. The Colon (Fixed width, perfectly aligned)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                child: pw.Text(
                  ' : ',
                  style: _text(
                    size: _deliveryDetailTextSize,
                    bold: _deliveryDetailTextBold,
                  ),
                ),
              ),

              // 3. Value Column (Takes remaining space, wraps automatically)
              pw.Expanded(
                flex: 7,
                child: pw.Text(
                  value,
                  style: _text(size: _deliveryDetailTextSize),
                ),
              ),
            ],
          ),
        ),
      );
    }

    addRow('Name', bill['delivery_cust_name']?.toString() ?? '');
    addRow('Phone', bill['delivery_cust_phone']?.toString() ?? '');
    addRow('Add. Type', bill['delivery_address_type']?.toString() ?? '');
    addRow('Address', bill['delivery_cust_address']?.toString() ?? '');
    addRow('Pincode', bill['delivery_cust_pincode']?.toString() ?? '');

    return widgets;
  }
  // ═══════════════════════════════════════════════════════════════════
  // ROOM ORDER DETAILS
  // ═══════════════════════════════════════════════════════════════════

  static List<pw.Widget> _roomOrderWidgets(
    List<dynamic> associatedOrders,
    double roomAdvance,
    double roomPending,
    double grantAmount,
    String payLabel,
  ) {
    final widgets = <pw.Widget>[];

    for (final assoc in associatedOrders) {
      final aMap = assoc as Map<String, dynamic>;
      final aId = aMap['restaurant_order_id']?.toString() ?? '';
      final aAmt =
          double.tryParse(aMap['order_amount']?.toString() ?? '0') ?? 0.0;

      widgets.add(
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Order ID #$aId',
                style: _text(
                    size: _roomAssociatedTextSize,
                    bold: _roomAssociatedTextBold),
              ),
            ),
            pw.Text(
              aAmt.toStringAsFixed(2),
              style: _text(
                  size: _roomAssociatedTextSize, bold: _roomAssociatedTextBold),
            ),
          ],
        ),
      );
    }

    widgets.add(
        _simpleDividerOrDotted ? _divider(dashed: true) : buildDottedLine(180));

    widgets.addAll(_billAmountLineWidgets(
      'Room Advance',
      roomAdvance.toStringAsFixed(2),
    ));
    widgets.addAll(_billAmountLineWidgets(
      'Room Pending',
      roomPending.toStringAsFixed(2),
    ));

    widgets.add(
        _simpleDividerOrDotted ? _divider(dashed: true) : buildDottedLine(180));

    widgets.addAll(_billTotalRow(
      'GRAND TOTAL',
      'Rs.${grantAmount.toStringAsFixed(0)}',
      _billGrandTotalTextSize,
      _billGrandTotalTextBold,
      subLabel: payLabel,
    ));

    return widgets;
  }

  // ═══════════════════════════════════════════════════════════════════
  // PURE UTILITY — NO LAYOUT CHANGES
  // ═══════════════════════════════════════════════════════════════════

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

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _stripKotPrice(String text) {
    return text
        .replaceAll(RegExp(r'\s*\(\+\s*\d+(?:\.\d+)?\s*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
            lines.add(
              word.substring(
                i,
                i + width > word.length ? word.length : i + width,
              ),
            );
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
              i,
              i + width > word.length ? word.length : i + width,
            );
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
}
