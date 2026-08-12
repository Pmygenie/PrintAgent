/// Single source of truth for the backend base URLs.
///
/// These are intentionally hardcoded constants — NOT stored in
/// [PrintConfig], NOT persisted to SharedPreferences, NOT editable from the
/// Settings screen, and NOT overridable by any API response (e.g. the
/// printer-agent-config sync). Every REST/socket call in the app must read
/// from here directly.
class AppConstants {
  AppConstants._();

  static const String apiUrl = 'https://preprod.mygenie.online';
  static const String socketUrl = 'https://presocket.mygenie.online';
}
