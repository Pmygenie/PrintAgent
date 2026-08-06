class OrderItem {
  final int? foodId;
  final String name;
  final double quantity;
  final String itemUnit;
  final double price; // base food price
  final String note;
  final String? station;
  final String? complementary;
  final List<String> variations;
  final List<String> addons;
  final double variationTotal;
  final double addonTotal;
  final int? foodStatus;
  final double itemUnitPrice;
  final DateTime? createdAt;

  const OrderItem({
    this.foodId,
    required this.name,
    required this.quantity,
    this.itemUnit = '',
    required this.price,
    this.note = '',
    this.station,
    this.complementary,
    this.variations = const [],
    this.addons = const [],
    this.variationTotal = 0.0,
    this.addonTotal = 0.0,
    this.foodStatus,
    this.itemUnitPrice = 0.0,
    this.createdAt,
  });

  OrderItem copyWith({double? quantity}) {
    return OrderItem(
      foodId: foodId,
      name: name,
      quantity: quantity ?? this.quantity,
      itemUnit: itemUnit,
      price: price,
      note: note,
      station: station,
      complementary: complementary,
      variations: variations,
      addons: addons,
      variationTotal: variationTotal,
      addonTotal: addonTotal,
      foodStatus: foodStatus,
      itemUnitPrice: itemUnitPrice,
      createdAt: createdAt,
    );
  }

  /// Bill-only: merge rows with same food, variation, and add-ons.
  /// Cancelled rows are dropped first so they cannot alter a surviving line's
  /// quantity or status.
  static List<OrderItem> mergedForBill(List<OrderItem> items) {
    final merged = <String, OrderItem>{};
    final order = <String>[];

    for (final item in items) {
      if (item.foodStatus == 3) continue;

      final key = _billMergeKey(item);
      final existing = merged[key];
      if (existing != null) {
        merged[key] = existing.copyWith(
          quantity: existing.quantity + item.quantity,
        );
      } else {
        merged[key] = item;
        order.add(key);
      }
    }

    return order.map((key) => merged[key]!).toList();
  }

  static String _billMergeKey(OrderItem item) {
    final foodKey =
        item.foodId != null ? 'id:${item.foodId}' : 'name:${item.name}';
    final varKey = item.variations.join('|');
    final addonKey = item.addons.join('|');
    final compKey =
        item.complementary?.toLowerCase() == 'yes' ? 'comp' : 'paid';
    final priceKey = item.price.toStringAsFixed(2);
    return '$foodKey::$varKey::$addonKey::$compKey::$priceKey';
  }

  static String _normalizeUnit(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return '';

    final lower = text.toLowerCase();
    if (lower == 'null') return '';

    final numeric = double.tryParse(text);
    if (numeric != null && numeric == 0) return '';

    return text;
  }

  factory OrderItem.fromJson(Map<String, dynamic> detail) {
    final food = Map<String, dynamic>.from(detail['food_details'] ?? {});

    final variationData = (detail['variation'] as List?) ?? const [];
    final addOnData = (detail['add_ons'] as List?) ?? const [];

    final List<String> variations = [];
    double variationTotal = 0.0;

    for (final v in variationData) {
      final map = Map<String, dynamic>.from(v as Map);
      final groupName = map['name']?.toString() ?? '';
      final values = (map['values'] as List?) ?? const [];

      final labels = <String>[];
      // double groupTotal = 0.0;

      for (final val in values) {
        final valueMap = Map<String, dynamic>.from(val as Map);
        final label = valueMap['label']?.toString() ?? '';
        final optionPrice =
            double.tryParse(valueMap['optionPrice']?.toString() ?? '0') ?? 0.0;

        if (label.isNotEmpty) {
          labels.add(label);
        }

        // groupTotal += optionPrice;
        variationTotal += optionPrice;
      }

      if (groupName.isNotEmpty && labels.isNotEmpty) {
        // Bill: show variation name only (no price in brackets)
        // final priceText =
        //     groupTotal > 0 ? ' (+${groupTotal.toStringAsFixed(0)})' : '';
        // variations.add('${labels.join(', ')}$priceText');
        variations.add(labels.join(', '));
      }
    }

    final List<String> addons = [];
    double addonTotal = 0.0;

    for (final a in addOnData) {
      final map = Map<String, dynamic>.from(a as Map);
      final name = map['name']?.toString() ?? '';
      final qty = int.tryParse(map['quantity']?.toString() ?? '1') ?? 1;
      final addonPrice =
          double.tryParse(map['price']?.toString() ?? '0') ?? 0.0;

      if (name.isNotEmpty) {
        final totalAddonPrice = addonPrice * qty;
        final priceText = totalAddonPrice > 0
            ? ' (+${totalAddonPrice.toStringAsFixed(0)})'
            : '';
        addons.add('$name x$qty$priceText');
      }

      addonTotal += addonPrice * qty;
    }

    final detailUnit = _normalizeUnit(detail['item_unit']);
    final foodUnit = _normalizeUnit(food['item_unit']);

    return OrderItem(
      foodId: food['id'] is int
          ? food['id'] as int
          : int.tryParse(food['id']?.toString() ?? ''),
      name: food['name']?.toString() ?? 'Unknown Item',
      quantity: double.tryParse(
            detail['quantity']?.toString() ?? '1',
          ) ??
          1.0,
      itemUnit: detailUnit.isNotEmpty ? detailUnit : foodUnit,
      price: double.tryParse(food['price']?.toString() ?? '0') ?? 0.0,
      note: detail['food_level_notes']?.toString().isNotEmpty == true
          ? detail['food_level_notes'].toString()
          : detail['note']?.toString() ?? '',
      station: detail['station']?.toString(),
      complementary: food['complementary']?.toString(),
      variations: variations,
      addons: addons,
      variationTotal: variationTotal,
      addonTotal: addonTotal,
      foodStatus: detail['food_status'] is int
          ? detail['food_status']
          : int.tryParse(detail['food_status']?.toString() ?? ''),
      itemUnitPrice: double.tryParse(
            detail['item_unit_price']?.toString() ??
                food['item_unit_price']?.toString() ??
                '0',
          ) ??
          0.0,
      createdAt: detail['created_at'] != null
          ? DateTime.tryParse(detail['created_at'].toString())?.toLocal()
          : null,
    );
  }
}
