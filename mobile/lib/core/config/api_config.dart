import 'package:gains/core/preferences/dev_api_url_preference.dart';

/// API base URL for the Gains backend.
///
/// Priority (debug):
/// 1. Saved URL from orange bar
/// 2. `--dart-define=API_BASE_URL=...` if set
/// 3. [localWifi] — PC on Wi‑Fi (run `setup-local-dev.ps1` if IP changes)
/// 4. Release → production
class ApiConfig {
  ApiConfig._();

  static const String production = 'https://api.gainsai.net';
  static const String localUsb = 'http://127.0.0.1:8080';
  static const String localWifi = 'http://192.168.1.19:8080';
  static const String androidEmulator = 'http://10.0.2.2:8080';

  static Future<String> resolveBaseUrl() => DevApiUrlPreference.resolveBaseUrl();
}
