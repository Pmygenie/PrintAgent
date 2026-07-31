import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/print_style_config.dart';
import 'package:printer_agent/core/printer/bitmap/print_style_extensions.dart';
import 'package:printer_agent/core/printer/bitmap/receipt_business_logic.dart';
import 'package:printer_agent/core/printer/receipt_text_renderer.dart';

/// Records receipt layout ops then rasterizes to a single [ui.Image].
class ReceiptCanvas {
  ReceiptCanvas({
    required this.style,
    required this.fontFamily,
    this.dotsPerMm = 8,
    this.renderScale = 3.0,
  })  : paperWidthPx = (PrintConfig.is80mm ? 576 : 384),
        _contentLeftPx = style.marginLeftPx(dotsPerMm),
        _contentRightPx = style.marginRightPx(dotsPerMm),
        _topPx = style.marginTopPx(dotsPerMm),
        _bottomPx = style.marginBottomPx(dotsPerMm) {
    contentWidthPx = paperWidthPx - _contentLeftPx - _contentRightPx;
  }

  final PrintStyleConfig style;
  final String fontFamily;
  final double dotsPerMm;
  final double renderScale;
  final int paperWidthPx;
  late final double contentWidthPx;

  final double _contentLeftPx;
  final double _contentRightPx;
  final double _topPx;
  final double _bottomPx;

  final List<_DrawOp> _ops = [];
  double _contentHeight = 0;

  static String? _loadedFamily;
  static String? _gujaratiFamily;

  /// Load receipt fonts once per app session.
  static Future<String> ensureFonts(PrintStyleConfig config) async {
    final family = _mapFontFamily(config.fontFamily);
    if (_loadedFamily == family) return family;

    if (family == 'ReceiptGujarati') {
      await ReceiptTextRenderer.ensureGujaratiFont();
      _gujaratiFamily = 'ReceiptGujarati';
      _loadedFamily = family;
      return family;
    }

    final loader = FontLoader(family);
    for (final entry in _fontAssets(family)) {
      loader.addFont(rootBundle.load(entry));
    }
    await loader.load();
    _loadedFamily = family;
    return family;
  }

  static String _mapFontFamily(String name) {
    switch (name) {
      case 'Roboto':
        return 'Roboto';
      case 'Poppins':
        return 'Poppins';
      case 'Gujarati':
        return 'ReceiptGujarati';
      case 'Montserrat':
      default:
        return 'Montserrat';
    }
  }

  static List<String> _fontAssets(String family) {
    switch (family) {
      case 'Roboto':
        return [
          'assets/fonts/Roboto-Regular.ttf',
          'assets/fonts/Roboto-Bold.ttf',
        ];
      case 'Poppins':
        return [
          'assets/fonts/Poppins-Regular.ttf',
          'assets/fonts/Poppins-Bold.ttf',
        ];
      case 'Montserrat':
      default:
        return [
          'assets/fonts/Montserrat-Regular.ttf',
          'assets/fonts/Montserrat-Bold.ttf',
        ];
    }
  }

  TextStyle styleFor(
    PrintStyleItem item, {
    double? letterSpacing,
    double? height,
  }) =>
      style.textStyle(
        item,
        fontFamily: fontFamily,
        letterSpacing: letterSpacing,
        height: height,
      );

  TextStyle _resolveStyle(String text, TextStyle base) {
    if (ReceiptTextRenderer.containsGujarati(text) && _gujaratiFamily != null) {
      return base.copyWith(fontFamily: _gujaratiFamily);
    }
    return base;
  }

  void gap([double px = 4]) {
    _contentHeight += px;
    _ops.add(_GapOp(px * renderScale));
  }

  void drawText(
    String text,
    TextStyle baseStyle, {
    TextAlign align = TextAlign.left,
    double? maxWidth,
    double afterGap = 2,
  }) {
    if (text.isEmpty) return;
    final resolved = _resolveStyle(text, baseStyle);
    final limit = (maxWidth ?? contentWidthPx) * renderScale;
    final painter = TextPainter(
      text: TextSpan(text: text, style: resolved.copyWith(fontSize: (resolved.fontSize ?? 10) * renderScale)),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: limit);

    final h = painter.height / renderScale;
    _ops.add(_TextOp(
      text: text,
      style: resolved,
      align: align,
      maxWidth: maxWidth ?? contentWidthPx,
      scale: renderScale,
    ));
    _contentHeight += h + afterGap;
  }

  void drawCenteredLines(String text, TextStyle baseStyle, {double afterGap = 2}) {
    for (final line in text.split('\n')) {
      drawText(line, baseStyle, align: TextAlign.center, afterGap: afterGap);
    }
  }

