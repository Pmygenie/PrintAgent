import 'package:printer_agent/drivers/usb_driver.dart';

/// Process-wide keep-alive USB sessions, keyed by vendor/product id.
///
/// First print scans + connects and caches the driver. Later prints reuse the
/// open USB connection (no scan, no per-job disconnect). Tearing the connection
/// down after every job leaves the native plugin holding a stale handle, which
/// crashes the next job — so the session is only evicted on send failure.
class UsbSessionRegistry {
  UsbSessionRegistry._();

  static final Map<String, UsbPrinterDriver> _sessions = {};

  /// Cache key: one entry per physical USB device.
  static String cacheKey(int vendorId, int productId) => '$vendorId:$productId';

  static Future<void> _evict(String key, UsbPrinterDriver driver) async {
    if (_sessions[key] == driver) {
      _sessions.remove(key);
      print('[USB] SESSION REMOVED $key');
    }
    await driver.disconnect();
  }

  /// Runs [action] on a live USB session for [vendorId]/[productId].
  ///
  /// Must be called under [UsbPrintLock] by the caller.
  static Future<void> run({
    required int vendorId,
    required int productId,
    required Future<void> Function(UsbPrinterDriver driver) action,
  }) async {
    final key = cacheKey(vendorId, productId);

    Future<UsbPrinterDriver> openSession() async {
      print('[USB] SESSION MISS $key → scanning');
      final driver = UsbPrinterDriver(
        vendorId: vendorId,
        productId: productId,
      );
      await driver.connect();
      _sessions[key] = driver;
      return driver;
    }

    var driver = _sessions[key];
    if (driver != null && driver.isConnected) {
      print('[USB] SESSION HIT $key → reusing connection');
      try {
        await action(driver);
        print('[USB] SEND SUCCESS $key');
        return;
      } catch (_) {
        print('[USB] SEND FAILED $key → reconnecting');
        await _evict(key, driver);
      }
    } else {
      if (driver != null) {
        await _evict(key, driver);
      }
      driver = await openSession();
      try {
        await action(driver);
        print('[USB] SEND SUCCESS $key');
        return;
      } catch (_) {
        print('[USB] SEND FAILED $key → reconnecting');
        await _evict(key, driver);
      }
    }

    // One fresh scan/connect + one send retry.
    driver = await openSession();
    try {
      await action(driver);
      print('[USB] SEND SUCCESS $key');
    } catch (e) {
      await _evict(key, driver);
      rethrow;
    }
  }

  /// Disconnects every cached USB session. Call on logout / process shutdown.
  static Future<void> disconnectAll() async {
    final entries = _sessions.entries.toList();
    _sessions.clear();
    for (final e in entries) {
      print('[USB] SESSION REMOVED ${e.key}');
      await e.value.disconnect();
    }
  }
}
