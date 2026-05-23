/// API base URL for the Gains backend.
///
/// Override at run time:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`
///
/// Defaults by platform (see `mobile/README.md` and `docs/API.md` in the repo root).
/// - Android emulator: `http://10.0.2.2:8080`
/// - iOS Simulator: `http://127.0.0.1:8080`
/// - Physical device: `http://<your-pc-lan-ip>:8080`
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
}
