import 'package:printer_agent/core/printer/bluetooth_address.dart';
import 'package:printer_agent/drivers/bluetooth_driver.dart';

/// Process-wide keep-alive BLE sessions, keyed by normalized MAC.
///
/// First print scans + connects and caches the driver. Later prints reuse the
/// GATT connection (no scan). On send failure the session is evicted and one
/// reconnect + send retry is attempted.
class BleSessionRegistry {
  BleSessionRegistry._();

  static final Map<String, BluetoothPrinterDriver> _sessions = {};

  /// Cache key: hex-only uppercase MAC (formatting-insensitive).
  static String cacheKey(String macAddress) {
    final extracted = BluetoothAddress.extractPrinterMac(macAddress);
    return BluetoothAddress.normalize(extracted ?? macAddress);
  }

  static String _logMac(String macAddress) {
    final extracted = BluetoothAddress.extractPrinterMac(macAddress);
    return extracted ?? BluetoothAddress.displayMac(macAddress);
  }

  static Future<void> _evict(String key, BluetoothPrinterDriver driver) async {
    if (_sessions[key] == driver) {
      _sessions.remove(key);
      print('[BT] SESSION REMOVED ${_logMac(driver.macAddress)}');
    }
    await driver.disconnect();
  }

  /// Runs [action] on a live BLE session for [macAddress].
  ///
  /// Must be called under [BluetoothPrintLock] by the caller.
  static Future<void> run({
    required String macAddress,
    required Future<void> Function(BluetoothPrinterDriver driver) action,
  }) async {
    final key = cacheKey(macAddress);
    final label = _logMac(macAddress);

    Future<BluetoothPrinterDriver> openSession() async {
      print('[BT] SESSION MISS $label → scanning');
      final driver = BluetoothPrinterDriver(macAddress: macAddress);
      await driver.connect();
      _sessions[key] = driver;
      return driver;
    }

    var driver = _sessions[key];
    if (driver != null && await driver.isConnected) {
      print('[BT] SESSION HIT $label → reusing connection');
      try {
        await action(driver);
        print('[BT] SEND SUCCESS $label');
        return;
      } catch (_) {
        print('[BT] SEND FAILED $label → reconnecting');
        await _evict(key, driver);
      }
    } else {
      if (driver != null) {
        await _evict(key, driver);
      }
      driver = await openSession();
      try {
        await action(driver);
        print('[BT] SEND SUCCESS $label');
        return;
      } catch (_) {
        print('[BT] SEND FAILED $label → reconnecting');
        await _evict(key, driver);
      }
    }

    // One fresh scan/connect + one send retry.
    driver = await openSession();
    try {
      await action(driver);
      print('[BT] SEND SUCCESS $label');
    } catch (e) {
      await _evict(key, driver);
      rethrow;
    }
  }

  /// Disconnects every cached BLE session. Call on logout / process shutdown.
  static Future<void> disconnectAll() async {
    final entries = _sessions.entries.toList();
    _sessions.clear();
    for (final e in entries) {
      print('[BT] SESSION REMOVED ${_logMac(e.value.macAddress)}');
      await e.value.disconnect();
    }
  }
}
