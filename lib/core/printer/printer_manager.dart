import 'dart:developer';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/printer/pdf_formatter.dart';
import 'package:printer_agent/drivers/windows_usb_driver.dart';
import 'package:printing/printing.dart';
import '../models/print_job.dart';
import '../models/printer_config.dart';
import 'bitmap/bitmap_formatter.dart';
import 'bitmap/bitmap_print_config.dart';
import 'ble_session_registry.dart';
import 'bluetooth_print_lock.dart';
import 'escpos_formatter.dart';
import 'op_timeout.dart';
import 'usb_print_lock.dart';
import 'usb_session_registry.dart';
import '../../drivers/printer_driver.dart';
import '../../drivers/lan_driver.dart';
import '../../drivers/usb_driver.dart';
import '../../drivers/bluetooth_driver.dart';
import '../../drivers/windows_bt_driver.dart';

class PrinterManager {
  final Map<String, PrinterConfig> _printers = {};

  void registerPrinter(PrinterConfig config) => _printers[config.id] = config;
  void registerAll(List<PrinterConfig> list) => list.forEach(registerPrinter);

  Future<void> print(PrintJob job) async {
    final config = _printers[job.printerId] ?? _printers.values.first;

    final copies = job.type == PrintType.kot
        ? PrintConfig.kotCopies
        : PrintConfig.billCopies;

    final shouldUseWindowsPdf = Platform.isWindows &&
        config.type == PrinterType.usb &&
        (PrintConfig.usePdfPrintingOnWindows || PrintConfig.isA4);
    // log('PDF DEBUG => isWindows=${Platform.isWindows}, usePdfPrintingOnWindows=${PrintConfig.usePdfPrintingOnWindows}, usePdfForBillsOnly=${PrintConfig.usePdfForBillsOnly},jobType=${job.type}, printerType=${config.type},shouldUseWindowsPdf=$shouldUseWindowsPdf');

    if (shouldUseWindowsPdf) {
      final pdfBytes = await PdfFormatter.format(job);

      final printers = await bounded(
        Printing.listPrinters(),
        OpTimeout.windowsListPrinters,
        'Windows printer enumeration',
      );

      final targetName = (config.windowsPrinterName ?? '').trim().toLowerCase();

      Printer? targetPrinter;
      for (final p in printers) {
        if (p.name.trim().toLowerCase() == targetName) {
          targetPrinter = p;
          break;
        }
      }

      if (targetPrinter == null) {
        throw Exception(
          'Windows printer not found: ${config.windowsPrinterName}',
        );
      }

      for (int i = 0; i < copies; i++) {
        final result = await bounded(
          Future.value(Printing.directPrintPdf(
            printer: targetPrinter,
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: 'BILL_${job.order.displayOrderId}_COPY_${i + 1}',
          )),
          OpTimeout.windowsDirectPrint,
          'Windows spool of BILL_${job.order.displayOrderId} copy ${i + 1}',
        );

        log('PDF DIRECT PRINT RESULT (Copy ${i + 1}) => $result');

        // Small delay between copies
        if (copies > 1 && i < copies - 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      return;
    }
    final bytes = BitmapPrintConfig.enabled
        ? await BitmapFormatter.format(job)
        : await EscPosFormatter.format(job);

    // BLE keep-alive: connect once per MAC, reuse session, no per-job disconnect.
    final isBleKeepAlive = config.type == PrinterType.bluetooth &&
        !(Platform.isWindows && config.bluetoothMode == BluetoothMode.classicSpp);

    if (isBleKeepAlive) {
      log('🔒 BT lock acquire | Order Id - ${job.order.displayOrderId}');
      await BluetoothPrintLock.exclusive(() async {
        await BleSessionRegistry.run(
          macAddress: config.macAddress!,
          action: (driver) async {
            for (int i = 0; i < copies; i++) {
              await driver.sendBytes(bytes);
              if (copies > 1 && i < copies - 1) {
                await Future.delayed(const Duration(milliseconds: 300));
              }
            }
          },
        );
      });
      log('🔓 BT lock release | Order Id - ${job.order.displayOrderId}');
      return;
    }

    // USB keep-alive (Android): connect once per device, reuse session, no
    // per-job disconnect. Kitchen + Bill can share one device, so serialize.
    final isUsbKeepAlive = config.type == PrinterType.usb && !Platform.isWindows;

    if (isUsbKeepAlive) {
      log('🔒 USB lock acquire | Order Id - ${job.order.displayOrderId}');
      await UsbPrintLock.exclusive(() async {
        await UsbSessionRegistry.run(
          vendorId: config.vendorId!,
          productId: config.productId!,
          action: (driver) async {
            for (int i = 0; i < copies; i++) {
              await driver.sendBytes(bytes);
              if (copies > 1 && i < copies - 1) {
                await Future.delayed(const Duration(milliseconds: 300));
              }
            }
          },
        );
      });
      log('🔓 USB lock release | Order Id - ${job.order.displayOrderId}');
      return;
    }

    final driver = _buildDriver(config);

    Future<void> sendToPrinter() async {
      await driver.connect();
      try {
        for (int i = 0; i < copies; i++) {
          await driver.sendBytes(bytes);

          if (copies > 1 && i < copies - 1) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      } finally {
        await driver.disconnect();
      }
    }

    // Windows classic SPP: one job at a time across queues (shared radio).
    if (config.type == PrinterType.bluetooth) {
      log('🔒 BT lock acquire | Order Id - ${job.order.displayOrderId}');
      await BluetoothPrintLock.exclusive(sendToPrinter);
      log('🔓 BT lock release | Order Id - ${job.order.displayOrderId}');
    } else {
      await sendToPrinter();
    }
  }

  PrinterDriver _buildDriver(PrinterConfig c) {
    switch (c.type) {
      case PrinterType.lan:
      case PrinterType.wifi:
        return LanPrinterDriver(ipAddress: c.ipAddress!, port: c.port);

      case PrinterType.usb:
        if (Platform.isWindows) {
          // ✅ Windows → printer name only, no VendorId needed
          return WindowsUsbDriver(printerName: c.windowsPrinterName!);
        }
        if (c.vendorId == null || c.productId == null || c.vendorId == 0) {
          throw Exception(
              '❌ USB printer not configured — go to Settings and scan USB printers');
        }
        // Android → VendorId + ProductId
        return UsbPrinterDriver(vendorId: c.vendorId!, productId: c.productId!);

      case PrinterType.bluetooth:
        if (Platform.isWindows &&
            c.bluetoothMode == BluetoothMode.classicSpp) {
          return WindowsBluetoothDriver(macAddress: c.macAddress!);
        }
        return BluetoothPrinterDriver(macAddress: c.macAddress!);
    }
  }
}
