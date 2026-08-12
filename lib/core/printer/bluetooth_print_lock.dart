import 'dart:async';

/// Serializes all Bluetooth print jobs process-wide.
///
/// Each physical printer has its own [PrintQueue], so Bar + Billing can start
/// printing at the same time. Classic/BLE radios cannot safely share the link —
/// this lock ensures only one BT connect/reconnect + sendBytes runs at a time.
/// USB/LAN jobs never take this lock.
class BluetoothPrintLock {
  BluetoothPrintLock._();

  static Future<void> _tail = Future<void>.value();

  /// Runs [action] after any in-flight Bluetooth print finishes.
  static Future<T> exclusive<T>(Future<T> Function() action) async {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;

    await previous;
    try {
      return await action();
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  }
}