  void drawThreeColRow(
    String left,
    String center,
    String right,
    TextStyle baseStyle,
  ) {
    final colW = contentWidthPx / 3;
    final leftLines = _wrapLines(left, colW, baseStyle);
    final centerLines = _wrapLines(center, colW, baseStyle);
    final rightLines = _wrapLines(right, colW, baseStyle);
    final maxLines = [leftLines.length, centerLines.length, rightLines.length]
        .reduce((a, b) => a > b ? a : b);

    for (var i = 0; i < maxLines; i++) {
      final l = i < leftLines.length ? leftLines[i] : '';
      final c = i < centerLines.length ? centerLines[i] : '';
      final r = i < rightLines.length ? rightLines[i] : '';
      _ops.add(_ThreeColOp(
        left: l,
        center: c,
        right: r,
        style: baseStyle,
        colWidth: colW,
        scale: renderScale,
      ));
      _contentHeight += _lineHeight(baseStyle) + 2;
    }
  }

  void drawLabelValue(
    String label,
    String value,
    TextStyle baseStyle, {
    double valueWidth = 56,
  }) {
    _ops.add(_LabelValueOp(
      label: label,
      value: value,
      style: baseStyle,
      valueWidth: valueWidth,
      contentWidth: contentWidthPx,
      scale: renderScale,
    ));
    _contentHeight += _lineHeight(baseStyle) + 2;
  }

  void drawLeftRight(
    String left,
    String right,
    TextStyle baseStyle,
  ) {
    _ops.add(_LeftRightOp(
      left: left,
      right: right,
      style: baseStyle,
      contentWidth: contentWidthPx,
      scale: renderScale,
    ));
    _contentHeight += _lineHeight(baseStyle) + 2;
  }

  void drawDivider({bool dashed = false}) {
    final h = dashed ? 6.0 : 4.0;
    _ops.add(_DividerOp(
      width: contentWidthPx,
      dashed: dashed,
      scale: renderScale,
      height: h,
    ));
    _contentHeight += h + 4;
  }

  void drawSolidRule() => drawDivider(dashed: false);

  void drawDottedRule() => drawDivider(dashed: true);

  void drawRule(bool solid) => solid ? drawSolidRule() : drawDottedRule();

  Future<void> drawImageBytes(
    Uint8List bytes, {
    double? targetWidthPx,
    TextAlign align = TextAlign.center,
  }) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    var w = targetWidthPx ?? contentWidthPx;
    if (w > contentWidthPx) w = contentWidthPx;
    final aspect = img.height / img.width;
    final h = w * aspect;
    _ops.add(_ImageOp(
      image: img,
      width: w,
      height: h,
      align: align,
      contentWidth: contentWidthPx,
      scale: renderScale,
    ));
    _contentHeight += h + 6;
  }

  void drawBitmapImage(
    ui.Image image, {
    double? targetWidthPx,
    TextAlign align = TextAlign.center,
  }) {
    var w = targetWidthPx ?? contentWidthPx;
    if (w > contentWidthPx) w = contentWidthPx;
    final aspect = image.height / image.width;
    final h = w * aspect;
    _ops.add(_ImageOp(
      image: image,
      width: w,
      height: h,
      align: align,
      contentWidth: contentWidthPx,
      scale: renderScale,
    ));
    _contentHeight += h + 6;
  }

  /// Simple QR placeholder via text until qr package is added; renders data matrix style block.
  Future<void> drawQr(String data, {double size = 96}) async {
    if (data.isEmpty) return;
    // Render QR as centered monospace block label for now — extensible hook.
    drawText(
      data,
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 8,
        color: Colors.black,
      ),
      align: TextAlign.center,
      maxWidth: size,
    );
  }

  double _lineHeight(TextStyle style) =>
      (style.fontSize ?? 10) * (style.height ?? 1.15);

  List<String> _wrapLines(String text, double maxWidth, TextStyle style) {
    if (text.trim().isEmpty) return [''];
    final resolved = _resolveStyle(text, style);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: resolved.copyWith(fontSize: (resolved.fontSize ?? 10) * renderScale),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth * renderScale);

    if (!painter.didExceedMaxLines && painter.computeLineMetrics().length <= 1) {
      return [text];
    }

    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final trial = current.isEmpty ? word : '$current $word';
      final tp = TextPainter(
        text: TextSpan(
          text: trial,
          style: resolved.copyWith(fontSize: (resolved.fontSize ?? 10) * renderScale),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth * renderScale);
      if (tp.width <= maxWidth * renderScale + 1) {
        current = trial;
      } else {
        if (current.isNotEmpty) lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [''] : lines;
  }

  void drawTableRow(
    List<ReceiptTableCell> cells,
    TextStyle style, {
    double afterGap = 2,
  }) {
    _ops.add(_TableRowOp(cells: cells, style: style, scale: renderScale));
    _contentHeight += _lineHeight(style) + afterGap;
  }

  void drawWrappedIndented(
    String prefix,
    String text,
    TextStyle style, {
    double indent = 12,
  }) {
    final firstWidth = contentWidthPx - indent;
    final lines = _wrapLines(text, firstWidth, style);
    for (var i = 0; i < lines.length; i++) {
      final line = i == 0 ? '$prefix${lines[i]}' : '${' ' * prefix.length}${lines[i]}';
      drawText(line, style, maxWidth: contentWidthPx);
    }
  }

  Future<ui.Image> buildImage() async {
    final totalH = (_topPx + _contentHeight + _bottomPx).ceil().clamp(1, 65535);
    final scaledW = (paperWidthPx * renderScale).ceil();
    final scaledH = (totalH * renderScale).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, scaledW.toDouble(), scaledH.toDouble()),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, scaledW.toDouble(), scaledH.toDouble()),
      Paint()..color = Colors.white,
    );

    var y = _topPx * renderScale;
    final left = _contentLeftPx * renderScale;

    for (final op in _ops) {
      y = op.paint(canvas, left, y, renderScale);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(scaledW, scaledH);

    // Downscale to printer DPI width.
    final targetW = paperWidthPx;
    final targetH = (scaledH / renderScale).ceil().clamp(1, 65535);
    if (scaledW == targetW && scaledH == targetH) return image;

    final recorder2 = ui.PictureRecorder();
    final canvas2 = Canvas(
      recorder2,
      Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
    );
    canvas2.drawRect(
      Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
      Paint()..color = Colors.white,
    );
    paintImage(
      canvas: canvas2,
      rect: Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
      image: image,
      filterQuality: FilterQuality.medium,
    );
    image.dispose();
    final out = await recorder2.endRecording().toImage(targetW, targetH);
    return out;
  }
}

