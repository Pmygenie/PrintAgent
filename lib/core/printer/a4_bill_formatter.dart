import 'package:flutter/material.dart' show FontWeight;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printer_agent/core/config/app_constants.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/order_item.dart';
import 'package:printer_agent/core/models/print_style_config.dart';
import 'package:printer_agent/core/models/restaurant_order.dart';
import 'package:printer_agent/core/printer/amount_in_words.dart';
import 'package:printer_agent/core/printer/bitmap/receipt_business_logic.dart';
import 'package:printer_agent/core/printer/receipt_text_renderer.dart';
import 'package:printer_agent/core/profile/restaurant_profile_model.dart';
import 'package:printer_agent/core/profile/restaurant_profile_service.dart';
import 'package:printer_agent/core/services/print_style_service.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Full-page A4 bill layout. Thermal 58/80mm bills stay in [PdfFormatter].
class A4BillFormatter {
  A4BillFormatter._();

  static const _marginMm = 14.0;
  static const _logoMm = 28.0;
  static const _qrMm = 32.0;
  static const _itemNameMaxWidthMm = 90.0;

  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static late PrintStyleConfig _style;

  static PdfPageFormat get _pageFormat => PdfPageFormat.a4.copyWith(
        marginTop: _marginMm * PdfPageFormat.mm,
        marginBottom: _marginMm * PdfPageFormat.mm,
        marginLeft: _marginMm * PdfPageFormat.mm,
        marginRight: _marginMm * PdfPageFormat.mm,
      );

  static pw.TableBorder get _border => pw.TableBorder.all(
        width: 0.6,
        color: PdfColors.black,
      );

  static double _pt(PrintStyleItem item) => item.size80 * 1.4;

  static pw.TextStyle _text(PrintStyleItem item) {
    return pw.TextStyle(
      font: item.isBold ? _boldFont : _regularFont,
      fontSize: _pt(item),
      fontWeight: item.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
  }

  static pw.EdgeInsets get _cellPad =>
      const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4);

  static Future<pw.MultiPage> buildPage(RestaurantOrder o) async {
    _style = await PrintStyleService.getConfig();
    await _ensureFonts();

    final profile = await RestaurantProfileService.getProfile();
    final logoImage = await _fetchLogoImage(profile);
    final bill = o.billData;
    final isAggregator = bill['is_aggregator'] == true;
    final upiQrImage = (!isAggregator &&
            PrintConfig.upiQrEnabled &&
            PrintConfig.upiId.trim().isNotEmpty)
        ? await _generateQrImage(PrintConfig.upiQrDataForBill(bill))
        : null;
    final feedbackQrImage = (!isAggregator && PrintConfig.feedbackQrEnabled)
        ? await _generateQrImage(PrintConfig.feedbackQrData(o.orderId))
        : null;

    final itemTable = await _itemTable(o);
    final children = <pw.Widget>[
      _header(profile, o, logoImage),
      _meta(o, bill),
      itemTable,
    ];

    final orderNote = bill['order_note']?.toString().trim() ?? '';
    if (orderNote.isNotEmpty) {
      children.add(_noteBox(orderNote));
    }

    final isRoom = ReceiptBusinessLogic.isRoomOrder(bill);
    children.add(_amountsAndTotal(bill, profile, isRoom: isRoom));

    if (isRoom) {
      children.add(_roomSection(bill));
    }

    if (bill['order_type']?.toString() == 'delivery' && !isAggregator) {
      children.add(_deliveryDetailsBox(bill));
    }

    final qrBox = _qrBox(upiQrImage, feedbackQrImage);
    if (qrBox != null) children.add(qrBox);
    children.add(_footerBox(profile));

    return pw.MultiPage(
      pageFormat: _pageFormat,
      build: (_) => children,
    );
  }

  // ── Header ──────────────────────────────────────────────────────────

