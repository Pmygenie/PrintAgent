import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:printer_agent/core/auth/auth_session_monitor.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/config/app_constants.dart';

/// Raw HTTP client for the `printer-agent-config` endpoint.
///
/// Returns only the `data` object of the response (which contains
/// `settings_config` and `style_config`), or `null` on any failure —
/// missing token, network error, timeout, non-200 status, malformed body,
/// or `success: false`. Callers are expected to treat `null` as "keep
/// whatever is already cached locally".
class PrinterAgentConfigApi {
  static const _tag = '[PrinterAgentConfigApi]';

  Future<Map<String, dynamic>?> fetchConfig() async {
    final token = PrintConfig.authToken;
    if (token.isEmpty) {
      print('$_tag skipped — no auth token available yet');
      return null;
    }

    final base = AppConstants.apiUrl.replaceAll(RegExp(r'/+$'), '');
    final url = '$base/api/v2/vendoremployee/restaurant-settings/printer-agent-config';

    print('$_tag GET $url');
    print('$_tag token: $token');

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        AuthSessionMonitor.instance.notifyExpired();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        print('$_tag failed — HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        print('$_tag failed — response body is not a JSON object');
        return null;
      }

      final body = Map<String, dynamic>.from(decoded);
      if (body['success'] != true) {
        print('$_tag failed — success:false in response (${body['message']})');
        return null;
      }
      if (body['data'] is! Map) {
        print('$_tag failed — missing "data" object in response');
        return null;
      }

      print('$_tag fetched OK — value_source=${body['value_source']}, is_default=${body['is_default']}');
      return Map<String, dynamic>.from(body['data'] as Map);
    } catch (e) {
      print('$_tag failed — $e');
      return null;
    }
  }
}
