import 'dart:developer';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/printer/pdf_formatter.dart';
import 'package:printer_agent/drivers/windows_usb_driver.dart';
import 'package:printing/printing.dart';
import '../models/print_job.dart';
import '../models/printer_config.dart';
import 'escpos_formatter.dart';
import '../../drivers/printer_driver.dart';
import '../../drivers/lan_driver.dart';
import '../../drivers/usb_driver.dart';
import '../../drivers/bluetooth_driver.dart'; // ✅ ONE file now

class PrinterManager {
  final Map<String, PrinterConfig> _printers = {};

  void registerPrinter(PrinterConfig config) => _printers[config.id] = config;
  void registerAll(List<PrinterConfig> list) => list.forEach(registerPrinter);

  // Future<void> print(PrintJob job) async {
  //   final config = _printers[job.printerId] ?? _printers.values.first;
  //   final driver = _buildDriver(config);
  //   final bytes = await EscPosFormatter.format(job);

  //   // ── Determine how many copies to print ──────────────
  //   // kotCopies applies to KOT only — bill always prints once
  //   final copies = job.type == PrintType.kot
  //       ? PrintConfig.kotCopies
  //       : PrintConfig.billCopies;

  //   await driver.connect();
  //   try {
  //     for (int i = 0; i < copies; i++) {
  //       await driver.sendBytes(bytes);

  //       // Small gap between copies so printer doesn't choke
  //       if (copies > 1 && i < copies - 1) {
  //         await Future.delayed(const Duration(milliseconds: 300));
  //       }
  //     }
  //   } finally {
  //     await driver.disconnect();
  //   }
  // }

  Future<void> print(PrintJob job) async {
    final config = _printers[job.printerId] ?? _printers.values.first;

    final copies = job.type == PrintType.kot
        ? PrintConfig.kotCopies
        : PrintConfig.billCopies;

    final shouldUseWindowsPdf = Platform.isWindows &&
        config.type == PrinterType.usb &&
        PrintConfig.usePdfPrintingOnWindows;
    // log('PDF DEBUG => isWindows=${Platform.isWindows}, usePdfPrintingOnWindows=${PrintConfig.usePdfPrintingOnWindows}, usePdfForBillsOnly=${PrintConfig.usePdfForBillsOnly},jobType=${job.type}, printerType=${config.type},shouldUseWindowsPdf=$shouldUseWindowsPdf');

    if (shouldUseWindowsPdf) {
      final pdfBytes = await PdfFormatter.format(job);

      final printers = await Printing.listPrinters();

      Printer? targetPrinter;
      for (final p in printers) {
        if (p.name.trim().toLowerCase() ==
            PrintConfig.printerName.trim().toLowerCase()) {
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
        final result = await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'BILL_${job.order.displayOrderId}_COPY_${i + 1}',
        );

        log('PDF DIRECT PRINT RESULT (Copy ${i + 1}) => $result');

        // Small delay between copies
        if (copies > 1 && i < copies - 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      return;
    }
    final driver = _buildDriver(config);
    final bytes = await EscPosFormatter.format(job);

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
        // ✅ No Platform.isAndroid check needed anymore
        return BluetoothPrinterDriver(macAddress: c.macAddress!);
    }
  }
}
