import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// Splits a tall receipt bitmap into printer-safe chunks.
class ImageChunker {
  ImageChunker._();

  /// Default max chunk height in pixels at 203 DPI (~75 mm).
  static const int defaultMaxChunkHeightPx = 2400;

  /// Splits [source] into horizontal strips no taller than [maxHeightPx].
  static Future<List<img.Image>> splitUiImage(
    ui.Image source, {
    int maxHeightPx = defaultMaxChunkHeightPx,
  }) async {
    final full = await _uiToPackageImage(source);
    return splitPackageImage(full, maxHeightPx: maxHeightPx);
  }

  static List<img.Image> splitPackageImage(
    img.Image source, {
    int maxHeightPx = defaultMaxChunkHeightPx,
  }) {
    if (source.height <= maxHeightPx) return [source];

    final chunks = <img.Image>[];
    var y = 0;
    while (y < source.height) {
      final h = (y + maxHeightPx > source.height)
          ? source.height - y
          : maxHeightPx;
      chunks.add(img.copyCrop(source, x: 0, y: y, width: source.width, height: h));
      y += h;
    }
    return chunks;
  }

  static Future<img.Image> _uiToPackageImage(ui.Image image) async {
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode receipt bitmap');
    }
    final decoded = img.decodeImage(byteData.buffer.asUint8List());
    if (decoded == null) {
      throw Exception('Failed to decode receipt bitmap');
    }
    return decoded;
  }

  static Future<img.Image> uiImageToPackageImage(ui.Image image) =>
      _uiToPackageImage(image);
}
