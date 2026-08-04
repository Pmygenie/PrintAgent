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
  final String? userCustName;
  final String? userCustPhone;
  final String dailyToken;
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
    this.userCustName,
    this.userCustPhone,
    this.dailyToken = '',
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
    final user =
        json['user'] != null ? Map<String, dynamic>.from(json['user']) : null;
    final custName = user?['f_name']?.toString().trim() ??
        json['user_name']?.toString().trim() ??
        '';
    final custPhone = user?['phone']?.toString().trim() ?? '';

    // print('????????? $custName $custPhone');

    return RestaurantOrder(
      orderId: json['id'] ?? 0,
      displayOrderId: json['restaurant_order_id']?.toString() ?? '',
      tableId: json['table_id'] ?? 0,
      tableName: table?['table_no']?.toString().trim() ?? '',
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
      userCustName: custName.isEmpty ? null : custName,
      userCustPhone: custPhone.isEmpty ? null : custPhone,
      dailyToken: json['daily_token']?.toString() ?? '',
    );
  }

  /// Maps socket new-order fields into the billData shape used by bill formatters.
  /// Does not change [fromJson]; only used for socket auto-bill.
  static Map<String, dynamic> billDataFromSocketOrder(Map<String, dynamic> json) {
    final employee = Map<String, dynamic>.from(json['vendorEmployee'] ?? {});
    final table = json['restaurantTable'] != null
        ? Map<String, dynamic>.from(json['restaurantTable'])
        : null;
    final user =
        json['user'] != null ? Map<String, dynamic>.from(json['user']) : null;

    final custName = user?['f_name']?.toString().trim() ??
        json['user_name']?.toString().trim() ??
        '';
    final custPhone = user?['phone']?.toString().trim() ?? '';
    final waiterName = [
      employee['f_name']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    final grantAmount =
        double.tryParse(json['order_amount']?.toString() ?? '0') ?? 0.0;
    final paymentAmount = double.tryParse(
          json['payment_amount']?.toString() ?? '',
        ) ??
        grantAmount;

    final serviceCharge = double.tryParse(
          json['service_tax']?.toString() ??
              json['total_service_tax_amount']?.toString() ??
              '0',
        ) ??
        0.0;

    final orderType = json['order_type']?.toString().trim() ?? '';
    final tableNo = table?['table_no']?.toString().trim() ?? '';
    // dinein + null/empty table → WC; dinein + table → table_no;
    // non-dinein → billCenterLabel uses order_type as-is.
    final tableName =
        orderType == 'dinein' ? (tableNo.isEmpty ? 'WC' : tableNo) : '';

    final delivery = json['delivery_address'] != null
        ? Map<String, dynamic>.from(json['delivery_address'] as Map)
        : <String, dynamic>{};

    return {
      'order_item_total':
          double.tryParse(json['order_sub_total_amount']?.toString() ?? '0') ??
              0.0,
      'order_subtotal': double.tryParse(
            json['order_sub_total_without_tax']?.toString() ?? '0',
          ) ??
          0.0,
      'service_charge_amount': serviceCharge,
      'delivery_charge':
          double.tryParse(json['delivery_charge']?.toString() ?? '0') ?? 0.0,
      'tip_amount':
          double.tryParse(json['tip_amount']?.toString() ?? '0') ?? 0.0,
      'gst_tax': double.tryParse(json['gst_tax']?.toString() ?? '0') ?? 0.0,
      'vat_tax': double.tryParse(json['vat_tax']?.toString() ?? '0') ?? 0.0,
      'packing_charge':
          double.tryParse(json['packing_charge']?.toString() ?? '0') ?? 0.0,
      'discount_amount':
          double.tryParse(json['order_discount']?.toString() ?? '0') ?? 0.0,
      'grant_amount': grantAmount,
      'payment_amount': paymentAmount,
      'payment_status': json['payment_status']?.toString() ?? '',
      'payment_method': json['payment_method']?.toString() ?? '',
      'order_type': orderType,
      'table_name': tableName,
      'waiter_name': waiterName,
      'order_note': json['order_note']?.toString() ?? '',
      'cust_name': custName,
      'cust_phone': custPhone,
      'cust_gst_name': json['cust_gst_name']?.toString() ??
          user?['gst_name']?.toString() ??
          '',
      'cust_gst':
          json['cust_gst']?.toString() ?? user?['gst_number']?.toString() ?? '',
      'wallet_used_amount':
          double.tryParse(json['wallet_used_amount']?.toString() ?? '0') ?? 0.0,
      'loyalty_discount_amount': double.tryParse(
            json['loyalty_discount_amount']?.toString() ?? '0',
          ) ??
          0.0,
      'coupon_code': json['coupon_code']?.toString() ?? '',
      'delivery_cust_name':
          delivery['contact_person_name']?.toString() ?? '',
      'delivery_cust_phone':
          delivery['contact_person_number']?.toString() ?? '',
      'delivery_address_type': delivery['address_type']?.toString() ?? '',
      'delivery_cust_address': delivery['address']?.toString() ?? '',
      'delivery_cust_pincode': delivery['pincode']?.toString() ?? '',
    };
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
        'userCustName': userCustName,
        'userCustPhone': userCustPhone,
        'items': items
            .map((i) => {
                  'name': i.name,
                  'quantity': i.quantity,
                  'price': i.price,
                  'note': i.note,
                })
            .toList(),
        'dailyToken': dailyToken,
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
      userCustName: map['userCustName'],
      userCustPhone: map['userCustPhone'],
      items: (map['items'] as List)
          .map((i) => OrderItem(
                name: i['name'],
                quantity: i['quantity'],
                price: i['price'],
                note: i['note'],
              ))
          .toList(),
      dailyToken: map['dailyToken'] ?? '',
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
      dailyToken: data['daily_token']?.toString().trim() ??
            bill['daily_token']?.toString().trim() ??
            '',
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

    final dateTimeRaw = kds['created_at']?.toString().trim().isNotEmpty == true
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
      dailyToken: data['daily_token']?.toString() ??
            kds['daily_token']?.toString() ??
            '',
    );
  }

  static double _sumItems(List<OrderItem> items) {
    return items.fold(0.0, (sum, i) {
      final basePrice = i.itemUnitPrice > 0 ? i.itemUnitPrice : i.price;

      final unitPrice = basePrice + i.variationTotal + i.addonTotal;

      return sum + (unitPrice * i.quantity);
    });
  }

  // ── For aggregator (UrbanPiper) API response ────────────────────────
  factory RestaurantOrder.fromAggregatorApi(Map<String, dynamic> json) {
    final ordersRoot = Map<String, dynamic>.from(json['orders'] as Map);
    final orderInfo  = Map<String, dynamic>.from(ordersRoot['order_details_order'] as Map);
    final customer   = ordersRoot['customer_details'] != null
        ? Map<String, dynamic>.from(ordersRoot['customer_details'] as Map)
        : <String, dynamic>{};
    final foodList   = (ordersRoot['order_details_food'] as List<dynamic>? ?? []);

    final items = foodList.map((raw) {
      final detail = Map<String, dynamic>.from(raw as Map);
      final food   = detail['food_details'] != null
          ? Map<String, dynamic>.from(detail['food_details'] as Map)
          : <String, dynamic>{};

      // Add-ons
      final addOnData = (detail['add_ons'] as List?) ?? const [];
      final List<String> addons = [];
      double addonTotal = 0.0;
      for (final a in addOnData) {
        final map       = Map<String, dynamic>.from(a as Map);
        final name      = map['title']?.toString() ?? '';
        final qty       = int.tryParse(map['quantity']?.toString() ?? '1') ?? 1;
        final addonPrice = double.tryParse(map['price']?.toString() ?? '0') ?? 0.0;
        if (name.isNotEmpty) {
          final total    = addonPrice * qty;
          final priceStr = total > 0 ? ' (+${total.toStringAsFixed(0)})' : '';
          addons.add('$name x$qty$priceStr');
        }
        addonTotal += addonPrice * qty;
      }

      return OrderItem(
        name: food['title']?.toString() ??
              food['name']?.toString() ??
              detail['name']?.toString() ??
              'Unknown Item',
        quantity: double.tryParse(detail['quantity']?.toString() ?? '1') ?? 1.0,
        price: double.tryParse(detail['unit_price']?.toString() ?? food['price']?.toString() ?? '0') ?? 0.0,
        note: detail['food_level_notes']?.toString().isNotEmpty == true
            ? detail['food_level_notes'].toString()
            : '',
        station: detail['station']?.toString() ?? 'KDS',
        foodStatus: detail['food_status'] is int
            ? detail['food_status']
            : int.tryParse(detail['food_status']?.toString() ?? ''),
        addons: addons,
        addonTotal: addonTotal,
        createdAt: detail['created_at'] != null
            ? DateTime.tryParse(detail['created_at'].toString())?.toLocal()
            : null,
      );
    }).toList();

    final timeRaw   = orderInfo['created_at']?.toString().trim() ?? '';
    final receivedAt = timeRaw.isNotEmpty
        ? (DateTime.tryParse(timeRaw)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final custName  = customer['name']?.toString().trim() ?? '';
    final custPhone = customer['phone']?.toString().trim() ?? '';

    final orderAmount = double.tryParse(
            orderInfo['order_amount']?.toString() ?? '0') ?? 0.0;
    final itemTotal   = double.tryParse(
            orderInfo['item_total']?.toString() ?? '0') ?? 0.0;
    final couponDiscount = double.tryParse(
            orderInfo['coupon_discount_amount']?.toString() ?? '0') ?? 0.0;
    final gstAmount   = double.tryParse(
            orderInfo['total_gst_tax_amount']?.toString() ?? '0') ?? 0.0;
    final packingCharge = double.tryParse(
            orderInfo['packing_charge']?.toString() ?? '0') ?? 0.0;
    final couponCode  = orderInfo['coupon_code']?.toString() ?? '';
    final platform    = orderInfo['order_plateform']?.toString() ?? 'aggregator';
    final brandName   = ordersRoot['brand_name']?.toString().trim() ?? '';

    // Build a synthetic billData map compatible with the PDF/ESC-POS bill formatter
    // Aggregator amounts come straight from API keys — no recalculation.
    final billData = <String, dynamic>{
      'is_aggregator':       true,
      'order_item_total':    itemTotal,       // item_total
      'order_subtotal':      itemTotal,       // unused on aggregator bill (no Sub Total row)
      'discount_amount':     couponDiscount,  // coupon_discount_amount
      'coupon_code':         couponCode.isNotEmpty ? couponCode : null,
      'packing_charge':      packingCharge,   // packing_charge
      'gst_tax':             gstAmount,       // total_gst_tax_amount
      'vat_tax':             0.0,
      'service_charge_amount': 0.0,
      'delivery_charge':     double.tryParse(
              orderInfo['delivery_charge']?.toString() ?? '0') ?? 0.0,
      'tip_amount':          double.tryParse(
              orderInfo['tip_amount']?.toString() ?? '0') ?? 0.0,
      'grant_amount':        orderAmount,     // order_amount → TOTAL
      'payment_amount':      orderAmount,
      'payment_status':      orderInfo['payment_status']?.toString() ?? 'unpaid',
      'payment_method':      orderInfo['payment_method']?.toString() ?? 'aggregator',
      'order_type':          brandName,
      'table_name':          platform.toUpperCase(),
      'waiter_name':         platform[0].toUpperCase() + platform.substring(1),
      'order_note':          orderInfo['order_note']?.toString() ?? '',
      'cust_name':           custName,
      'cust_phone':          custPhone,
      'daily_token':         '',
    };

    return RestaurantOrder(
      orderId:        orderInfo['id'] ?? 0,
      displayOrderId: orderInfo['aggrigator_id']?.toString() ?? '',
      tableId:        orderInfo['table_id'] ?? 0,
      tableName:      platform.toUpperCase(),
      waiterName:     platform[0].toUpperCase() + platform.substring(1),
      orderAmount:    orderAmount,
      orderNote:      orderInfo['order_note']?.toString() ?? '',
      orderType:      brandName,
      printKot:       'Yes',
      restaurantName: PrintConfig.restaurantName,
      receivedAt:     receivedAt,
      items:          items,
      userCustName:   custName.isEmpty ? null : custName,
      userCustPhone:  custPhone.isEmpty ? null : custPhone,
      billData:       billData,
    );
  }
}