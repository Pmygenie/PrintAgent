import "package:shared_preferences/shared_preferences.dart";

import "../core/models/print_models.dart";
import "app_settings.dart";

class SettingsStore {
  static const String _kSocketUrl = "socket_url";
  static const String _kRestaurantId = "restaurant_id";
  static const String _kKitchenIp = "kitchen_ip";
  static const String _kKitchenPaper = "kitchen_paper";
  static const String _kBillingIp = "billing_ip";
  static const String _kBillingPaper = "billing_paper";

  Future<AgentSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AgentSettings defaults = AgentSettingsDefaults.values();
    return AgentSettings(
      socketUrl: prefs.getString(_kSocketUrl) ?? defaults.socketUrl,
      restaurantId: prefs.getInt(_kRestaurantId) ?? defaults.restaurantId,
      kitchenPrinterIp: prefs.getString(_kKitchenIp) ?? defaults.kitchenPrinterIp,
      kitchenPaper: _toPaper(prefs.getString(_kKitchenPaper)) ?? defaults.kitchenPaper,
      billingPrinterIp: prefs.getString(_kBillingIp) ?? defaults.billingPrinterIp,
      billingPaper: _toPaper(prefs.getString(_kBillingPaper)) ?? defaults.billingPaper,
    );
  }

  Future<void> save(AgentSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSocketUrl, settings.socketUrl);
    await prefs.setInt(_kRestaurantId, settings.restaurantId);
    await prefs.setString(_kKitchenIp, settings.kitchenPrinterIp);
    await prefs.setString(_kKitchenPaper, settings.kitchenPaper.name);
    await prefs.setString(_kBillingIp, settings.billingPrinterIp);
    await prefs.setString(_kBillingPaper, settings.billingPaper.name);
  }

  PaperKind? _toPaper(String? value) {
    if (value == null) {
      return null;
    }
    return PaperKind.values.where((PaperKind p) => p.name == value).firstOrNull;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
