import 'dart:async';

/// Fired whenever ANY authenticated API call returns HTTP 401 Unauthorized,
/// signalling that [PrintConfig.authToken] is no longer valid server-side
/// (expired, revoked, or superseded by a login from another device).
///
/// [HomeScreen] listens to [sessionExpired] and reacts by clearing the local
/// token and forcing navigation back to [LoginScreen] — retrying API calls
/// with a token the server has already rejected would just keep failing.
class AuthSessionMonitor {
  AuthSessionMonitor._();
  static final AuthSessionMonitor instance = AuthSessionMonitor._();

  final _controller = StreamController<void>.broadcast();
  Stream<void> get sessionExpired => _controller.stream;

  bool _pending = false;

  /// Call this whenever an authenticated API call returns HTTP 401.
  /// Multiple calls in quick succession (e.g. several endpoints failing
  /// around the same time) are coalesced into a single notification.
  void notifyExpired() {
    if (_pending) return;
    _pending = true;
    _controller.add(null);
    // Re-arm shortly after so a *future* session (post re-login) can
    // trigger this again if it also goes bad.
    Future.delayed(const Duration(seconds: 5), () => _pending = false);
  }
}
