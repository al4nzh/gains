import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// RevenueCat public SDK keys (dart-define at build time).
abstract final class SubscriptionConfig {
  static const iosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY', defaultValue: '');
  static const androidApiKey = String.fromEnvironment('REVENUECAT_ANDROID_API_KEY', defaultValue: '');
  static const entitlementId = String.fromEnvironment('REVENUECAT_ENTITLEMENT_ID', defaultValue: 'premium');

  static bool get isStoreConfigured {
    if (kIsWeb) return false;
    if (Platform.isIOS) return iosApiKey.trim().isNotEmpty;
    if (Platform.isAndroid) return androidApiKey.trim().isNotEmpty;
    return false;
  }

  static String? get platformApiKey {
    if (kIsWeb) return null;
    if (Platform.isIOS) {
      final k = iosApiKey.trim();
      return k.isEmpty ? null : k;
    }
    if (Platform.isAndroid) {
      final k = androidApiKey.trim();
      return k.isEmpty ? null : k;
    }
    return null;
  }
}
