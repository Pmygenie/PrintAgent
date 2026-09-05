import 'dart:async';

/// Serializes all USB print jobs process-wide.
///
/// Each physical printer has its own [PrintQueue], so Kitchen + Billing can be
/// mapped to the same USB device and start printing at the same time. The
/// native USB plugin holds a single connection object per device — this lock
/// ensures only one USB connect + printData runs at a time.
/// LAN/Bluetooth jobs never take this lock.
class UsbPrintLock {
  UsbPrintLock._();

  static Future<void> _tail = Future<void>.value();

  /// Runs [action] after any in-flight USB print finishes.
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
