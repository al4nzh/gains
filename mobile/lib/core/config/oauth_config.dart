import 'dart:io';

/// OAuth client IDs from Google Cloud / Apple Developer.
///
/// Android Google Sign-In needs [googleServerClientId] (Web client ID) so the
/// returned id_token matches `GOOGLE_OAUTH_CLIENT_IDS` on the API.
///
/// iOS Google Sign-In also needs [googleIosClientId] (iOS client ID).
///
/// Apple uses bundle ID `com.alanz.gains` — set `APPLE_OAUTH_CLIENT_ID` on the API.
class OAuthConfig {
  OAuthConfig._();

  /// Web OAuth client ID — pass as `serverClientId` on Android (and optional on iOS).
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// iOS OAuth client ID from Google Cloud (required on iOS).
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isGoogleConfigured {
    if (Platform.isIOS) {
      return googleIosClientId.isNotEmpty &&
          (googleServerClientId.isNotEmpty || googleIosClientId.isNotEmpty);
    }
    return googleServerClientId.isNotEmpty;
  }

  static bool get isAppleConfigured => Platform.isIOS || Platform.isMacOS;
}
