import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:printer_agent/core/auth/auth_session_monitor.dart';
import 'package:printer_agent/core/config/app_constants.dart';

/// Client for `POST /api/v2/vendoremployee/employee-logout`.
///
/// Invalidates the current session token server-side. Requires the current
/// `PrintConfig.authToken` as a Bearer token — callers must not invoke this
/// once the local token has already been cleared.
class AuthLogoutApi {
  static const _tag = '[AuthLogoutApi]';

  Future<void> logout({required String token}) async {
    final url = '${AppConstants.apiUrl}/api/v2/vendoremployee/employee-logout';
    print('$_tag POST $url');
    print('$_tag token: $token');

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'X-localization': 'en',
              HttpHeaders.authorizationHeader: 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      print('$_tag ❌ network error: $e');
      throw Exception('Could not reach server. Check your connection.');
    }

    if (response.statusCode == 401) {
      // Server already considers this session dead — there's nothing left
      // to invalidate. Notify the global monitor (which drives the actual
      // local logout + navigation) and treat this as an effective success
      // rather than throwing, so callers don't show a confusing "failed"
      // error right before the forced-logout redirect happens.
      print('$_tag ⚠️ 401 Unauthorized — session already invalid server-side, treating as logged out');
      AuthSessionMonitor.instance.notifyExpired();
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Logout failed (status ${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {
        // Non-JSON body — fall back to the generic status-code message.
      }
      print('$_tag ❌ $message');
      throw Exception(message);
    }

    print('$_tag ✅ logout success');
  }
}