class ReceiptTableCell {
  final String text;
  final double width;
  final TextAlign align;

  const ReceiptTableCell(
    this.text,
    this.width, {
    this.align = TextAlign.left,
  });
}

abstract class _DrawOp {
  double paint(Canvas canvas, double left, double y, double scale);
}

class _GapOp implements _DrawOp {
  _GapOp(this.gap);
  final double gap;
  @override
  double paint(Canvas canvas, double left, double y, double scale) => y + gap;
}

class _TextOp implements _DrawOp {
  _TextOp({
    required this.text,
    required this.style,
    required this.align,
    required this.maxWidth,
    required this.scale,
  });

  final String text;
  final TextStyle style;
  final TextAlign align;
  final double maxWidth;
  final double scale;

  @override
  double paint(Canvas canvas, double left, double y, double scale) {
    final resolved = ReceiptTextRenderer.containsGujarati(text)
        ? style.copyWith(fontFamily: 'ReceiptGujarati')
        : style;
    final fs = (resolved.fontSize ?? 10) * scale;
    final painter = TextPainter(
      text: TextSpan(text: text, style: resolved.copyWith(fontSize: fs)),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth * scale);

    var dx = left;
    if (align == TextAlign.center) {
      dx = left + (maxWidth * scale - painter.width) / 2;
    } else if (align == TextAlign.right) {
      dx = left + maxWidth * scale - painter.width;
    }
    painter.paint(canvas, Offset(dx, y));
    return y + painter.height;
  }
}

class _ThreeColOp implements _DrawOp {
  _ThreeColOp({
    required this.left,
    required this.center,
    required this.right,
    required this.style,
    required this.colWidth,
    required this.scale,
  });

  final String left;
  final String center;
  final String right;
  final TextStyle style;
  final double colWidth;
  final double scale;

  @override
  double paint(Canvas canvas, double lx, double y, double scale) {
    var maxH = 0.0;
    maxH = [
      _paintCell(canvas, left, lx, y, colWidth, TextAlign.left, scale),
      _paintCell(canvas, center, lx + colWidth * scale, y, colWidth, TextAlign.center, scale),
      _paintCell(canvas, right, lx + colWidth * 2 * scale, y, colWidth, TextAlign.right, scale),
    ].reduce((a, b) => a > b ? a : b);
    return y + maxH;
  }

  double _paintCell(
    Canvas canvas,
    String text,
    double x,
    double y,
    double w,
    TextAlign align,
    double scale,
  ) {
    if (text.isEmpty) return 0;
    final resolved = ReceiptTextRenderer.containsGujarati(text)
        ? style.copyWith(fontFamily: 'ReceiptGujarati')
        : style;
    final fs = (resolved.fontSize ?? 10) * scale;
    final painter = TextPainter(
      text: TextSpan(text: text, style: resolved.copyWith(fontSize: fs)),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * scale);
    var dx = x;
    if (align == TextAlign.center) {
      dx = x + (w * scale - painter.width) / 2;
    } else if (align == TextAlign.right) {
      dx = x + w * scale - painter.width;
    }
    painter.paint(canvas, Offset(dx, y));
    return painter.height;
  }
}

