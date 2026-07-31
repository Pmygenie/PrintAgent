import 'package:printer_agent/core/models/print_job.dart';
import 'package:printer_agent/core/printer/bitmap/bitmap_generator.dart';
import 'package:printer_agent/core/printer/bitmap/receipt_canvas.dart';
import 'package:printer_agent/core/printer/bitmap/receipt_renderer.dart';
import 'package:printer_agent/core/services/print_style_service.dart';

/// Bitmap-based thermal receipt formatter.
///
/// Renders the full receipt with Flutter canvas, splits into chunks if needed,
/// and outputs ESC/POS bytes via [Generator.image] only.
///
/// Existing [EscPosFormatter] is unchanged. Enable via [BitmapPrintConfig].
class BitmapFormatter {
  BitmapFormatter._();

  static Future<List<int>> format(PrintJob job) async {
    final style = await PrintStyleService.getConfig();
    final fontFamily = await ReceiptCanvas.ensureFonts(style);

    final image = await ReceiptRenderer.render(
      job: job,
      style: style,
      fontFamily: fontFamily,
    );

    try {
      return await BitmapGenerator.toEscPosBytes(image);
    } finally {
      image.dispose();
    }
  }
}
