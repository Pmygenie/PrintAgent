import 'dart:ui' as ui;

import 'package:printer_agent/core/models/print_job.dart';
import 'package:printer_agent/core/models/print_style_config.dart';
import 'package:printer_agent/core/profile/restaurant_profile_service.dart';
import 'package:printer_agent/core/printer/bitmap/bill_renderer.dart';
import 'package:printer_agent/core/printer/bitmap/cancel_kot_renderer.dart';
import 'package:printer_agent/core/printer/bitmap/kot_renderer.dart';

class ReceiptRenderer {
  ReceiptRenderer._();

  static Future<ui.Image> render({
    required PrintJob job,
    required PrintStyleConfig style,
    required String fontFamily,
  }) async {
    switch (job.type) {
      case PrintType.kot:
        final canvas = await KotRenderer.render(
          order: job.order,
          style: style,
          fontFamily: fontFamily,
          stationLabel: job.stationLabel,
        );
        return canvas.buildImage();

      case PrintType.cancelKot:
        final cancelCanvas = await CancelKotRenderer.render(
          order: job.order,
          style: style,
          fontFamily: fontFamily,
          stationLabel: job.stationLabel,
        );
        return cancelCanvas.buildImage();

      case PrintType.bill:
        final profile = await RestaurantProfileService.getProfile();
        final billCanvas = await BillRenderer.render(
          order: job.order,
          style: style,
          fontFamily: fontFamily,
          profile: profile,
        );
        return billCanvas.buildImage();
    }
  }
}
