import 'package:flutter/material.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/print_style_config.dart';

/// Helpers to turn [PrintStyleConfig] into Flutter [TextStyle] values.
extension PrintStyleItemX on PrintStyleItem {
  double resolvedSize([bool? is80mm]) {
    final wide = is80mm ?? PrintConfig.is80mm;
    return wide ? size80 : size58;
  }
}

extension PrintStyleConfigX on PrintStyleConfig {
  bool get useSolidDivider => dividerStyle == 'Solid';

  double marginLeftPx([double dotsPerMm = 8]) => marginLeftMm * dotsPerMm;

  double marginRightPx([double dotsPerMm = 8]) => marginRightMm * dotsPerMm;

  double marginTopPx([double dotsPerMm = 8]) => marginTopMm * dotsPerMm;

  double marginBottomPx([double dotsPerMm = 8]) => marginBottomMm * dotsPerMm;

  TextStyle textStyle(
    PrintStyleItem item, {
    required String fontFamily,
    bool? is80mm,
    TextAlign align = TextAlign.left,
    double? letterSpacing,
    double? height,
    Color color = Colors.black,
  }) {
    final size = item.resolvedSize(is80mm);
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
      letterSpacing: letterSpacing,
      height: height ?? 1.15,
      color: color,
    );
  }
}
