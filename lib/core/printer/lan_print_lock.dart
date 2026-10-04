import 'dart:async';

/// Serializes LAN/Wi-Fi print jobs per physical printer (`ip:port`).
///
/// Kitchen + Bill can share one TCP printer. Port 9100 typically accepts a
/// single client — concurrent connects from two queues cause timeouts.
/// Different IPs are not blocked by each other.
class LanPrintLock {
  LanPrintLock._();

  static final Map<String, Future<void>> _tails = {};

  static String key(String ipAddress, int port) => '$ipAddress:$port';

  static Future<T> exclusive<T>(
    String ipAddress,
    int port,
    Future<T> Function() action,
  ) async {
    final k = key(ipAddress, port);
    final previous = _tails[k] ?? Future<void>.value();
    final gate = Completer<void>();
    _tails[k] = gate.future;

    await previous;
    try {
      return await action();
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  }
}