  static pw.Widget _header(
    RestaurantProfileModel profile,
    RestaurantOrder o,
    pw.MemoryImage? logoImage,
  ) {
    final name = ReceiptBusinessLogic.restaurantName(profile, o);
    final info = <pw.Widget>[
      pw.Text(
        name.toUpperCase(),
        style: _text(_style.restaurantName),
      ),
      if (profile.restaurantAddress.isNotEmpty)
        pw.Text(
          profile.restaurantAddress,
          style: _text(_style.restaurantAddress),
        ),
      if (profile.restaurantPhone.isNotEmpty)
        pw.Text(
          'Ph: ${profile.restaurantPhone}',
          style: _text(_style.restaurantPhone),
        ),
      if (profile.gstCode.isNotEmpty)
        pw.Text(
          'GST No: ${profile.gstCode}',
          style: _text(_style.restaurantGst),
        ),
      if (profile.fssai.isNotEmpty)
        pw.Text(
          'Fssai No: ${profile.fssai}',
          style: _text(_style.restaurantFssai),
        ),
    ];

    return pw.Table(
      border: _border,
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: _cellPad,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null) ...[
                    pw.Image(
                      logoImage,
                      width: _logoMm * PdfPageFormat.mm,
                      height: _logoMm * PdfPageFormat.mm,
                      fit: pw.BoxFit.contain,
                    ),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: info,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Meta ────────────────────────────────────────────────────────────

  static pw.Widget _meta(RestaurantOrder o, Map<String, dynamic> bill) {
    final waiterName = bill['waiter_name']?.toString().trim() ?? '';
    final custName = bill['cust_name']?.toString().trim() ?? '';
    final custPhone = bill['cust_phone']?.toString().trim() ?? '';
    final custGstName = bill['cust_gst_name']?.toString().trim() ?? '';
    final custGstNumber = bill['cust_gst']?.toString().trim() ?? '';
    final token = o.dailyToken.trim();

    final rows = <pw.TableRow>[
      _metaRow(
        'Bill No',
        o.displayOrderId,
        'Date',
        ReceiptBusinessLogic.formatDate(o.receivedAt),
        _style.billInfoRow1,
      ),
      _metaRow(
        'Table / Type',
        ReceiptBusinessLogic.billCenterLabel(bill),
        'Waiter',
        waiterName,
        _style.billInfoRow2,
      ),
    ];
    if (custName.isNotEmpty || custPhone.isNotEmpty) {
      rows.add(_metaRow(
        'Customer',
        custName,
        'Phone',
        custPhone,
        _style.billInfoRow2,
      ));
    }
    if (custGstName.isNotEmpty || custGstNumber.isNotEmpty) {
      rows.add(_metaRow(
        'GSTIN Name',
        custGstName,
        'GSTIN',
        custGstNumber,
        _style.billInfoRow3,
      ));
    }
    if (token.isNotEmpty) {
      rows.add(_metaRow('Token', 'T-$token', '', '', _style.billInfoRow4));
    }

    return pw.Table(border: _border, children: rows);
  }

  static pw.TableRow _metaRow(
    String leftLabel,
    String leftValue,
    String rightLabel,
    String rightValue,
    PrintStyleItem item,
  ) {
    return pw.TableRow(
      children: [
        _metaCell(leftLabel, leftValue, item),
        _metaCell(rightLabel, rightValue, item),
      ],
    );
  }

  static pw.Widget _metaCell(String label, String value, PrintStyleItem item) {
    if (label.isEmpty && value.isEmpty) {
      return pw.Padding(padding: _cellPad, child: pw.SizedBox());
    }
    final style = _text(item);
    return pw.Padding(
      padding: _cellPad,
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label : ', style: style),
            pw.TextSpan(text: value, style: style),
          ],
        ),
      ),
    );
  }

  // ── Items ───────────────────────────────────────────────────────────

  static Future<pw.Widget> _itemTable(RestaurantOrder o) async {
    final headerStyle = _text(_style.billTableHeader);
    final contentStyle = _text(_style.billTableContent);
    final qtyStyle = _text(_style.billTableQty);
    final metaStyle = _text(_style.billTableMeta);
    final priceHeader =
        PrintConfig.restaurantId == 798 ? 'PRICE/KG' : 'PRICE';
    final showDate = PrintConfig.showItemDateOn80mm;

    final headerCells = [
      _headerCell('#', headerStyle, pw.TextAlign.center),
      _headerCell('ITEM', headerStyle, pw.TextAlign.left),
      _headerCell('QTY', headerStyle, pw.TextAlign.center),
      _headerCell(priceHeader, headerStyle, pw.TextAlign.right),
      _headerCell('AMT', headerStyle, pw.TextAlign.right),
      if (showDate) _headerCell('DATE', headerStyle, pw.TextAlign.right),
    ];

    final rows = <pw.TableRow>[
      pw.TableRow(children: headerCells),
    ];

    var sr = 1;
    for (final item in OrderItem.mergedForBill(o.items)) {
      if (item.foodStatus == 3) continue;

      final isComp = item.complementary?.toString().toLowerCase() == 'yes';
      final effectivePrice =
          (item.itemUnit.isNotEmpty && item.itemUnitPrice > 0)
              ? item.itemUnitPrice
              : item.price;
      final displayUnitPrice = item.variations.isNotEmpty
          ? effectivePrice + item.variationTotal
          : effectivePrice;
      final basePrice = isComp ? 0.0 : displayUnitPrice;
      final unitTotalPrice =
          effectivePrice + item.variationTotal + item.addonTotal;
      final amt = isComp ? 0.0 : unitTotalPrice * item.quantity;
      final displayName = isComp ? '${item.name} (Comp)' : item.name;

      final isGramUnit798 = PrintConfig.restaurantId == 798 &&
          item.itemUnit.trim().toLowerCase() == 'gm';
      final priceDisplay = isGramUnit798
          ? ReceiptBusinessLogic.formatMoney(basePrice * 1000)
          : ReceiptBusinessLogic.formatMoney(basePrice);

      final nameChildren = <pw.Widget>[
        await ReceiptTextRenderer.buildReceiptText(
          displayName,
          fontSize: _pt(_style.billTableContent),
          fontWeight: _style.billTableContent.isBold
              ? FontWeight.bold
              : FontWeight.normal,
          pdfStyle: contentStyle,
          maxWidth: _itemNameMaxWidthMm * PdfPageFormat.mm,
        ),
      ];
      for (final variation in item.variations) {
        nameChildren.add(
          await ReceiptTextRenderer.buildReceiptText(
            '- $variation',
            fontSize: _pt(_style.billTableMeta),
            fontWeight: _style.billTableMeta.isBold
                ? FontWeight.bold
                : FontWeight.normal,
            pdfStyle: metaStyle,
            maxWidth: _itemNameMaxWidthMm * PdfPageFormat.mm,
          ),
        );
      }
      for (final addon in item.addons) {
        nameChildren.add(
          await ReceiptTextRenderer.buildReceiptText(
            '+ $addon',
            fontSize: _pt(_style.billTableMeta),
            fontWeight: _style.billTableMeta.isBold
                ? FontWeight.bold
                : FontWeight.normal,
            pdfStyle: metaStyle,
            maxWidth: _itemNameMaxWidthMm * PdfPageFormat.mm,
          ),
        );
      }

      rows.add(
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.top,
          children: [
            _bodyCell('$sr', contentStyle, pw.TextAlign.center),
            pw.Padding(
              padding: _cellPad,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: nameChildren,
              ),
            ),
            _bodyCell(
              ReceiptBusinessLogic.qtyDisplay(item),
              qtyStyle,
              pw.TextAlign.center,
            ),
            _bodyCell(priceDisplay, contentStyle, pw.TextAlign.right),
            _bodyCell(
              ReceiptBusinessLogic.formatMoney(amt),
              contentStyle,
              pw.TextAlign.right,
            ),
            if (showDate)
              _bodyCell(
                ReceiptBusinessLogic.itemDate(item.createdAt),
                contentStyle,
                pw.TextAlign.right,
              ),
          ],
        ),
      );
      sr++;
    }

    return pw.Table(
      border: _border,
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(70),
        if (showDate) 5: const pw.FixedColumnWidth(50),
      },
      children: rows,
    );
  }

  static pw.Widget _headerCell(
    String text,
    pw.TextStyle style,
    pw.TextAlign align,
  ) {
    return pw.Padding(
      padding: _cellPad,
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  static pw.Widget _bodyCell(
    String text,
    pw.TextStyle style,
    pw.TextAlign align,
  ) {
    return pw.Padding(
      padding: _cellPad,
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  static pw.Widget _noteBox(String note) {
    return pw.Table(
      border: _border,
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: _cellPad,
              child: pw.Text(
                'Note : $note',
                style: _text(_style.orderNote),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Amounts ─────────────────────────────────────────────────────────

  static pw.Widget _amountsAndTotal(
    Map<String, dynamic> bill,
    RestaurantProfileModel profile, {
    required bool isRoom,
  }) {
    double d(String key) => ReceiptBusinessLogic.billAmount(bill, key);

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
    final roomAdvance = ReceiptBusinessLogic.roomAdvance(bill);
    final roomPending = ReceiptBusinessLogic.roomPending(bill);
    final isAggregator = ReceiptBusinessLogic.isAggregator(bill);
    final couponCode = bill['coupon_code']?.toString() ?? '';
    final discountAmount = d('discount_amount');
    final walletAmount = d('wallet_used_amount');
    final loyaltyAmount = d('loyalty_discount_amount');

    final lines = <_AmountLine>[
      _AmountLine('Item Total', itemTotal.toStringAsFixed(2)),
    ];
    if (serviceCharge > 0) {
      lines.add(_AmountLine(
          profile.serviceChargeLabel, serviceCharge.toStringAsFixed(2)));
    }
    if (deliveryCharge > 0) {
      lines.add(
          _AmountLine('Delivery Charge', deliveryCharge.toStringAsFixed(2)));
    }
    if (discountAmount > 0) {
      lines.add(_AmountLine('Discount', discountAmount.toString()));
    }
    if (packingCharge > 0) {
      lines.add(_AmountLine('Packing Charge', packingCharge.toStringAsFixed(2)));
    }
    if (couponCode.isNotEmpty) {
      lines.add(_AmountLine('Coupon Code', couponCode));
    }
    if (loyaltyAmount > 0) {
      lines.add(_AmountLine('Loyalty', loyaltyAmount.toString()));
    }
    if (walletAmount > 0) {
      lines.add(_AmountLine('Wallet', walletAmount.toString()));
    }
    if (tip > 0) {
      lines.add(_AmountLine('Tip', tip.toStringAsFixed(2)));
    }
    if (!isAggregator) {
      lines.add(_AmountLine('Sub Total', subTotal.toStringAsFixed(2)));
    }

    final gstRows = ReceiptBusinessLogic.stationGstRows(
      bill,
      restaurantFor: profile.restaurantFor,
    );

    final taxLines = <_AmountLine>[];
    if (gstTax > 0) {
      if (isAggregator) {
        taxLines.add(_AmountLine('Total Tax', gstTax.toStringAsFixed(2)));
      } else {
        taxLines.add(_AmountLine('CGST', (gstTax / 2).toStringAsFixed(2)));
        taxLines.add(_AmountLine('SGST', (gstTax / 2).toStringAsFixed(2)));
      }
    }
    if (vatTax > 0) {
      taxLines.add(_AmountLine('VAT', vatTax.toStringAsFixed(2)));
    }
    if (roomAdvance > 0) {
      taxLines.add(_AmountLine('Room Advance', roomAdvance.toStringAsFixed(2)));
    }
    if (roomPending > 0) {
      taxLines.add(_AmountLine('Room Pending', roomPending.toStringAsFixed(2)));
    }

    final totalAmount = isRoom ? paymentAmount : grantAmount;
    final pay = isAggregator ? '' : _payLabel(bill);

    final amountStyle = _text(_style.billAmountLine);
    final totalStyle = _text(_style.billTotal);

    final rightAmounts = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(line.label, style: amountStyle),
              ),
              pw.Text(line.value, style: amountStyle),
            ],
          ),
        if (gstRows.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text('GST Detail', style: _text(_style.billAmountLine)),
          for (final row in gstRows)
            pw.Row(
              children: [
                pw.Expanded(child: pw.Text(row['name'] ?? '', style: amountStyle)),
                pw.Expanded(
                  child: pw.Text(
                    row['taxId'] ?? '',
                    textAlign: pw.TextAlign.center,
                    style: amountStyle,
                  ),
                ),
                pw.Text(row['gst'] ?? '', style: amountStyle),
              ],
            ),
        ],
        for (final line in taxLines)
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(line.label, style: amountStyle),
              ),
              pw.Text(line.value, style: amountStyle),
            ],
          ),
      ],
    );

    if (isRoom) {
      return pw.Table(
        border: _border,
        columnWidths: const {
          0: pw.FlexColumnWidth(6),
          1: pw.FlexColumnWidth(4),
        },
        children: [
          pw.TableRow(
            children: [
              pw.SizedBox(),
              pw.Padding(padding: _cellPad, child: rightAmounts),
            ],
          ),
          pw.TableRow(
            children: [
              pw.SizedBox(),
              pw.Padding(
                padding: _cellPad,
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text('TOTAL', style: totalStyle),
                    ),
                    pw.Text(
                      ReceiptBusinessLogic.formatMoney(totalAmount),
                      style: totalStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return pw.Table(
      border: _border,
      columnWidths: const {
        0: pw.FlexColumnWidth(6),
        1: pw.FlexColumnWidth(4),
      },
      children: [
        pw.TableRow(
          children: [
            pw.SizedBox(),
            pw.Padding(padding: _cellPad, child: rightAmounts),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: _cellPad,
              child: pw.Text(
                'In Words : ${AmountInWords.rupees(totalAmount)}',
                style: _text(_style.billAmountLine),
              ),
            ),
            pw.Padding(
              padding: _cellPad,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('TOTAL', style: totalStyle)),
                      pw.Text(
                        ReceiptBusinessLogic.formatMoney(totalAmount),
                        style: totalStyle,
                      ),
                    ],
                  ),
                  if (pay.isNotEmpty)
                    pw.Text(pay, style: _text(_style.billPaidBy)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _roomSection(Map<String, dynamic> bill) {
    final associated = bill['associated_orders'];
    final associatedList = associated is List ? associated : const [];
    final style = _text(_style.roomContent);
    final header = _text(_style.roomHeader);
    final amountStyle = _text(_style.billAmountLine);
    final grandStyle = _text(_style.billGrandTotal);
    final paymentAmount =
        ReceiptBusinessLogic.billAmount(bill, 'payment_amount');
    final grantAmount = ReceiptBusinessLogic.billAmount(bill, 'grant_amount');
    final pay = _payLabel(bill);

    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          pw.Padding(
            padding: _cellPad,
            child: pw.Text('-- Previous Room Bill --', style: header),
          ),
          pw.Padding(padding: _cellPad, child: pw.SizedBox()),
        ],
      ),
    ];

    for (final raw in associatedList) {
      if (raw is! Map) continue;
      final assoc = Map<String, dynamic>.from(raw);
      final amt =
          double.tryParse(assoc['order_amount']?.toString() ?? '0') ?? 0.0;
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: _cellPad,
              child: pw.Text(
                'Order ID #${assoc['restaurant_order_id'] ?? ''}',
                style: style,
              ),
            ),
            pw.Padding(
              padding: _cellPad,
              child: pw.Text(
                amt.toStringAsFixed(2),
                style: style,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: _cellPad,
            child: pw.Text(
              'In Words : ${AmountInWords.rupees(paymentAmount)}',
              style: amountStyle,
            ),
          ),
          pw.Padding(
            padding: _cellPad,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _kvRow(
                  'GRAND TOTAL',
                  'Rs.${grantAmount.toStringAsFixed(0)}',
                  grandStyle,
                ),
                if (pay.isNotEmpty)
                  pw.Text(pay, style: _text(_style.billPaidBy)),
              ],
            ),
          ),
        ],
      ),
    );

    return pw.Table(
      border: _border,
      columnWidths: const {
        0: pw.FlexColumnWidth(6),
        1: pw.FlexColumnWidth(4),
      },
      children: rows,
    );
  }

  static pw.Widget _kvRow(String label, String value, pw.TextStyle style) {
    return pw.Table(
      children: [
        pw.TableRow(
          children: [
            pw.Text(label, style: style),
            pw.Text(value, style: style, textAlign: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  static pw.Widget _deliveryDetailsBox(Map<String, dynamic> bill) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Name', bill['delivery_cust_name']?.toString() ?? ''),
      MapEntry('Phone', bill['delivery_cust_phone']?.toString() ?? ''),
      MapEntry('Add. Type', bill['delivery_address_type']?.toString() ?? ''),
      MapEntry('Address', bill['delivery_cust_address']?.toString() ?? ''),
      MapEntry('Pincode', bill['delivery_cust_pincode']?.toString() ?? ''),
    ].where((e) => e.value.trim().isNotEmpty).toList();

    final header = _text(_style.deliveryHeader);
    final body = _text(_style.deliveryContent);

    return pw.Table(
      border: _border,
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: _cellPad,
              child: pw.Center(
                child: pw.Text('-- Delivery Details --', style: header),
              ),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: _cellPad,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final row in rows)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: 70,
                            child: pw.Text(row.key, style: body),
                          ),
                          pw.Text(' : ', style: body),
                          pw.Expanded(child: pw.Text(row.value, style: body)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget? _qrBox(
    pw.MemoryImage? upiQrImage,
    pw.MemoryImage? feedbackQrImage,
  ) {
    if (upiQrImage == null && feedbackQrImage == null) return null;
    final caption = _text(_style.footer);

    pw.Widget cell(pw.MemoryImage? image, String label) {
      if (image == null) {
        return pw.Padding(padding: _cellPad, child: pw.SizedBox());
      }
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Column(
          children: [
            pw.Image(
              image,
              width: _qrMm * PdfPageFormat.mm,
              height: _qrMm * PdfPageFormat.mm,
            ),
            pw.SizedBox(height: 4),
            pw.Text(label, style: caption),
          ],
        ),
      );
    }

    if (upiQrImage != null && feedbackQrImage != null) {
      return pw.Table(
        border: _border,
        children: [
          pw.TableRow(
            children: [
              cell(upiQrImage, 'Scan to Pay'),
              cell(feedbackQrImage, 'Scan for Feedback'),
            ],
          ),
        ],
      );
    }

    return pw.Table(
      border: _border,
      children: [
        pw.TableRow(
          children: [
            cell(
              upiQrImage ?? feedbackQrImage,
              upiQrImage != null ? 'Scan to Pay' : 'Scan for Feedback',
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _footerBox(RestaurantProfileModel profile) {
    final style = _text(_style.footer);
    return pw.Table(
      border: _border,
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: pw.Column(
                children: [
                  pw.Text(
                    PrintConfig.poweredByFooter,
                    style: style,
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _payLabel(Map<String, dynamic> bill) {
    final paymentStatus = bill['payment_status']?.toString() ?? '';
    final paymentMethod = bill['payment_method']?.toString() ?? '';
    if (paymentStatus == 'unpaid' && paymentMethod == 'pending') {
      return 'Unpaid';
    }
    final method = paymentMethod.isNotEmpty
        ? paymentMethod[0].toUpperCase() + paymentMethod.substring(1)
        : '';
    return method.isEmpty ? '' : 'Paid by $method';
  }

  // ── Assets ──────────────────────────────────────────────────────────

  static String _resolveLogoUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = AppConstants.apiUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/$path';
  }

  static Future<pw.MemoryImage?> _fetchLogoImage(
    RestaurantProfileModel profile,
  ) async {
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

  static Future<void> _ensureFonts() async {
    _regularFont = null;
    _boldFont = null;
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
}

class _AmountLine {
  final String label;
  final String value;
  const _AmountLine(this.label, this.value);
}
