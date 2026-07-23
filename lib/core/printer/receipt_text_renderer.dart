import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class _CachedTextImage {
  final Uint8List bytes;
  final double widthPt;
  final double heightPt;

  const _CachedTextImage({
    required this.bytes,
    required this.widthPt,
    required this.heightPt,
  });
}

/// Renders receipt text as [pw.Text], or as a shaped PNG image when the
/// string contains Gujarati (package:pdf mishandles conjuncts).
class ReceiptTextRenderer {
  ReceiptTextRenderer._();

  static const _gujaratiFamily = 'ReceiptGujarati';
  static const _scale = 3.0;
  static const _gujaratiRe = r'[\u0A80-\u0AFF]';

  static bool _fontReady = false;
  static final Map<String, _CachedTextImage> _imageCache = {};

  /// Clear per-PDF-generation image cache (call at start of each format).
  static void clearCache() => _imageCache.clear();

  static bool containsGujarati(String text) =>
      RegExp(_gujaratiRe).hasMatch(text);

  static Future<void> ensureGujaratiFont() async {
    if (_fontReady) return;

    Future<ByteData> loadTtf(String fileName) async {
      final uri = Uri.parse(
        'https://raw.githubusercontent.com/google/fonts/main/ofl/hindvadodara/$fileName',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw Exception('Failed to load $fileName (${res.statusCode})');
      }
      return ByteData.sublistView(res.bodyBytes);
    }

    final loader = FontLoader(_gujaratiFamily);
    loader.addFont(loadTtf('HindVadodara-Regular.ttf'));
    loader.addFont(loadTtf('HindVadodara-Bold.ttf'));
    await loader.load();
    _fontReady = true;
  }

  /// Rasterize [text] with Flutter shaping (correct Gujarati conjuncts).
  static Future<Uint8List> renderTextToImage(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
    TextAlign textAlign = TextAlign.left,
  }) async {
    final cached = await _renderCached(
      text,
      style,
      maxWidth: maxWidth,
      textAlign: textAlign,
    );
    return cached.bytes;
  }

  static Future<_CachedTextImage> _renderCached(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
    TextAlign textAlign = TextAlign.left,
  }) async {
    await ensureGujaratiFont();

    final fontSize = style.fontSize ?? 10;
    final bold = style.fontWeight == FontWeight.bold;
    final cacheKey =
        '$text|$fontSize|$bold|${textAlign.index}|${maxWidth.isFinite ? maxWidth.toStringAsFixed(1) : 0}';

    final hit = _imageCache[cacheKey];
    if (hit != null) return hit;

    final scaled = style.copyWith(
      fontSize: fontSize * _scale,
      fontFamily: _gujaratiFamily,
      color: style.color ?? Colors.black,
      height: style.height ?? 1.15,
    );

    final layoutMax = maxWidth.isFinite ? maxWidth * _scale : double.infinity;

    final painter = TextPainter(
      text: TextSpan(text: text, style: scaled),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: layoutMax);

    // Slight padding so glyphs aren't clipped at edges.
    final width = (painter.width + 2).ceil().clamp(1, 4000);
    final height = (painter.height + 2).ceil().clamp(1, 4000);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Offset(1, 1));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();

    if (byteData == null) {
      throw Exception('Failed to encode text image for: $text');
    }

    var widthPt = width / _scale;
    var heightPt = height / _scale;

    // Hard clamp so PDF flex never sees a child wider than the column.
    if (maxWidth.isFinite && widthPt > maxWidth) {
      final scaleDown = maxWidth / widthPt;
      widthPt = maxWidth;
      heightPt = heightPt * scaleDown;
    }

    final cached = _CachedTextImage(
      bytes: byteData.buffer.asUint8List(),
      widthPt: widthPt,
      heightPt: heightPt,
    );
    _imageCache[cacheKey] = cached;
    return cached;
  }

  /// English / non-Gujarati → [pw.Text]. Gujarati / mixed → [pw.Image].
  ///
  /// Always pass [maxWidth] when placing inside a [pw.Expanded] / Row cell,
  /// otherwise a long Gujarati string can overflow and crash PDF layout.
  static Future<pw.Widget> buildReceiptText(
    String text, {
    PdfColor? color,
    double fontSize = 9,
    FontWeight fontWeight = FontWeight.normal,
    TextAlign textAlign = TextAlign.left,
    pw.TextStyle? pdfStyle,
    pw.TextAlign? pdfTextAlign,
    double? maxWidth,
  }) async {
    if (text.isEmpty) {
      return pw.SizedBox();
    }

    final resolvedPdfAlign = pdfTextAlign ??
        switch (textAlign) {
          TextAlign.center => pw.TextAlign.center,
          TextAlign.right => pw.TextAlign.right,
          TextAlign.justify => pw.TextAlign.justify,
          _ => pw.TextAlign.left,
        };

    if (!containsGujarati(text)) {
      final style = pdfStyle ??
          pw.TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight == FontWeight.bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: color,
          );
      return pw.Text(
        text,
        style: color != null && pdfStyle != null
            ? pdfStyle.copyWith(color: color)
            : style,
        textAlign: resolvedPdfAlign,
      );
    }

    try {
      final size = pdfStyle?.fontSize ?? fontSize;
      final bold = pdfStyle != null
          ? pdfStyle.fontWeight == pw.FontWeight.bold
          : fontWeight == FontWeight.bold;

      final limit = maxWidth ?? double.infinity;

      final cached = await _renderCached(
        text,
        TextStyle(
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: Colors.black,
        ),
        maxWidth: limit,
        textAlign: textAlign,
      );

      final w = limit.isFinite
          ? math.min(cached.widthPt, limit)
          : cached.widthPt;
      final h = cached.widthPt > 0
          ? cached.heightPt * (w / cached.widthPt)
          : cached.heightPt;

      final widget = pw.Image(
        pw.MemoryImage(cached.bytes),
        width: w,
        height: h,
        fit: pw.BoxFit.contain,
      );

      // Keep intrinsic width = painted text width (not full column),
      // so Expanded siblings (QTY) keep correct flex space.
      final boxed = limit.isFinite
          ? pw.ConstrainedBox(
              constraints: pw.BoxConstraints(maxWidth: limit),
              child: widget,
            )
          : widget;

      return switch (resolvedPdfAlign) {
        pw.TextAlign.center => pw.Center(child: boxed),
        pw.TextAlign.right => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: boxed,
          ),
        _ => boxed,
      };
    } catch (_) {
      // Font download / rasterize failed — fall back to pw.Text
      final style = pdfStyle ??
          pw.TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight == FontWeight.bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: color,
          );
      return pw.Text(text, style: style, textAlign: resolvedPdfAlign);
    }
  }
}
