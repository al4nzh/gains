import 'package:flutter/foundation.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/features/auth/data/auth_api.dart';
import 'package:gains/features/auth/data/token_storage.dart';
import 'package:gains/features/auth/models/user.dart';
import 'package:gains/features/profile/data/profile_api.dart';
import 'package:gains/features/profile/models/profile.dart';
import 'package:gains/features/profile/models/profile_update.dart';

enum AuthStatus { loading, unauthenticated, authenticated }

class AuthSession extends ChangeNotifier {
  AuthSession({
    required TokenStorage tokenStorage,
    required AuthApi authApi,
    required ProfileApi profileApi,
  })  : _tokenStorage = tokenStorage,
        _authApi = authApi,
        _profileApi = profileApi;

  final TokenStorage _tokenStorage;
  final AuthApi _authApi;
  final ProfileApi _profileApi;

  AuthStatus status = AuthStatus.loading;
  User? user;
  Profile? profile;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get needsOnboarding => profile?.needsOnboarding ?? true;

  Future<void> bootstrap() async {
    status = AuthStatus.loading;
    user = null;
    profile = null;
    notifyListeners();

    final access = await _tokenStorage.readAccessToken();
    if (access == null || access.isEmpty) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      await _loadSession();
      status = AuthStatus.authenticated;
    } on ApiException {
      await _tokenStorage.clear();
      status = AuthStatus.unauthenticated;
    } catch (_) {
      await _tokenStorage.clear();
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    final response = await _authApi.register(email, password);
    await _tokenStorage.saveTokens(response.tokens, userId: response.user.id);
    user = response.user;
    profile = await _profileApi.getProfile();
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final response = await _authApi.login(email, password);
    await _tokenStorage.saveTokens(response.tokens, userId: response.user.id);
    user = response.user;
    profile = await _profileApi.getProfile();
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> completeOnboarding(ProfileUpdate update) async {
    profile = await _profileApi.updateProfile(update);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    profile = await _profileApi.getProfile();
    notifyListeners();
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    user = null;
    profile = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _loadSession() async {
    user = await _authApi.me();
    profile = await _profileApi.getProfile();
  }
}
