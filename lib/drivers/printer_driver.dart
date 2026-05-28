abstract class PrinterDriver {
  Future<void> connect();
  Future<void> sendBytes(List<int> bytes);
  Future<void> disconnect();
}