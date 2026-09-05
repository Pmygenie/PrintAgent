import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/order_item.dart';
import 'package:printer_agent/core/models/print_job.dart';
import 'package:printer_agent/core/models/restaurant_order.dart';
import 'package:printer_agent/core/queue/print_queue_manager.dart';

/// Queues KOT jobs as one ticket per line item when
/// [PrintConfig.kotSeparateTicket] is on. Quantity is left as-is.
/// Cancel KOT and bills are unchanged.
class KotSeparateTicket {
  KotSeparateTicket._();

  static void queue({
    required PrintQueueManager queueManager,
    required List<String> printerIds,
    required PrintType type,
    required RestaurantOrder order,
    String? stationLabel,
  }) {
    if (printerIds.isEmpty) return;

    if (type != PrintType.kot || !PrintConfig.kotSeparateTicket) {
      for (final printerId in printerIds) {
        queueManager.route(PrintJob(
          type: type,
          printerId: printerId,
          order: order,
          stationLabel: stationLabel,
        ));
      }
      return;
    }

    for (final item in order.items) {
      if (item.foodStatus == 3) continue;
      final ticket = _orderWithItem(order, item);
      for (final printerId in printerIds) {
        queueManager.route(PrintJob(
          type: type,
          printerId: printerId,
          order: ticket,
          stationLabel: stationLabel,
        ));
      }
    }
  }

  static RestaurantOrder _orderWithItem(RestaurantOrder order, OrderItem item) {
    return RestaurantOrder(
      orderId: order.orderId,
      displayOrderId: order.displayOrderId,
      tableId: order.tableId,
      tableName: order.tableName,
      waiterName: order.waiterName,
      orderAmount: item.price * item.quantity,
      orderNote: order.orderNote,
      orderType: order.orderType,
      printKot: order.printKot,
      restaurantName: order.restaurantName,
      receivedAt: order.receivedAt,
      empCode: order.empCode,
      station: order.station,
      userCustName: order.userCustName,
      userCustPhone: order.userCustPhone,
      dailyToken: order.dailyToken,
      billData: order.billData,
      items: [item],
    );
  }
}
