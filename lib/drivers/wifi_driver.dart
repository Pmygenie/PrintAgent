// import "../core/printer/printer_driver.dart";
// import "lan_driver.dart";

// class WifiPrinterDriver implements PrinterDriver {
//   WifiPrinterDriver({
//     required String host,
//     int port = 9100,
//   }) : _delegate = LanPrinterDriver(host: host, port: port);

//   final LanPrinterDriver _delegate;

//   @override
//   String get id => _delegate.id.replaceFirst("lan:", "wifi:");

//   @override
//   Future<void> connect() => _delegate.connect();

//   @override
//   Future<void> disconnect() => _delegate.disconnect();

//   @override
//   Future<bool> get isConnected => _delegate.isConnected;

//   @override
//   Future<void> printBytes(List<int> bytes) => _delegate.printBytes(bytes);
// }
