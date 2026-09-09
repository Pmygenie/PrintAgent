/// Safe ESC/POS delivery over Bluetooth (BLE / classic SPP).
///
/// Blind fixed-size chunks can split `ESC`/`GS` commands / raster images so
/// printers cut off QR codes or print garbage. This helper:
/// - prepends printer reset (`ESC @`)
/// - never splits `GS v 0` or `ESC *` image blocks
/// - avoids ending a text chunk on a lone `ESC`/`GS`
/// - paces writes and settles after the last chunk
library;

import 'package:printer_agent/core/printer/op_timeout.dart';

class EscPosBluetoothTransport {
  EscPosBluetoothTransport._();

  /// ESC @ — initialize printer.
  static const List<int> reset = [0x1B, 0x40];

  /// Build payload with leading reset (idempotent if already present).
  static List<int> withReset(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0x1B && bytes[1] == 0x40) {
      return bytes;
    }
    return [...reset, ...bytes];
  }

  /// Length of a `GS v 0` raster block starting at [i], or null if not one.
  /// Format: `1D 76 30 m xL xH yL yH` + `(xL+xH*256)*(yL+yH*256)` data bytes.
  static int? _gsV0Length(List<int> bytes, int i) {
    if (i + 7 >= bytes.length) return null;
    if (bytes[i] != 0x1D || bytes[i + 1] != 0x76 || bytes[i + 2] != 0x30) {
      return null;
    }
    final x = bytes[i + 4] + (bytes[i + 5] << 8);
    final y = bytes[i + 6] + (bytes[i + 7] << 8);
    final dataLen = x * y;
    final total = 8 + dataLen;
    if (i + total > bytes.length) {
      // Truncated stream — take remainder so we don't loop forever.
      return bytes.length - i;
    }
    return total;
  }

  /// Length of an `ESC *` bit-image line starting at [i], or null if not one.
  /// Format: `1B 2A m nL nH` + data (`n` bytes if m<32, else `3*n`).
  static int? _escStarLength(List<int> bytes, int i) {
    if (i + 4 >= bytes.length) return null;
    if (bytes[i] != 0x1B || bytes[i + 1] != 0x2A) return null;
    final m = bytes[i + 2];
    final n = bytes[i + 3] + (bytes[i + 4] << 8);
    final dataLen = m >= 32 ? n * 3 : n;
    final total = 5 + dataLen;
    if (i + total > bytes.length) return bytes.length - i;
    return total;
  }

  /// Next image-command start in `[from, to)`, or -1.
  static int _nextImageStart(List<int> bytes, int from, int to) {
    for (var j = from; j < to; j++) {
      if (_gsV0Length(bytes, j) != null) return j;
      if (_escStarLength(bytes, j) != null) return j;
    }
    return -1;
  }

  /// Split [bytes] into chunks. Image commands are always one chunk (uncut).
  static List<List<int>> chunkSafely(
    List<int> bytes, {
    int maxChunk = 64,
  }) {
    if (bytes.isEmpty) return const [];
    if (maxChunk < 16) maxChunk = 16;

    final chunks = <List<int>>[];
    var i = 0;

    while (i < bytes.length) {
      final gsLen = _gsV0Length(bytes, i);
      if (gsLen != null) {
        chunks.add(bytes.sublist(i, i + gsLen));
        i += gsLen;
        continue;
      }

      final escLen = _escStarLength(bytes, i);
      if (escLen != null) {
        chunks.add(bytes.sublist(i, i + escLen));
        i += escLen;
        continue;
      }

      var end = i + maxChunk;
      if (end > bytes.length) end = bytes.length;

      // Don't swallow the start of an upcoming image into this text chunk.
      final imgAt = _nextImageStart(bytes, i + 1, end);
      if (imgAt >= 0) end = imgAt;

      if (end < bytes.length) {
        end = _adjustTextEnd(bytes, i, end);
      }

      if (end <= i) {
        end = (i + 1 < bytes.length) ? i + 1 : bytes.length;
      }

      chunks.add(bytes.sublist(i, end));
      i = end;
    }

    return chunks;
  }

  /// Avoid ending a text chunk on a lone ESC/GS prefix.
  static int _adjustTextEnd(List<int> bytes, int start, int end) {
    if (end <= start) return end;

    final last = bytes[end - 1];
    if (last == 0x1B || last == 0x1D) {
      return end - 1;
    }

    for (var look = 2; look <= 6; look++) {
      if (end - look < start) break;
      final b = bytes[end - look];
      if (b == 0x1B || b == 0x1D) {
        return end - look;
      }
    }
    return end;
  }

  /// Send [bytes] using [write], with reset + safe chunking + pacing.
  /// [writeTimeout] bounds a single chunk write, not the whole payload, so a
  /// long paced print is unaffected. Null leaves the write unbounded.
  static Future<void> send({
    required List<int> bytes,
    required Future<void> Function(List<int> chunk) write,
    int maxChunk = 64,
    Duration chunkDelay = const Duration(milliseconds: 40),
    Duration settleDelay = const Duration(milliseconds: 1500),
    Duration? writeTimeout,
  }) async {
    if (bytes.isEmpty) return;

    final payload = withReset(bytes);
    final chunks = chunkSafely(payload, maxChunk: maxChunk);

    for (var i = 0; i < chunks.length; i++) {
      print(
        '➡️ Sending chunk ${i + 1}/${chunks.length} (${chunks[i].length} bytes)',
      );
      final pending = write(chunks[i]);
      await (writeTimeout == null
          ? pending
          : bounded(pending, writeTimeout, 'chunk ${i + 1}/${chunks.length}'));
      print('✅ Chunk ${i + 1} sent');
      if (i < chunks.length - 1 && chunkDelay > Duration.zero) {
        await Future.delayed(chunkDelay);
      }
    }

    if (settleDelay > Duration.zero) {
      await Future.delayed(settleDelay);
    }
  }
}
