// import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
// import 'printer_driver.dart';

// class LanPrinterDriver implements PrinterDriver {
//   final String ipAddress;
//   final int port;
//   FlutterThermalPrinterNetwork? _service;

//   LanPrinterDriver({required this.ipAddress, this.port = 9100});

//   @override
//   Future<void> connect() async {
//     _service = FlutterThermalPrinterNetwork(ipAddress, port: port);
//     await _service!.connect();
//   }

//   @override
//   Future<void> sendBytes(List<int> bytes) async {
//     await _service!.printTicket(bytes);
//   }

//   @override
//   Future<void> disconnect() async {
//     await _service?.disconnect();
//     _service = null;
//   }
// }

import 'dart:async';
import 'dart:io';

import 'package:printer_agent/core/printer/op_timeout.dart';
import 'package:printer_agent/drivers/escpos_bluetooth_send.dart';

import 'printer_driver.dart';

class LanPrinterDriver implements PrinterDriver {
  final String ipAddress;
  final int port;
  Socket? _socket;
  bool _alive = false;

  LanPrinterDriver({required this.ipAddress, this.port = 9100});

  bool get isConnected => _alive && _socket != null;

  String get _label => '$ipAddress:$port';

  @override
  Future<void> connect() async {
    final socket = await Socket.connect(
      ipAddress,
      port,
      timeout: OpTimeout.lanConnect,
    );
    _socket = socket;
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {
      abort();
      rethrow;
    }
    socket.done.then((_) {
      _alive = false;
    }).catchError((_) {
      _alive = false;
    });
    _alive = true;
    print('[LAN] CONNECTED $_label');
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    final socket = _socket;
    if (socket == null || !_alive) {
      throw Exception('LAN printer not connected ($_label)');
    }
    if (bytes.isEmpty) {
      print('❌ ERROR: Byte array is empty! Aborting print.');
      return;
    }

    await EscPosBluetoothTransport.send(
      bytes: bytes,
      maxChunk: OpTimeout.lanSliceBytes,
      chunkDelay: OpTimeout.lanSliceDelay,
      settleDelay: OpTimeout.lanSettle,
      write: (chunk) async {
        // TCP is a stream — splitting a large raster across writes is safe
        // and is what stops Wi-Fi printers overflowing after the logo.
        for (var i = 0; i < chunk.length; i += OpTimeout.lanSliceBytes) {
          final end = (i + OpTimeout.lanSliceBytes > chunk.length)
              ? chunk.length
              : i + OpTimeout.lanSliceBytes;
          socket.add(chunk.sublist(i, end));
          await bounded(
            socket.flush(),
            OpTimeout.lanFlush,
            'LAN flush to $_label',
          );
          if (end < chunk.length) {
            await Future.delayed(OpTimeout.lanSliceDelay);
          }
        }
      },
    );
  }

  /// Graceful close after a successful send.
  @override
  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    _alive = false;
    if (socket == null) return;
    try {
      await bounded(
        socket.close(),
        OpTimeout.lanClose,
        'LAN close to $_label',
      );
    } on TimeoutException {
      socket.destroy();
    } catch (_) {
      socket.destroy();
    }
    print('[LAN] DISCONNECTED $_label');
  }

  /// Drops the socket in both directions. Use when connect or send already failed.
  void abort() {
    final socket = _socket;
    _socket = null;
    _alive = false;
    if (socket == null) return;
    socket.destroy();
    print('[LAN] ABORT $_label');
  }
}
