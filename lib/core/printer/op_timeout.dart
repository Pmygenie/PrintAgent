import 'dart:async';

/// Operation-level timeouts for printer I/O.
///
/// Bounds are per *operation*, never per job: a legitimately long print (many
/// paced chunks) is unaffected, while a single call that wedges forever is
/// turned into an exception the print queue can retry and log.
///
/// Values carry large headroom on purpose. If one of these ever fires during
/// normal printing the limit is wrong, not the printer — a write that is
/// abandoned mid-receipt leaves a partial slip and the retry reprints it.
class OpTimeout {
  OpTimeout._();

  // LAN — writes are local-network fast; connect already bounds itself.
  static const lanFlush = Duration(seconds: 10);
  static const lanClose = Duration(seconds: 5);

  // Windows classic Bluetooth (SPP).
  static const sppDiscover = Duration(seconds: 15);
  static const sppPair = Duration(seconds: 30);
  static const sppConnect = Duration(seconds: 30);
  static const sppDisconnect = Duration(seconds: 5);

  /// One paced chunk (512 bytes) — normally tens of milliseconds.
  static const sppWrite = Duration(seconds: 10);

  // Windows PDF spooling.
  static const windowsListPrinters = Duration(seconds: 10);
  static const windowsDirectPrint = Duration(seconds: 60);
}

/// Fails [op] with a named [TimeoutException] if it outlives [limit].
///
/// Dart cannot cancel a future, so the underlying operation keeps running —
/// callers must tear down the connection rather than reuse it after a timeout.
Future<T> bounded<T>(Future<T> op, Duration limit, String what) => op.timeout(
      limit,
      onTimeout: () => throw TimeoutException(
        '⏱️ $what did not finish within ${limit.inSeconds}s',
      ),
    );
