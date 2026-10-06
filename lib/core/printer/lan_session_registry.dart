import 'package:printer_agent/core/printer/op_timeout.dart';
import 'package:printer_agent/drivers/lan_driver.dart';

/// One TCP connection per LAN/Wi-Fi print job (`ip:port` is only a log label).
///
/// Each job connects, sends, flushes, and closes. The socket is not cached.
/// A port-9100 session left open through a long idle can go stale, and on
/// some printer firmware it wedges the NIC until the printer is power-cycled.
///
/// A failed attempt is aborted at once and retried once on a new socket.
/// Callers must still run this under [LanPrintLock].
class LanSessionRegistry {
  LanSessionRegistry._();

  static String cacheKey(String ipAddress, int port) => '$ipAddress:$port';

  /// Runs [action] on a fresh connection to [ipAddress]:[port], then closes it.
  static Future<void> run({
    required String ipAddress,
    required int port,
    required Future<void> Function(LanPrinterDriver driver) action,
  }) async {
    final key = cacheKey(ipAddress, port);
    try {
      await _once(key, ipAddress, port, action);
    } catch (e) {
      print('[LAN] FAILED $key → one fresh connection ($e)');
      await Future.delayed(OpTimeout.lanReconnectGap);
      await _once(key, ipAddress, port, action);
    }
  }

  static Future<void> _once(
    String key,
    String ipAddress,
    int port,
    Future<void> Function(LanPrinterDriver driver) action,
  ) async {
    print('[LAN] CONNECT $key');
    final driver = LanPrinterDriver(ipAddress: ipAddress, port: port);
    try {
      await driver.connect();
      await action(driver);
      print('[LAN] SEND SUCCESS $key');
    } catch (e) {
      driver.abort();
      rethrow;
    }
    try {
      await driver.disconnect();
    } catch (e) {
      // Bytes were already accepted. Do not retry the job from a close error.
      print('[LAN] CLOSE FAILED $key ($e)');
      driver.abort();
    }
  }

  /// No cached LAN sockets. In-flight jobs close their own connection.
  static Future<void> disconnectAll() async {}
}
