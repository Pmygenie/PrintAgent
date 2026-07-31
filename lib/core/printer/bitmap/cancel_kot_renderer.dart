import 'package:printer_agent/core/models/print_style_config.dart';
import 'package:printer_agent/core/models/restaurant_order.dart';
import 'package:printer_agent/core/printer/bitmap/kot_renderer.dart';
import 'package:printer_agent/core/printer/bitmap/receipt_canvas.dart';

class CancelKotRenderer {
  static Future<ReceiptCanvas> render({
    required RestaurantOrder order,
    required PrintStyleConfig style,
    required String fontFamily,
    String? stationLabel,
  }) {
    return KotRenderer.render(
      order: order,
      style: style,
      fontFamily: fontFamily,
      stationLabel: stationLabel,
      skipCancelledItems: false,
      isCancel: true,
      includeOrderNote: false,
    );
  }
}
