import 'package:flutter/material.dart';
import 'package:gains/app.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/auth/data/auth_api.dart';
import 'package:gains/features/auth/data/token_storage.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:gains/features/profile/data/profile_api.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage);
  final authSession = AuthSession(
    tokenStorage: tokenStorage,
    authApi: AuthApi(apiClient),
    profileApi: ProfileApi(apiClient),
  );

  runApp(
    Provider<ApiClient>.value(
      value: apiClient,
      child: GainsApp(authSession: authSession),
    ),
  );
}
