import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printer_agent/core/config/app_constants.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/order_item.dart';
import 'package:printer_agent/core/models/print_style_config.dart';
import 'package:printer_agent/core/models/restaurant_order.dart';
import 'package:printer_agent/core/profile/restaurant_profile_model.dart';
import 'package:printer_agent/core/printer/bitmap/print_style_extensions.dart';
import 'package:printer_agent/core/printer/bitmap/receipt_business_logic.dart';
import 'package:printer_agent/core/printer/bitmap/receipt_canvas.dart';

class BillRenderer {
  static Future<ReceiptCanvas> render({
    required RestaurantOrder order,
    required PrintStyleConfig style,
    required String fontFamily,
    required RestaurantProfileModel profile,
  }) async {
    final canvas = ReceiptCanvas(style: style, fontFamily: fontFamily);
    final solid = style.useSolidDivider;
    final bill = order.billData;

    final logoBytes = await _fetchLogoBytes(profile);
    if (logoBytes != null) {
      final logoW = (style.logoWidthMm * 8).clamp(50.0, 400.0);
      await canvas.drawImageBytes(logoBytes, targetWidthPx: logoW);
    }

    final name = ReceiptBusinessLogic.restaurantName(profile, order);
    canvas.drawText(
      name.toUpperCase(),
      canvas.styleFor(style.restaurantName),
      align: TextAlign.center,
    );

    if (profile.restaurantAddress.isNotEmpty) {
      canvas.drawText(
        profile.restaurantAddress,
        canvas.styleFor(style.restaurantAddress),
        align: TextAlign.center,
      );
    }
    if (profile.restaurantPhone.isNotEmpty) {
      canvas.drawText(
        'Ph: ${profile.restaurantPhone}',
        canvas.styleFor(style.restaurantPhone),
        align: TextAlign.center,
      );
    }
    if (profile.gstCode.isNotEmpty) {
      canvas.drawText(
        'GST No: ${profile.gstCode}',
        canvas.styleFor(style.restaurantGst),
        align: TextAlign.center,
      );
    }
    if (profile.fssai.isNotEmpty) {
      canvas.drawText(
        'Fssai No: ${profile.fssai}',
        canvas.styleFor(style.restaurantFssai),
        align: TextAlign.center,
      );
    }

    canvas.drawRule(solid);

    final custName = bill['cust_name']?.toString().trim() ?? '';
    final custPhone = bill['cust_phone']?.toString().trim() ?? '';
    final custGstName = bill['cust_gst_name']?.toString().trim() ?? '';
    final custGstNumber = bill['cust_gst']?.toString().trim() ?? '';
    final orderNote = bill['order_note']?.toString().trim() ?? '';
    final waiterName = bill['waiter_name']?.toString().trim() ?? '';
    final centerLabel = ReceiptBusinessLogic.billCenterLabel(bill);

    canvas.drawThreeColRow(
      'Bill NO. ${order.displayOrderId}',
      waiterName,
      ReceiptBusinessLogic.formatDate(order.receivedAt),
      canvas.styleFor(style.billInfoRow1),
    );

    if (custName.isNotEmpty ||
        centerLabel.isNotEmpty ||
        custPhone.isNotEmpty) {
      canvas.drawThreeColRow(
        custName,
        centerLabel,
        custPhone,
        canvas.styleFor(style.billInfoRow2),
      );
    }

    if (custGstName.isNotEmpty || custGstNumber.isNotEmpty) {
      canvas.drawThreeColRow(
        custGstName,
        '',
        custGstNumber,
        canvas.styleFor(style.billInfoRow3),
      );
    }

    if (order.dailyToken.isNotEmpty) {
      canvas.drawThreeColRow(
        '',
        'Token No: ${order.dailyToken}',
        '',
        canvas.styleFor(style.billInfoRow4),
      );
    }

    canvas.drawRule(solid);

    final showDate = ReceiptBusinessLogic.showBillItemDate;
    final cw = canvas.contentWidthPx;
    final amtW = cw * (showDate ? 0.18 : 0.22);
    final qtyW = cw * (showDate ? 0.14 : 0.16);
    final dateW = showDate ? cw * 0.12 : 0.0;
    final itemW = cw - qtyW - amtW - dateW;

    final headerStyle = canvas.styleFor(style.billTableHeader);
    canvas.drawTableRow([
      ReceiptTableCell('ITEM', itemW),
      ReceiptTableCell('QTY', qtyW, align: TextAlign.center),
      ReceiptTableCell('AMT', amtW, align: TextAlign.right),
      if (showDate) ReceiptTableCell('DATE', dateW, align: TextAlign.right),
    ], headerStyle);

    canvas.drawRule(solid);

    final rowStyle = canvas.styleFor(style.billTableContent);
    final metaStyle = canvas.styleFor(style.billTableMeta);

    for (final item in OrderItem.mergedForBill(order.items)) {
      if (item.foodStatus == 3) continue;

      final unitPrice = ReceiptBusinessLogic.itemUnitPrice(item);
      final amt = unitPrice * item.quantity;
      final qtyDisplay = ReceiptBusinessLogic.qtyDisplay(item);
      final displayName = ReceiptBusinessLogic.billItemDisplayName(item);
      final dateStr = showDate ? ReceiptBusinessLogic.itemDate(item.createdAt) : '';

      canvas.drawTableRow([
        ReceiptTableCell(displayName, itemW),
        ReceiptTableCell(qtyDisplay, qtyW, align: TextAlign.center),
        ReceiptTableCell(ReceiptBusinessLogic.formatMoney(amt), amtW, align: TextAlign.right),
        if (showDate)
          ReceiptTableCell(dateStr, dateW, align: TextAlign.right),
      ], rowStyle);

      for (final variation in item.variations) {
        canvas.drawText('  + $variation', metaStyle);
      }
      for (final addon in item.addons) {
        canvas.drawText('  + $addon', metaStyle);
      }
    }

    if (orderNote.isNotEmpty) {
      canvas.drawRule(solid);
      canvas.drawText(
        'Notes : $orderNote',
        canvas.styleFor(style.orderNote),
        align: TextAlign.center,
      );
    }

    canvas.drawRule(solid);

    final itemTotal = ReceiptBusinessLogic.billAmount(bill, 'order_item_total');
    final serviceCharge =
        ReceiptBusinessLogic.billAmount(bill, 'service_charge_amount');
    final deliveryCharge =
        ReceiptBusinessLogic.billAmount(bill, 'delivery_charge');
    final tip = ReceiptBusinessLogic.billAmount(bill, 'tip_amount');
    final subTotal = ReceiptBusinessLogic.billAmount(bill, 'order_subtotal');
    final gstTax = ReceiptBusinessLogic.billAmount(bill, 'gst_tax');
    final vatTax = ReceiptBusinessLogic.billAmount(bill, 'vat_tax');
    final packingCharge = ReceiptBusinessLogic.billAmount(bill, 'packing_charge');
    final grantAmount = ReceiptBusinessLogic.billAmount(bill, 'grant_amount');
    final paymentAmount = ReceiptBusinessLogic.billAmount(bill, 'payment_amount');
    final roomAdvance = ReceiptBusinessLogic.billAmount(bill, 'room_advance_pay');
    final roomPending = ReceiptBusinessLogic.billAmount(bill, 'room_remaining_pay');
    final isAggregator = ReceiptBusinessLogic.isAggregator(bill);
    final isRoomOrder = ReceiptBusinessLogic.isRoomOrder(bill);
    final couponCode = bill['coupon_code']?.toString() ?? '';
    final walletAmount =
        ReceiptBusinessLogic.billAmount(bill, 'wallet_used_amount');
    final loyaltyAmount =
        ReceiptBusinessLogic.billAmount(bill, 'loyalty_discount_amount');
    final discountAmount =
        ReceiptBusinessLogic.billAmount(bill, 'discount_amount');

    final amountStyle = canvas.styleFor(style.billAmountLine);

    canvas.drawLabelValue('Item Total', itemTotal.toStringAsFixed(2), amountStyle);
    if (serviceCharge > 0) {
      canvas.drawLabelValue(
          profile.serviceChargeLabel, serviceCharge.toStringAsFixed(2), amountStyle);
    }
    if (deliveryCharge > 0) {
      canvas.drawLabelValue(
          'Delivery Charge', deliveryCharge.toStringAsFixed(2), amountStyle);
    }
    if (discountAmount > 0) {
      canvas.drawLabelValue(
          'Discount', discountAmount.toString(), amountStyle);
    }
    if (packingCharge > 0) {
      canvas.drawLabelValue(
          'Packing Charge', packingCharge.toStringAsFixed(2), amountStyle);
    }
    if (couponCode.isNotEmpty) {
      canvas.drawLabelValue('Coupon Code', couponCode, amountStyle);
    }
    if (loyaltyAmount > 0) {
      canvas.drawLabelValue('Loyalty', loyaltyAmount.toString(), amountStyle);
    }
    if (walletAmount > 0) {
      canvas.drawLabelValue('Wallet', walletAmount.toString(), amountStyle);
    }
    if (tip > 0) {
      canvas.drawLabelValue('Tip', tip.toStringAsFixed(2), amountStyle);
    }
    if (!isAggregator) {
      canvas.drawLabelValue(
          'Sub Total', subTotal.toStringAsFixed(2), amountStyle);
    }
    final stationGstRows = ReceiptBusinessLogic.stationGstRows(
      bill,
      restaurantFor: profile.restaurantFor,
    );
    if (stationGstRows.isNotEmpty) {
      canvas.drawRule(solid);
      canvas.drawText(
        'GST Detail',
        canvas.styleFor(style.billAmountLine).copyWith(fontWeight: FontWeight.bold),
        align: TextAlign.center,
      );
      for (final row in stationGstRows) {
        canvas.drawThreeColRow(
          row['name'] ?? '',
          row['taxId'] ?? '',
          row['gst'] ?? '',
          amountStyle,
        );
      }
      canvas.drawRule(solid);
    }
    if (gstTax > 0) {
      if (isAggregator) {
        canvas.drawLabelValue('GST', gstTax.toStringAsFixed(2), amountStyle);
      } else {
        final half = gstTax / 2;
        canvas.drawLabelValue('CGST', half.toStringAsFixed(2), amountStyle);
        canvas.drawLabelValue('SGST', half.toStringAsFixed(2), amountStyle);
      }
    }
    if (vatTax > 0) {
      canvas.drawLabelValue('VAT', vatTax.toStringAsFixed(2), amountStyle);
    }
    if (roomAdvance > 0) {
      canvas.drawLabelValue(
          'Room Advance', roomAdvance.toStringAsFixed(2), amountStyle);
    }
    if (roomPending > 0) {
      canvas.drawLabelValue(
          'Room Pending', roomPending.toStringAsFixed(2), amountStyle);
    }

    canvas.drawRule(solid);

    final totalAmount = isRoomOrder ? paymentAmount : grantAmount;
    final totalLabel = isRoomOrder || isAggregator
        ? 'TOTAL'
        : 'TOTAL ${ReceiptBusinessLogic.payLabel(bill)}';
    canvas.drawLeftRight(
      totalLabel,
      ReceiptBusinessLogic.formatMoney(totalAmount),
      canvas.styleFor(style.billTotal),
    );

    if (bill['order_type']?.toString() == 'delivery') {
      canvas.drawRule(solid);
      canvas.drawText(
        '-- Delivery Details --',
        canvas.styleFor(style.deliveryHeader),
        align: TextAlign.center,
      );
      canvas.drawRule(solid);

      final dName = bill['delivery_cust_name']?.toString() ?? '';
      final phone = bill['delivery_cust_phone']?.toString() ?? '';
      final addrType = bill['delivery_address_type']?.toString() ?? '';
      final house = bill['delivery_cust_house']?.toString() ?? '';
      final floor = bill['delivery_cust_floor']?.toString() ?? '';
      final addr = bill['delivery_cust_address']?.toString() ?? '';
      final city = bill['delivery_cust_city']?.toString() ?? '';
      final state = bill['delivery_cust_state']?.toString() ?? '';
      final pincode = bill['delivery_cust_pincode']?.toString() ?? '';
      final deliveryStyle = canvas.styleFor(style.deliveryContent);

      if (dName.isNotEmpty) _drawLabelBlock(canvas, 'Name', dName, deliveryStyle);
      if (phone.isNotEmpty) _drawLabelBlock(canvas, 'Phone', phone, deliveryStyle);
      if (addrType.isNotEmpty) {
        _drawLabelBlock(canvas, 'Add. Type', addrType, deliveryStyle);
      }
      if (house.isNotEmpty) {
        _drawLabelBlock(canvas, 'House', house, deliveryStyle);
      }
      if (floor.isNotEmpty) {
        _drawLabelBlock(canvas, 'Floor', floor, deliveryStyle);
      }
      if (addr.isNotEmpty) _drawLabelBlock(canvas, 'Address', addr, deliveryStyle);
      if (city.isNotEmpty) {
        _drawLabelBlock(canvas, 'City', city, deliveryStyle);
      }
      if (state.isNotEmpty) {
        _drawLabelBlock(canvas, 'State', state, deliveryStyle);
      }
      if (pincode.isNotEmpty) {
        _drawLabelBlock(canvas, 'Pincode', pincode, deliveryStyle);
      }
    }

    if (isRoomOrder) {
      final associatedOrders = bill['associated_orders'] as List<dynamic>?;
      canvas.drawRule(solid);
      canvas.drawText(
        '-- Previous Room Bill --',
        canvas.styleFor(style.roomHeader),
        align: TextAlign.center,
      );
      canvas.drawRule(solid);

      for (final assoc in associatedOrders ?? []) {
        final aMap = assoc as Map<String, dynamic>;
        final aId = aMap['restaurant_order_id']?.toString() ?? '';
        final aAmt =
            double.tryParse(aMap['order_amount']?.toString() ?? '0') ?? 0.0;
        canvas.drawLeftRight(
          'Order ID #$aId',
          aAmt.toStringAsFixed(2),
          canvas.styleFor(style.roomContent),
        );
      }

      canvas.drawRule(solid);
      canvas.drawLeftRight(
        'GRAND TOTAL ${ReceiptBusinessLogic.payLabel(bill)}',
        'Rs.${grantAmount.toStringAsFixed(0)}',
        canvas.styleFor(style.billGrandTotal),
      );
    }

    canvas.drawRule(solid);
    canvas.drawText(
      PrintConfig.poweredByFooter,
      canvas.styleFor(style.footer).copyWith(fontWeight: FontWeight.bold),
      align: TextAlign.center,
    );

    return canvas;
  }

  static void _drawLabelBlock(
    ReceiptCanvas canvas,
    String label,
    String value,
    TextStyle style,
  ) {
    canvas.drawText('$label: $value', style);
  }

  static Future<Uint8List?> _fetchLogoBytes(
    RestaurantProfileModel profile,
  ) async {
    final rawPath =
        profile.billLogo.isNotEmpty ? profile.billLogo : profile.restaurantLogo;
    final url = ReceiptBusinessLogic.resolveLogoUrl(rawPath, AppConstants.apiUrl);
    if (url.isEmpty) return null;
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return Uint8List.fromList(res.bodyBytes);
      }
    } catch (_) {}
    return null;
  }
}
