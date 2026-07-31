import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/models/order_item.dart';
import 'package:printer_agent/core/models/restaurant_order.dart';
import 'package:printer_agent/core/profile/restaurant_profile_model.dart';

/// Pure data/formatting helpers mirrored from [EscPosFormatter] business rules.
class ReceiptBusinessLogic {
  ReceiptBusinessLogic._();

  static const escMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static double billAmount(Map<String, dynamic> bill, String key) =>
      double.tryParse(bill[key]?.toString() ?? '0') ?? 0.0;

  static String formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  static String formatQty(double qty) =>
      qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();

  static String formatMoney(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String itemDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day}-${escMonths[dt.month - 1]}';
  }

  static String truncate(String text, int maxLen) =>
      text.length <= maxLen ? text : '${text.substring(0, maxLen - 2)}..';

  static String stripKotPrice(String text) => text
      .replaceAll(RegExp(r'\s*\(\+\s*\d+(?:\.\d+)?\s*\)'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<String> groupKotModifiers(List<String> values, String marker) {
    final grouped = <String, List<String>>{};
    final plain = <String>[];

    for (final raw in values) {
      final clean = stripKotPrice(raw);
      if (clean.isEmpty) continue;

      final idx = clean.indexOf(':');
      if (idx > 0) {
        final key = clean.substring(0, idx).trim();
        final value = clean.substring(idx + 1).trim();
        if (value.isEmpty) continue;
        grouped.putIfAbsent(key, () => []).add(value);
      } else {
        plain.add(clean);
      }
    }

    final lines = <String>[];
    grouped.forEach((key, vals) {
      lines.add('$marker $key: ${vals.join(', ')}');
    });
    for (final p in plain) {
      lines.add('$marker $p');
    }
    return lines;
  }

  static double itemUnitPrice(OrderItem item) =>
      (item.itemUnit.isNotEmpty && item.itemUnitPrice > 0
              ? item.itemUnitPrice
              : item.price) +
      item.variationTotal +
      item.addonTotal;

  static String billCenterLabel(Map<String, dynamic> bill) {
    final orderType = bill['order_type']?.toString().trim() ?? '';
    final tableName = bill['table_name']?.toString().trim() ?? '';
    if (orderType == 'pos' || orderType == 'dinein') {
      return tableName.toUpperCase();
    }
    return orderType.replaceAll('_', ' ').toUpperCase();
  }

  static String kotCenterLabel(RestaurantOrder o) {
    final type = o.orderType.trim().toLowerCase();
    final table = (o.tableName ?? '').trim();
    if (type == 'pos' || type == 'dinein') {
      return table.isNotEmpty ? table.toUpperCase() : 'WC';
    }
    return o.orderType.trim().replaceAll('_', ' ').toUpperCase();
  }

  static String payLabel(Map<String, dynamic> bill) {
    final paymentStatus = bill['payment_status']?.toString() ?? '';
    final paymentMethod = bill['payment_method']?.toString() ?? '';
    if (paymentStatus == 'unpaid' && paymentMethod == 'pending') {
      return '(Unpaid)';
    }
    final method = paymentMethod.isNotEmpty
        ? paymentMethod[0].toUpperCase() + paymentMethod.substring(1)
        : '';
    return '(Paid by $method)';
  }

  static bool isRoomOrder(Map<String, dynamic> bill) {
    final associated = bill['associated_orders'] as List<dynamic>?;
    return associated != null && associated.isNotEmpty;
  }

  static bool isAggregator(Map<String, dynamic> bill) =>
      bill['is_aggregator'] == true;

  static bool get showBillItemDate =>
      PrintConfig.is80mm && PrintConfig.showItemDateOn80mm;

  static String resolveLogoUrl(String path, String apiUrl) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = apiUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/$path';
  }

  static String restaurantName(
    RestaurantProfileModel profile,
    RestaurantOrder order,
  ) =>
      profile.restaurantName.isNotEmpty
          ? profile.restaurantName
          : order.restaurantName;

  static String qtyDisplay(OrderItem item) => item.itemUnit.isNotEmpty
      ? '${formatQty(item.quantity)}${item.itemUnit}'
      : formatQty(item.quantity);

  static String billItemDisplayName(OrderItem item) {
    final isComp = item.complementary?.toString().toLowerCase() == 'yes';
    final isCancelled = item.foodStatus == 3;
    final displayName = isComp ? '${item.name} (Comp)' : item.name;
    return isCancelled ? '$displayName (Cancelled)' : displayName;
  }

  static String kotTitle(String? stationLabel, {bool cancel = false}) {
    final station = stationLabel?.trim().toUpperCase() ?? '';
    if (cancel) {
      return station.isNotEmpty ? 'CANCEL KOT [ $station ]' : 'CANCEL';
    }
    return station.isNotEmpty ? 'KOT [ $station ]' : 'KOT';
  }

  static String waiterLine(RestaurantOrder o, int maxChars) =>
      o.waiterName.length > maxChars
          ? truncate(o.waiterName, maxChars - 9)
          : o.waiterName;
}
