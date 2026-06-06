import 'package:flutter/foundation.dart';
import 'package:gains/core/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug-only saved API base URL (survives hot restart; no rebuild needed).
class DevApiUrlPreference {
  DevApiUrlPreference._();

  static const _key = 'dev_api_base_url_v2';

  static bool _isDeviceLocalhost(String url) {
    final u = url.toLowerCase();
    return u.contains('127.0.0.1') ||
        u.contains('localhost') ||
        u.contains('10.0.2.2');
  }

  static Future<String> resolveBaseUrl() async {
    if (kReleaseMode) {
      const fromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');
      if (fromDefine.isNotEmpty) return fromDefine;
      return ApiConfig.production;
    }

    const fromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key)?.trim();
    if (saved != null && saved.isNotEmpty) {
      // Old USB/emulator saves lose to a LAN dart-define from setup-local-dev.
      if (_isDeviceLocalhost(saved) &&
          fromDefine.isNotEmpty &&
          !_isDeviceLocalhost(fromDefine)) {
        return fromDefine;
      }
      return saved;
    }

    if (fromDefine.isNotEmpty) return fromDefine;
    return ApiConfig.localWifi;
  }

  static Future<void> save(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
