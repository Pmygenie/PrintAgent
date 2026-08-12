import 'package:printer_agent/core/api/printer_agent_config_api.dart';
import 'package:printer_agent/core/config/print_config.dart';
import 'package:printer_agent/core/mappers/printer_agent_config_mapper.dart';
import 'package:printer_agent/core/models/printer_config.dart';
import 'package:printer_agent/core/services/print_style_service.dart';

/// Fetches the remote `printer-agent-config` endpoint and maps it onto the
/// existing local configuration models (`PrintConfig`, `PrinterConfigStorage`,
/// `PrintStyleConfig`), using SharedPreferences (via those models' own
/// `save()` methods) as a write-through cache.
///
/// Also applies the same `data` payload when pushed over the socket
/// (`printer_agent_config_{restaurantId}`).
///
/// Phase 1 is read-only toward the server: nothing here ever pushes local
/// edits back. On any failure, the local cache is left completely untouched
/// and callers keep using whatever was already loaded from SharedPreferences.
class PrinterAgentConfigSyncService {
  PrinterAgentConfigSyncService._();

  static const _tag = '[PrinterAgentConfigSync]';

  static final PrinterAgentConfigApi _api = PrinterAgentConfigApi();

  /// Whether a sync has already succeeded once this app session.
  static bool _hasSyncedSuccessfully = false;

  /// Shared future so concurrent callers (e.g. Settings and Print Style
  /// opening at nearly the same time) don't trigger two network calls.
  static Future<bool>? _inFlight;

  /// Syncs local config from the remote API.
  ///
  /// - Without [force], this performs at most one real network call per app
  ///   session — once a sync succeeds, later calls return `true`
  ///   immediately without hitting the network, since local models already
  ///   reflect the remote state.
  /// - With [force] (used by the manual "refresh" action), the network call
  ///   always happens again, bypassing the session cache.
  static Future<bool> sync({bool force = false}) {
    if (!force && _hasSyncedSuccessfully) {
      print('$_tag skipped — already synced this session');
      return Future.value(true);
    }

    final existing = _inFlight;
    if (existing != null) {
      print('$_tag already in flight — awaiting existing request');
      return existing;
    }

    print(force ? '$_tag starting (forced)' : '$_tag starting');
    final future = _performSync();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  static Future<bool> _performSync() async {
    try {
      // Nothing to authenticate the request with yet — leave local
      // defaults/cache exactly as they are.
      if (PrintConfig.authToken.isEmpty) {
        print('$_tag skipped — no auth token available yet');
        return false;
      }

      final data = await _api.fetchConfig();
      if (data == null) {
        print('$_tag failed — no data returned, local cache left untouched');
        return false;
      }

      return applyFromData(data);
    } catch (e) {
      print('$_tag failed — $e');
      return false;
    }
  }

  /// Applies a `data` object shaped like the printer-agent-config API
  /// (`settings_config` / `style_config`) onto local models and persists them.
  ///
  /// Used by both HTTP sync and the socket push path. Returns `false` if the
  /// payload has neither config section (local cache left untouched).
  static Future<bool> applyFromData(Map<String, dynamic> data) async {
    try {
      final settingsConfig = data['settings_config'];
      final styleConfig = data['style_config'];
      if (settingsConfig is! Map && styleConfig is! Map) {
        print(
            '$_tag failed — payload had neither settings_config nor style_config');
        return false;
      }

      if (settingsConfig is Map) {
        final printers = PrinterAgentConfigMapper.applySettingsConfig(
          Map<String, dynamic>.from(settingsConfig),
        );
        await PrintConfig.save();
        print('$_tag settings_config applied → PrintConfig saved');
        if (printers.isNotEmpty) {
          await PrinterConfigStorage.save(printers);
          print(
              '$_tag settings_config applied → ${printers.length} printer(s) saved');
        }
      }

      if (styleConfig is Map) {
        final mappedStyle = PrinterAgentConfigMapper.mapStyleConfig(
          Map<String, dynamic>.from(styleConfig),
        );
        await PrintStyleService.saveConfig(mappedStyle);
        print('$_tag style_config applied → PrintStyleConfig saved');
      }

      _hasSyncedSuccessfully = true;
      print('$_tag apply completed successfully');
      return true;
    } catch (e) {
      print('$_tag apply failed — $e');
      return false;
    }
  }
}
