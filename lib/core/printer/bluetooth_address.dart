/// Helpers for Bluetooth device addresses across Android BLE and Windows SPP.
///
/// Windows classic paths look like:
/// `Bluetooth#Bluetooth<local>-<remote>#RFCOMM:…`
/// The **remote** (last) MAC is the printer — same value Android reports.
class BluetoothAddress {
  BluetoothAddress._();

  static final RegExp _macRe =
      RegExp(r'([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}');

  /// Formats a raw MAC token as `XX:XX:XX:XX:XX:XX`.
  static String formatMac(String raw) => raw
      .replaceAll('-', ':')
      .toUpperCase()
      .split(':')
      .map((b) => b.padLeft(2, '0'))
      .join(':');

  /// Hex-only uppercase form for comparisons.
  static String normalize(String address) =>
      address.replaceAll(RegExp(r'[^a-fA-F0-9]'), '').toUpperCase();

  /// Printer MAC from a BLE address or Windows RFCOMM path.
  ///
  /// When multiple MACs appear (Windows local-remote), uses the **last** one
  /// (remote device / printer), matching Android.
  static String? extractPrinterMac(String raw) {
    final matches = _macRe.allMatches(raw).toList();
    if (matches.isEmpty) return null;
    return formatMac(matches.last.group(0)!);
  }

  /// Short label for UI — printer MAC, or a truncated fallback.
  static String displayMac(String raw) =>
      extractPrinterMac(raw) ??
      (raw.length > 28 ? '${raw.substring(0, 28)}…' : raw);

  /// True when [a] and [b] refer to the same printer.
  static bool samePrinter(String a, String b) {
    final ma = extractPrinterMac(a);
    final mb = extractPrinterMac(b);
    if (ma != null && mb != null) {
      return normalize(ma) == normalize(mb);
    }
    if (ma != null && normalize(b).contains(normalize(ma))) return true;
    if (mb != null && normalize(a).contains(normalize(mb))) return true;
    return normalize(a) == normalize(b);
  }
}
