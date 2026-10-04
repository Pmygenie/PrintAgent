import 'package:printer_agent/drivers/lan_driver.dart';

/// Process-wide keep-alive LAN sessions, keyed by `ip:port`.
///
/// First print connects and caches the driver. Later prints reuse the TCP
/// socket (no per-job disconnect). A sleepy Wi-Fi printer often misses a
/// fresh connect, so the session is only evicted on send failure.
class LanSessionRegistry {
  LanSessionRegistry._();

  static final Map<String, LanPrinterDriver> _sessions = {};

  static String cacheKey(String ipAddress, int port) => '$ipAddress:$port';

  static Future<void> _evict(String key, LanPrinterDriver driver) async {
    if (_sessions[key] == driver) {
      _sessions.remove(key);
      print('[LAN] SESSION REMOVED $key');
    }
    await driver.disconnect();
  }

  /// Runs [action] on a live LAN session for [ipAddress]:[port].
  ///
  /// Must be called under [LanPrintLock] by the caller.
  static Future<void> run({
    required String ipAddress,
    required int port,
    required Future<void> Function(LanPrinterDriver driver) action,
  }) async {
    final key = cacheKey(ipAddress, port);

    Future<LanPrinterDriver> openSession() async {
      print('[LAN] SESSION MISS $key → connecting');
      final driver = LanPrinterDriver(ipAddress: ipAddress, port: port);
      await driver.connect();
      _sessions[key] = driver;
      return driver;
    }

    var driver = _sessions[key];
    if (driver != null && driver.isConnected) {
      print('[LAN] SESSION HIT $key → reusing connection');
      try {
        await action(driver);
        print('[LAN] SEND SUCCESS $key');
        return;
      } catch (_) {
        print('[LAN] SEND FAILED $key → reconnecting');
        await _evict(key, driver);
      }
    } else {
      if (driver != null) {
        await _evict(key, driver);
      }
      driver = await openSession();
      try {
        await action(driver);
        print('[LAN] SEND SUCCESS $key');
        return;
      } catch (_) {
        print('[LAN] SEND FAILED $key → reconnecting');
        await _evict(key, driver);
      }
    }

    driver = await openSession();
    try {
      await action(driver);
      print('[LAN] SEND SUCCESS $key');
    } catch (e) {
      await _evict(key, driver);
      rethrow;
    }
  }

  /// Disconnects every cached LAN session. Call on logout / process shutdown.
  static Future<void> disconnectAll() async {
    final entries = _sessions.entries.toList();
    _sessions.clear();
    for (final e in entries) {
      print('[LAN] SESSION REMOVED ${e.key}');
      await e.value.disconnect();
    }
  }
}
