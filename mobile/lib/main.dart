import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gains/app.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/config/api_config.dart';
import 'package:gains/core/preferences/body_units_preference.dart';
import 'package:gains/features/auth/data/auth_api.dart';
import 'package:gains/features/auth/data/token_storage.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:gains/features/profile/data/profile_api.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiBaseUrl = await ApiConfig.resolveBaseUrl();
  if (kDebugMode) {
    debugPrint('Gains API_BASE_URL=$apiBaseUrl');
  }

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage, baseUrl: apiBaseUrl);
  final authSession = AuthSession(
    tokenStorage: tokenStorage,
    authApi: AuthApi(apiClient),
    profileApi: ProfileApi(apiClient),
  );
  final bodyUnits = await BodyUnitsPreference.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<BodyUnitsPreference>.value(value: bodyUnits),
        ChangeNotifierProvider<AuthSession>.value(value: authSession),
      ],
      child: GainsApp(authSession: authSession),
    ),
  );
}