class _LabelValueOp implements _DrawOp {
  _LabelValueOp({
    required this.label,
    required this.value,
    required this.style,
    required this.valueWidth,
    required this.contentWidth,
    required this.scale,
  });

  final String label;
  final String value;
  final TextStyle style;
  final double valueWidth;
  final double contentWidth;
  final double scale;

  @override
  double paint(Canvas canvas, double left, double y, double scale) {
    final innerW = contentWidth * 0.75;
    final labelW = innerW - valueWidth - 8;
    final labelText = ReceiptBusinessLogic.truncate(label, 32);
    final line = '${labelText.padRight(labelW.toInt())}: ${value.padLeft(7)}';
    final op = _TextOp(
      text: line,
      style: style,
      align: TextAlign.right,
      maxWidth: contentWidth,
      scale: scale,
    );
    return op.paint(canvas, left, y, scale);
  }
}

class _LeftRightOp implements _DrawOp {
  _LeftRightOp({
    required this.left,
    required this.right,
    required this.style,
    required this.contentWidth,
    required this.scale,
  });

  final String left;
  final String right;
  final TextStyle style;
  final double contentWidth;
  final double scale;

  @override
  double paint(Canvas canvas, double lx, double y, double scale) {
    final fs = (style.fontSize ?? 10) * scale;
    final resolved = style;
    final lp = TextPainter(
      text: TextSpan(text: left, style: resolved.copyWith(fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rp = TextPainter(
      text: TextSpan(text: right, style: resolved.copyWith(fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(lx, y));
    rp.paint(canvas, Offset(lx + contentWidth * scale - rp.width, y));
    return y + [lp.height, rp.height].reduce((a, b) => a > b ? a : b);
  }
}

class _DividerOp implements _DrawOp {
  _DividerOp({
    required this.width,
    required this.dashed,
    required this.scale,
    required this.height,
  });

  final double width;
  final bool dashed;
  final double scale;
  final double height;

  @override
  double paint(Canvas canvas, double left, double y, double scale) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1 * scale;
    final w = width * scale;
    if (dashed) {
      const dash = 4.0;
      var x = left;
      while (x < left + w) {
        canvas.drawLine(
          Offset(x, y + height * scale / 2),
          Offset((x + dash * scale).clamp(0, left + w), y + height * scale / 2),
          paint,
        );
        x += dash * 2 * scale;
      }
    } else {
      canvas.drawLine(
        Offset(left, y + height * scale / 2),
        Offset(left + w, y + height * scale / 2),
        paint,
      );
    }
    return y + height * scale;
  }
}

class _ImageOp implements _DrawOp {
  _ImageOp({
    required this.image,
    required this.width,
    required this.height,
    required this.align,
    required this.contentWidth,
    required this.scale,
  });

  final ui.Image image;
  final double width;
  final double height;
  final TextAlign align;
  final double contentWidth;
  final double scale;

  @override
  double paint(Canvas canvas, double left, double y, double scale) {
    var dx = left;
    if (align == TextAlign.center) {
      dx = left + (contentWidth * scale - width * scale) / 2;
    } else if (align == TextAlign.right) {
      dx = left + contentWidth * scale - width * scale;
    }
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(dx, y, width * scale, height * scale),
      image: image,
      filterQuality: FilterQuality.medium,
    );
    return y + height * scale;
  }
}

class _TableRowOp implements _DrawOp {
  _TableRowOp({
    required this.cells,
    required this.style,
    required this.scale,
  });

  final List<ReceiptTableCell> cells;
  final TextStyle style;
  final double scale;

  @override
  double paint(Canvas canvas, double left, double y, double scale) {
    var x = left;
    var maxH = 0.0;
    for (final cell in cells) {
      final resolved = ReceiptTextRenderer.containsGujarati(cell.text)
          ? style.copyWith(fontFamily: 'ReceiptGujarati')
          : style;
      final fs = (resolved.fontSize ?? 10) * scale;
      final painter = TextPainter(
        text: TextSpan(text: cell.text, style: resolved.copyWith(fontSize: fs)),
        textAlign: cell.align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cell.width * scale);

      var dx = x;
      if (cell.align == TextAlign.center) {
        dx = x + (cell.width * scale - painter.width) / 2;
      } else if (cell.align == TextAlign.right) {
        dx = x + cell.width * scale - painter.width;
      }
      painter.paint(canvas, Offset(dx, y));
      maxH = maxH > painter.height ? maxH : painter.height;
      x += cell.width * scale;
    }
    return y + maxH;
  }
}
