import 'package:printer_agent/core/config/print_config.dart';
import 'order_item.dart';

class RestaurantOrder {
  final int orderId;
  final String displayOrderId;
  final int tableId;
  final String? tableName;
  final String waiterName;
  final double orderAmount;
  final String orderNote;
  final String orderType;
  final String printKot;
  final String restaurantName;
  final List<OrderItem> items;
  final DateTime receivedAt;
  final String? empCode;
  final String? station;
  final Map<String, dynamic> billData;

  RestaurantOrder({
    required this.orderId,
    required this.displayOrderId,
    required this.tableId,
    this.tableName,
    required this.waiterName,
    required this.orderAmount,
    required this.orderNote,
    required this.orderType,
    required this.printKot,
    required this.restaurantName,
    required this.items,
    required this.receivedAt,
    this.station,
    this.empCode,
    this.billData = const {},
  });

  String get tableDisplay {
    if (tableId == 0 || tableName == null || tableName!.isEmpty) {
      return 'Counter / Takeaway';
    }
    return tableName!;
  }

  factory RestaurantOrder.fromJson(Map<String, dynamic> json) {
    final employee = Map<String, dynamic>.from(json['vendorEmployee'] ?? {});
    final table = json['restaurantTable'] != null
        ? Map<String, dynamic>.from(json['restaurantTable'])
        : null;
    final details = (json['orderDetails'] as List<dynamic>? ?? [])
        .map((d) => OrderItem.fromJson(Map<String, dynamic>.from(d)))
        .toList();

    final timeRaw = json['created_at']?.toString().trim() ?? '';
    final receivedAt =
        timeRaw.isNotEmpty ? DateTime.parse(timeRaw).toLocal() : DateTime.now();

    return RestaurantOrder(
      orderId: json['id'] ?? 0,
      displayOrderId: json['restaurant_order_id']?.toString() ?? '',
      tableId: json['table_id'] ?? 0,
      tableName: table?['table_no']?.toString().trim() ?? '' ,
      waiterName: [
        employee['f_name']?.toString() ?? '',
      ].where((s) => s.isNotEmpty).join(' '),
      orderAmount:
          double.tryParse(json['order_amount']?.toString() ?? '0') ?? 0.0,
      orderNote: json['order_note']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? 'pos',
      printKot: json['print_kot']?.toString() ?? 'No',
      restaurantName: json['restaurant']?['name']?.toString() ?? 'Restaurant',
      items: details,
      station: json['station']?.toString(),
      receivedAt: receivedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'displayOrderId': displayOrderId,
        'tableId': tableId,
        'tableName': tableName,
        'waiterName': waiterName,
        'orderAmount': orderAmount,
        'orderNote': orderNote,
        'orderType': orderType,
        'printKot': printKot,
        'restaurantName': restaurantName,
        'receivedAt': receivedAt.toIso8601String(),
        'items': items
            .map((i) => {
                  'name': i.name,
                  'quantity': i.quantity,
                  'price': i.price,
                  'note': i.note,
                })
            .toList(),
      };

  factory RestaurantOrder.fromMap(Map<String, dynamic> map) {
    return RestaurantOrder(
      orderId: map['orderId'],
      displayOrderId: map['displayOrderId'],
      tableId: map['tableId'],
      tableName: map['tableName'],
      waiterName: map['waiterName'],
      orderAmount: map['orderAmount'],
      orderNote: map['orderNote'],
      orderType: map['orderType'],
      printKot: map['printKot'],
      restaurantName: map['restaurantName'],
      receivedAt: DateTime.parse(map['receivedAt']).toLocal(),
      items: (map['items'] as List)
          .map((i) => OrderItem(
                name: i['name'],
                quantity: i['quantity'],
                price: i['price'],
                note: i['note'],
              ))
          .toList(),
    );
  }

  // ── For manually_print API response (bill-safe parser) ─────────────
  // stationFilter = null → all items
  // stationFilter != null → filtered items
  factory RestaurantOrder.fromTempApi(
    Map<String, dynamic> data, {
    String? stationFilter,
  }) {
    final allDetails = (data['orderDetails'] as List<dynamic>? ?? [])
        .map((d) => OrderItem.fromJson(Map<String, dynamic>.from(d)))
        .toList();

    final details = stationFilter == null
        ? allDetails
        : allDetails
            .where((item) =>
                item.station?.toUpperCase() == stationFilter.toUpperCase())
            .toList();

    String restaurantName = PrintConfig.restaurantName;
    if (data['orderDetails'] != null &&
        (data['orderDetails'] as List).isNotEmpty) {
      final firstFood = data['orderDetails'][0]['food_details'];
      if (firstFood != null) {
        restaurantName = firstFood['restaurant_name']?.toString() ??
            PrintConfig.restaurantName;
      }
    }

    final bill = Map<String, dynamic>.from(data['bill'] ?? {});

    final timeRaw = data['created_at']?.toString().trim() ?? '';
    final receivedAt =
        timeRaw.isNotEmpty ? DateTime.parse(timeRaw).toLocal() : DateTime.now();

    return RestaurantOrder(
      orderId: data['order_id'] ?? 0,
      displayOrderId: data['restaurant_order_id']?.toString() ?? '',
      tableId: data['table_id'] ?? 0,
      empCode: data['emp_code']?.toString() ?? '',
      tableName: null,
      waiterName: 'Staff',
      orderAmount: _sumItems(details),
      orderNote: '',
      orderType: data['order_type']?.toString() ?? 'pos',
      printKot: data['print_kot']?.toString() ?? 'Yes',
      restaurantName: restaurantName,
      receivedAt: receivedAt,
      items: details,
      billData: bill,
    );
  }

  // ── For manually_print KOT response (KDS-aware parser) ─────────────
  factory RestaurantOrder.fromTempKdsApi(
    Map<String, dynamic> data, {
    String? stationFilter,
  }) {
    final allDetails = (data['orderDetails'] as List<dynamic>? ?? [])
        .map((d) => OrderItem.fromJson(Map<String, dynamic>.from(d)))
        .toList();

    final details = stationFilter == null
        ? allDetails
        : allDetails
            .where((item) =>
                item.station?.toUpperCase() == stationFilter.toUpperCase())
            .toList();

    String restaurantName = PrintConfig.restaurantName;
    if (data['orderDetails'] != null &&
        (data['orderDetails'] as List).isNotEmpty) {
      final firstFood = data['orderDetails'][0]['food_details'];
      if (firstFood != null) {
        restaurantName = firstFood['restaurant_name']?.toString() ??
            PrintConfig.restaurantName;
      }
    }

    final kds = Map<String, dynamic>.from(data['kds'] ?? {});
    final bill = Map<String, dynamic>.from(data['bill'] ?? {});

    if (kds.isEmpty) {
      throw Exception('KDS payload missing in fromTempKdsApi');
    }

    final waiterName = kds['waiter_name']?.toString().trim() ?? '';
    final orderNote = kds['order_note']?.toString().trim() ?? '';
    final orderType = kds['order_type']?.toString().trim() ?? 'pos';
    final tableName = kds['table_name']?.toString().trim() ?? '';
    final printKot = kds['print_kot']?.toString().trim() ?? 'Yes';

    final dateTimeRaw =
        kds['created_at']?.toString().trim().isNotEmpty == true
            ? kds['created_at'].toString().trim()
            : kds['updated_at']?.toString().trim() ?? '';

    if (dateTimeRaw.isEmpty) {
      throw Exception('KDS datetime missing in fromTempKdsApi');
    }

    final receivedAt = DateTime.parse(dateTimeRaw).toLocal();

    return RestaurantOrder(
      orderId: data['order_id'] ?? 0,
      displayOrderId: data['restaurant_order_id']?.toString() ?? '',
      tableId: data['table_id'] ?? 0,
      empCode: data['emp_code']?.toString() ?? '',
      tableName: tableName.isEmpty ? null : tableName,
      waiterName: waiterName,
      orderAmount: _sumItems(details),
      orderNote: orderNote,
      orderType: orderType,
      printKot: printKot,
      restaurantName: restaurantName,
      receivedAt: receivedAt,
      items: details,
      billData: bill,
    );
  }

  static double _sumItems(List<OrderItem> items) =>
      items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
}