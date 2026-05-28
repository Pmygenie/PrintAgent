import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'printer_driver.dart';

class WindowsUsbDriver implements PrinterDriver {
  final String printerName; // e.g. "Everycom-printer"

  WindowsUsbDriver({required this.printerName});

  @override
  Future<void> connect() async {
    print('✅ WindowsUsbDriver ready → $printerName');
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    final namePtr      = printerName.toNativeUtf16();
    final phPrinter    = calloc<HANDLE>();
    final bytesWritten = calloc<DWORD>();

    try {
      if (OpenPrinter(namePtr, phPrinter, nullptr) == 0) {
        throw Exception('❌ Printer not found: "$printerName"\n'
            '→ Run in PowerShell: Get-Printer | Select Name');
      }

      final docInfo = calloc<DOC_INFO_1>();
      docInfo.ref.pDocName  = 'PrintJob'.toNativeUtf16();
      docInfo.ref.pDatatype = 'RAW'.toNativeUtf16();

      StartDocPrinter(phPrinter.value, 1, docInfo.cast());
      StartPagePrinter(phPrinter.value);

      final buffer = calloc<Uint8>(bytes.length);
      buffer.asTypedList(bytes.length).setAll(0, bytes);

      WritePrinter(phPrinter.value, buffer, bytes.length, bytesWritten);
      print('📤 Sent ${bytesWritten.value} bytes → "$printerName"');

      EndPagePrinter(phPrinter.value);
      EndDocPrinter(phPrinter.value);
      ClosePrinter(phPrinter.value);
      calloc.free(buffer);
    } finally {
      calloc.free(namePtr);
      calloc.free(phPrinter);
      calloc.free(bytesWritten);
    }
  }

  @override
  Future<void> disconnect() async {}

  // List all Windows printer names (for diagnostics)
  static List<String> listPrinters() {
    final needed   = calloc<DWORD>();
    final returned = calloc<DWORD>();
    final names    = <String>[];

    EnumPrinters(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
        nullptr, 2, nullptr, 0, needed, returned);

    final buffer = calloc<Uint8>(needed.value);
    try {
      EnumPrinters(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
          nullptr, 2, buffer, needed.value, needed, returned);

      final arr = buffer.cast<PRINTER_INFO_2>();
      for (int i = 0; i < returned.value; i++) {
        final n = arr[i].pPrinterName;
        if (n != nullptr) names.add(n.toDartString());
      }
    } finally {
      calloc.free(buffer);
      calloc.free(needed);
      calloc.free(returned);
    }
    return names;
  }
}