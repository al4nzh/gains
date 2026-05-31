import 'package:flutter/foundation.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/features/auth/data/auth_api.dart';
import 'package:gains/features/auth/data/oauth_service.dart';
import 'package:gains/features/auth/data/token_storage.dart';
import 'package:gains/features/auth/models/auth_response.dart';
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
    OAuthService? oauthService,
  })  : _tokenStorage = tokenStorage,
        _authApi = authApi,
        _profileApi = profileApi,
        _oauthService = oauthService ?? OAuthService();

  final TokenStorage _tokenStorage;
  final AuthApi _authApi;
  final ProfileApi _profileApi;
  final OAuthService _oauthService;

  AuthStatus status = AuthStatus.loading;
  User? user;
  Profile? profile;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get needsOnboarding => profile?.needsOnboarding ?? true;
  bool get needsEmailVerification =>
      user != null && user!.usesEmailAuth && !user!.isEmailVerified;

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
    await _applyAuthResponse(response);
  }

  Future<void> login(String email, String password) async {
    final response = await _authApi.login(email, password);
    await _applyAuthResponse(response);
  }

  Future<void> signInWithGoogle() async {
    final creds = await _oauthService.signInWithGoogle();
    final response = await _authApi.loginGoogle(creds.idToken);
    await _applyAuthResponse(response);
  }

  Future<void> signInWithApple() async {
    final creds = await _oauthService.signInWithApple();
    final response = await _authApi.loginApple(creds.idToken, email: creds.email);
    await _applyAuthResponse(response);
  }

  Future<void> completeOnboarding(ProfileUpdate update) async {
    await updateProfile(update);
  }

  Future<void> updateProfile(ProfileUpdate update) async {
    profile = await _profileApi.updateProfile(update);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    profile = await _profileApi.getProfile();
    notifyListeners();
  }

  Future<void> refreshUser() async {
    user = await _authApi.me();
    notifyListeners();
  }

  Future<void> verifyEmail(String token) async {
    user = await _authApi.verifyEmail(token);
    notifyListeners();
  }

  Future<void> resendVerificationEmail() async {
    await _authApi.resendVerification();
  }

  Future<void> forgotPassword(String email) async {
    await _authApi.forgotPassword(email);
  }

  Future<void> resetPassword(String token, String password) async {
    await _authApi.resetPassword(token, password);
  }

  Future<void> logout() async {
    await _oauthService.signOutGoogle();
    await _tokenStorage.clear();
    user = null;
    profile = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _applyAuthResponse(AuthResponse response) async {
    await _tokenStorage.saveTokens(response.tokens, userId: response.user.id);
    user = response.user;
    profile = await _profileApi.getProfile();
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> _loadSession() async {
    user = await _authApi.me();
    profile = await _profileApi.getProfile();
  }
}
