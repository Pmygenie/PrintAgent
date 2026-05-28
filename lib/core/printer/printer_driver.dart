abstract class PrinterDriver {
  String get id;
  Future<void> connect();
  Future<void> printBytes(List<int> bytes);
  Future<void> disconnect();
  Future<bool> get isConnected;
}
