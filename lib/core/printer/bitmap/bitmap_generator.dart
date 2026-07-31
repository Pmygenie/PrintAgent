import 'dart:ui' as ui;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/printer/bitmap/image_chunker.dart';

/// Converts receipt bitmaps to ESC/POS bytes using [Generator.image] only.
class BitmapGenerator {
  BitmapGenerator._();

  static Future<List<int>> toEscPosBytes(
    ui.Image receiptImage, {
    int maxChunkHeightPx = ImageChunker.defaultMaxChunkHeightPx,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = PrintConfig.is80mm ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final full = await ImageChunker.uiImageToPackageImage(receiptImage);
    final targetWidth = paperSize.width;
    final resized = full.width == targetWidth
        ? full
        : img.copyResize(full, width: targetWidth);

    final chunks = ImageChunker.splitPackageImage(
      resized,
      maxHeightPx: maxChunkHeightPx,
    );

    final bytes = <int>[];
    for (final chunk in chunks) {
      bytes.addAll(generator.image(chunk, align: PosAlign.center));
    }
    bytes.addAll(generator.cut());
    return bytes;
  }
}
