import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:printer_agent/core/config/app_constants.dart';

/// Result of a successful [AuthLoginApi.login] call.
class LoginResult {
  final String token;
  const LoginResult({required this.token});
}

/// Client for `POST /api/v1/auth/vendoremployee/common-login`.
///
/// Unlike every other API this app calls, the login endpoint itself does
/// NOT require an `Authorization` header — it's what *produces* the token
/// used for every other call (`printer-agent-config`, `restaurant profile`,
/// the print socket, etc. via `PrintConfig.authToken`).
class AuthLoginApi {
  static const _tag = '[AuthLoginApi]';

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final url = '${AppConstants.apiUrl}/api/v1/auth/vendoremployee/common-login';
    print('$_tag POST $url');

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'X-localization': 'en',
            },
            body: jsonEncode({
              'fcm_token': '',
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      print('$_tag ❌ network error: $e');
      throw Exception('Could not reach server. Check your connection.');
    }

    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Non-JSON body — fall through, handled by status/token checks below.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (body['message'] ?? body['error'])?.toString() ??
          'Login failed (status ${response.statusCode})';
      print('$_tag ❌ $message');
      throw Exception(message);
    }

    final token = body['token']?.toString() ?? '';
    if (token.isEmpty) {
      print('$_tag ❌ response did not contain a token');
      throw Exception('Login succeeded but no token was returned');
    }

    print('$_tag ✅ login success');
    print('$_tag token: $token');
    return LoginResult(token: token);
  }
}
