import 'package:flutter/material.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/print_style_config.dart';
import 'package:printer_agent/core/models/restaurant_order.dart';
import 'package:printer_agent/core/printer/bitmap/print_style_extensions.dart';
import 'package:printer_agent/core/printer/bitmap/receipt_business_logic.dart';
import 'package:printer_agent/core/printer/bitmap/receipt_canvas.dart';

class KotRenderer {
  static Future<ReceiptCanvas> render({
    required RestaurantOrder order,
    required PrintStyleConfig style,
    required String fontFamily,
    String? stationLabel,
    bool skipCancelledItems = true,
    bool isCancel = false,
    bool includeOrderNote = true,
  }) async {
    final canvas = ReceiptCanvas(style: style, fontFamily: fontFamily);
    final title = ReceiptBusinessLogic.kotTitle(stationLabel, cancel: isCancel);
    final solid = style.useSolidDivider;

    canvas.drawCenteredLines(
      title,
      canvas.styleFor(isCancel ? style.cancelKotTitle : style.kotTitle),
    );
    canvas.drawRule(solid);

    final waiterLine = ReceiptBusinessLogic.waiterLine(
      order,
      canvas.contentWidthPx.toInt(),
    );
    canvas.drawThreeColRow(
      'Order No:#${order.displayOrderId}',
      waiterLine,
      ReceiptBusinessLogic.formatDate(order.receivedAt),
      canvas.styleFor(style.kotOrderInfo1),
    );

    final centerText = ReceiptBusinessLogic.kotCenterLabel(order);
    if (centerText.isNotEmpty) {
      canvas.drawThreeColRow('', centerText, '', canvas.styleFor(style.kotOrderInfo2));
    }

    final custName = (order.userCustName ?? '').trim();
    final custPhone = (order.userCustPhone ?? '').trim();
    if (custName.isNotEmpty || custPhone.isNotEmpty) {
      canvas.drawThreeColRow(
        custName,
        '',
        custPhone,
        canvas.styleFor(style.kotOrderInfo3),
      );
    }

    if (order.dailyToken.isNotEmpty) {
      canvas.drawThreeColRow(
        '',
        'Token No: ${order.dailyToken}',
        '',
        canvas.styleFor(style.kotOrderInfo4),
      );
    }

    canvas.drawRule(solid);

    final srW = canvas.contentWidthPx * 0.12;
    final qtyW = canvas.contentWidthPx * 0.18;
    final itemW = canvas.contentWidthPx - srW - qtyW;
    final headerStyle = canvas.styleFor(style.kotTableHeader);
    canvas.drawTableRow([
      ReceiptTableCell('SR', srW),
      ReceiptTableCell(' ITEM', itemW),
      ReceiptTableCell('QTY', qtyW, align: TextAlign.right),
    ], headerStyle);

    canvas.drawRule(solid);

    var srNo = 1;
    final contentStyle = canvas.styleFor(style.kotTableContent);
    for (final item in order.items) {
      if (skipCancelledItems && item.foodStatus == 3) continue;

      canvas.drawTableRow([
        ReceiptTableCell('${srNo++}.', srW),
        ReceiptTableCell(item.name.trim(), itemW),
        ReceiptTableCell('${ReceiptBusinessLogic.qtyDisplay(item)}  ', qtyW,
            align: TextAlign.right),
      ], contentStyle);

      for (final line in ReceiptBusinessLogic.groupKotModifiers(item.variations, '-')) {
        canvas.drawWrappedIndented('   ', line, contentStyle, indent: 16);
      }
      for (final line in ReceiptBusinessLogic.groupKotModifiers(item.addons, '+')) {
        canvas.drawWrappedIndented('   ', line, contentStyle, indent: 16);
      }
      if (item.note.isNotEmpty) {
        canvas.drawWrappedIndented(
          '   ',
          'Note: ${item.note.trim()}',
          contentStyle,
          indent: 16,
        );
      }
    }

    if (includeOrderNote && order.orderNote.trim().isNotEmpty) {
      canvas.drawRule(solid);
      canvas.drawText(
        'Notes: ${order.orderNote.trim()}',
        canvas.styleFor(style.kotNote),
        align: TextAlign.center,
      );
    }

    canvas.drawRule(solid);
    canvas.drawText(
      PrintConfig.poweredByFooter,
      canvas.styleFor(style.footer),
      align: TextAlign.center,
    );

    return canvas;
  }
}
