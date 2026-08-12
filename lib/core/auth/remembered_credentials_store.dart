import 'package:shared_preferences/shared_preferences.dart';

/// A "Remember Me" email/password pair for pre-filling the Login screen.
class RememberedCredentials {
  final String email;
  final String password;
  const RememberedCredentials({required this.email, required this.password});
}

/// Locally-persisted "Remember me" login credentials.
///
/// Stored in plaintext in SharedPreferences — same trust model as the rest
/// of this app's local config (auth token, server URLs, etc.). Only ever
/// used to pre-fill the Login form fields; never used to auto-submit login.
class RememberedCredentialsStore {
  RememberedCredentialsStore._();

  static const _kEmail = 'remembered_login_email';
  static const _kPassword = 'remembered_login_password';

  static Future<RememberedCredentials?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_kEmail);
    final password = prefs.getString(_kPassword);
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    return RememberedCredentials(email: email, password: password);
  }

  static Future<void> save({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kPassword, password);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEmail);
    await prefs.remove(_kPassword);
  }
}
