import 'package:flutter/material.dart';

import 'package:printer_agent/core/auth/auth_login_api.dart';
import 'package:printer_agent/core/auth/remembered_credentials_store.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/profile/restaurant_profile_api.dart';
import 'package:printer_agent/core/profile/restaurant_profile_repository.dart';
import 'package:printer_agent/core/profile/restaurant_profile_store.dart';
import 'package:printer_agent/core/queue/print_queue_manager.dart';
import 'package:printer_agent/core/services/printer_agent_config_sync_service.dart';
import 'package:printer_agent/core/socket/windows_socket_service.dart';
import 'package:printer_agent/ui/screens/home_screen.dart';

/// The two blocking steps run after a fresh login, before [HomeScreen] is
/// ever shown — each one is individually retryable on failure.
enum _PostLoginStep { profile, config }

/// Gate screen shown whenever no auth token is stored (first launch or
/// after Logout). On success, stores the returned token in [PrintConfig],
/// then blocks on syncing the restaurant profile + printer-agent-config
/// from the server (showing progress / retry UI) before finally routing to
/// [HomeScreen], carrying through whatever live socket/queue instances were
/// already constructed in `main()` (or by a prior session).
class LoginScreen extends StatefulWidget {
  final WindowsSocketService? windowsSocket;
  final PrintQueueManager? queueManager;

  const LoginScreen({
    super.key,
    required this.windowsSocket,
    required this.queueManager,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _api = AuthLoginApi();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _error;

  // ── Post-login sync (profile + printer-agent-config) ────────────────────
  bool _isSyncing = false;
  _PostLoginStep? _syncStep;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    final remembered = await RememberedCredentialsStore.load();
    if (!mounted || remembered == null) return;
    setState(() {
      _emailCtrl.text = remembered.email;
      _passwordCtrl.text = remembered.password;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _api.login(email: email, password: password);

      PrintConfig.authToken = result.token;
      await PrintConfig.save();

      if (_rememberMe) {
        await RememberedCredentialsStore.save(email: email, password: password);
      } else {
        await RememberedCredentialsStore.clear();
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      await _runProfileStep();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ── Post-login sync steps ────────────────────────────────────────────────

  Future<void> _runProfileStep() async {
    setState(() {
      _isSyncing = true;
      _syncStep = _PostLoginStep.profile;
      _syncError = null;
    });

    try {
      final repo = RestaurantProfileRepository(
        api: RestaurantProfileApi(),
        store: RestaurantProfileStore(),
      );
      await repo.fetchAndStore(token: PrintConfig.authToken);

      if (!mounted) return;
      await _runConfigStep();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncError = 'Failed to fetch restaurant profile: '
            '${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _runConfigStep() async {
    setState(() {
      _syncStep = _PostLoginStep.config;
      _syncError = null;
    });

    try {
      final ok = await PrinterAgentConfigSyncService.sync(force: true);
      if (!ok) {
        throw Exception('Could not fetch printer configuration');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            windowsSocket: widget.windowsSocket,
            queueManager: widget.queueManager,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncError = 'Failed to fetch printer configuration: '
            '${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  /// Retries whichever step is currently showing an error — not the whole
  /// sequence (e.g. if profile already succeeded, retrying only re-attempts
  /// the config fetch).
  void _retrySync() {
    if (_syncStep == _PostLoginStep.profile) {
      _runProfileStep();
    } else {
      _runConfigStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: _isSyncing ? _buildSyncProgress() : _buildLoginForm(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Post-login sync progress / retry UI ──────────────────────────────────
  Widget _buildSyncProgress() {
    final stepLabel = _syncStep == _PostLoginStep.profile
        ? 'Fetching restaurant profile…'
        : 'Fetching printer configuration…';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.print, size: 64, color: Colors.tealAccent),
        const SizedBox(height: 12),
        const Text(
          'Print Agent Login',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        if (_syncError == null) ...[
          const LinearProgressIndicator(minHeight: 6),
          const SizedBox(height: 16),
          Text(
            stepLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
        ] else ...[
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text(
            _syncError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _retrySync,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ),
        ],
      ],
    );
  }

  // ── Login form ────────────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.print, size: 64, color: Colors.tealAccent),
        const SizedBox(height: 12),
        const Text(
          'Print Agent Login',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'owner@hogwarts.com',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
            filled: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            filled: true,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        CheckboxListTile(
          value: _rememberMe,
          onChanged: (v) => setState(() => _rememberMe = v ?? false),
          title: const Text('Remember me'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Login', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
