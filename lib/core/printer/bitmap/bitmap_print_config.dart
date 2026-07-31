/// Toggle bitmap receipt rendering without modifying [PrintConfig].
///
/// When enabled, [PrinterManager] uses [BitmapFormatter] instead of
/// [EscPosFormatter] for Bluetooth, LAN, and USB (non-PDF) paths.
class BitmapPrintConfig {
  BitmapPrintConfig._();

  static bool enabled = false;
}
