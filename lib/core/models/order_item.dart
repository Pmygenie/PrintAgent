class OrderItem {
  final String name;
  final int quantity;
  final double price; // base food price
  final String note;
  final String? station;
  final String? complementary;
  final List<String> variations;
  final List<String> addons;
  final double variationTotal;
  final double addonTotal;
  final int? foodStatus;

  const OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.note = '',
    this.station,
    this.complementary,
    this.variations = const [],
    this.addons = const [],
    this.variationTotal = 0.0,
    this.addonTotal = 0.0,
    this.foodStatus,

  });

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
      double groupTotal = 0.0;

      for (final val in values) {
        final valueMap = Map<String, dynamic>.from(val as Map);
        final label = valueMap['label']?.toString() ?? '';
        final optionPrice =
            double.tryParse(valueMap['optionPrice']?.toString() ?? '0') ?? 0.0;

        if (label.isNotEmpty) {
          labels.add(label);
        }

        groupTotal += optionPrice;
        variationTotal += optionPrice;
      }

      if (groupName.isNotEmpty && labels.isNotEmpty) {
        final priceText =
            groupTotal > 0 ? ' (+${groupTotal.toStringAsFixed(0)})' : '';
        variations.add('${labels.join(', ')}$priceText');
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

    return OrderItem(
      name: food['name']?.toString() ?? 'Unknown Item',
      quantity: int.tryParse(detail['quantity']?.toString() ?? '1') ?? 1,
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
    );
  }
}
