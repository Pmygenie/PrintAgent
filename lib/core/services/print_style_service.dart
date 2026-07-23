import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/print_style_config.dart';

class PrintStyleService {
  static const String _key = 'print_style_config';

  static Future<PrintStyleConfig> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonString);
        return PrintStyleConfig.fromJson(decoded);
      } catch (e) {
        return PrintStyleConfig.defaults();
      }
    }
    return PrintStyleConfig.defaults();
  }

  static Future<void> saveConfig(PrintStyleConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(config.toJson());
    await prefs.setString(_key, jsonString);
  }

  static Future<void> resetDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}