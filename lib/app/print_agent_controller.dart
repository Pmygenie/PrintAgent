// import "package:flutter/foundation.dart";

// import "app_settings.dart";
// import "../core/models/print_models.dart";
// import "../core/printer/printer_manager.dart";
// import "../core/queue/print_queue.dart";
// import "../core/socket/windows_socket_service.dart";
// import "../drivers/lan_driver.dart";

// class PrintAgentController extends ChangeNotifier {
//   PrintAgentController({
//     required AgentSettings initialSettings,
//   }) : _settings = initialSettings {
//     _setup(_settings);
//   }

//   AgentSettings _settings;

//   late PrinterManager _printerManager;
//   late PrintQueue _queue;
//   SocketService? _socketService;

//   String socketStatus = "initializing";
//   String queueStatus = "idle";
//   String lastPrint = "none";
//   String lastError = "none";

//   AgentSettings get settings => _settings;
//   int get queueLength => _queue.length;

//   void _setup(AgentSettings settings) {
//     _printerManager = PrinterManager();
//     _printerManager.register(
//       config: PrinterConfig(
//         id: "kitchen-lan",
//         name: "Kitchen Printer",
//         type: PrinterType.lan,
//         paperKind: settings.kitchenPaper,
//         role: "kitchen",
//         host: settings.kitchenPrinterIp,
//       ),
//       driver: LanPrinterDriver(host: settings.kitchenPrinterIp),
//     );
//     _printerManager.register(
//       config: PrinterConfig(
//         id: "billing-lan",
//         name: "Billing Printer",
//         type: PrinterType.lan,
//         paperKind: settings.billingPaper,
//         role: "billing",
//         host: settings.billingPrinterIp,
//       ),
//       driver: LanPrinterDriver(host: settings.billingPrinterIp),
//     );

//     _queue = PrintQueue(printerManager: _printerManager);
//     _socketService = SocketService(
//       socketUrl: settings.socketUrl,
//       restaurantId: settings.restaurantId,
//       onPrintJob: _onPrintJob,
//       onStatus: _onSocketStatus,
//       onError: _onError,
//     );
//   }

//   void start() {
//     socketStatus = "connecting";
//     notifyListeners();
//     _socketService?.start();
//   }

//   void stop() {
//     _socketService?.stop();
//     socketStatus = "stopped";
//     notifyListeners();
//   }

//   Future<void> applySettings(AgentSettings newSettings) async {
//     final bool wasRunning = _socketService != null && socketStatus != "stopped";
//     _socketService?.stop();
//     _settings = newSettings;
//     _setup(_settings);
//     if (wasRunning) {
//       start();
//     } else {
//       notifyListeners();
//     }
//   }

//   Future<void> testKitchenPrint() async {
//     await _printerManager.printJob(
//       PrintJob(
//         jobId: "test-kitchen-${DateTime.now().millisecondsSinceEpoch}",
//         eventType: "manual-test",
//         orderId: 999001,
//         restaurantId: _settings.restaurantId,
//         status: 1,
//         type: PrintJobType.kot,
//         createdAt: DateTime.now(),
//       ),
//     );
//     lastPrint = "manual KOT test sent";
//     notifyListeners();
//   }

//   Future<void> testBillingPrint() async {
//     await _printerManager.printJob(
//       PrintJob(
//         jobId: "test-billing-${DateTime.now().millisecondsSinceEpoch}",
//         eventType: "manual-test",
//         orderId: 999002,
//         restaurantId: _settings.restaurantId,
//         status: 2,
//         type: PrintJobType.bill,
//         createdAt: DateTime.now(),
//       ),
//     );
//     lastPrint = "manual BILL test sent";
//     notifyListeners();
//   }

//   void _onPrintJob(PrintJob job) {
//     _queue.enqueue(job);
//     queueStatus = _queue.isBusy ? "processing" : "queued";
//     lastPrint = "queued ${job.type.name.toUpperCase()} #${job.orderId} (status ${job.status})";
//     notifyListeners();
//   }

//   void _onSocketStatus(String status) {
//     socketStatus = status;
//     notifyListeners();
//   }

//   void _onError(String error) {
//     lastError = error;
//     notifyListeners();
//   }
// }
