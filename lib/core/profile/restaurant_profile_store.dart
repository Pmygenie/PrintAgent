import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'restaurant_profile_model.dart';

class RestaurantProfileStore {
  static const String _profileKey = 'restaurant_profile_cache';

  Future<void> save(RestaurantProfileModel profile) async {
    final prefs = await SharedPreferences.getInstance();

    // optional but safe
    await prefs.remove(_profileKey);

    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    await prefs.reload();
  }

  Future<RestaurantProfileModel?> get() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      return RestaurantProfileModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.reload();
  }
}
