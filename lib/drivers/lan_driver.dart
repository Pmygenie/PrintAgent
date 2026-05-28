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

import 'dart:io';
import 'printer_driver.dart';

class LanPrinterDriver implements PrinterDriver {
  final String ipAddress;
  final int port;
  Socket? _socket;

  LanPrinterDriver({required this.ipAddress, this.port = 9100});

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(
      ipAddress,
      port,
      timeout: const Duration(seconds: 5),
    );
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    _socket!.add(bytes);
    await _socket!.flush();
  }

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}