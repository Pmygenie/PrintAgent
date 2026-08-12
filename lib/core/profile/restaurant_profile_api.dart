import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:printer_agent/core/auth/auth_session_monitor.dart';
import 'package:printer_agent/core/config/app_constants.dart';

class RestaurantProfileApi {
  Future<Map<String, dynamic>> fetchProfile({
    required String token,
  }) async {
    final url = '${AppConstants.apiUrl}'
        '/api/v1/vendoremployee/profile';
    print('========>${url}');
    print('========> token: $token');
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'accept': 'application/json',
        HttpHeaders.authorizationHeader: 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      AuthSessionMonitor.instance.notifyExpired();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to fetch restaurant profile. '
        'Status code: ${response.statusCode}, body: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return Map<String, dynamic>.from(decoded as Map);
  }
}
