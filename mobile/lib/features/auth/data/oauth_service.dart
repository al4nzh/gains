import 'dart:io';

import 'package:gains/core/config/oauth_config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class OAuthCredentials {
  const OAuthCredentials({
    required this.idToken,
    this.email,
  });

  final String idToken;
  final String? email;
}

class OAuthSignInException implements Exception {
  OAuthSignInException(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;

  @override
  String toString() => message;
}

class OAuthService {
  GoogleSignIn? _google;

  GoogleSignIn get _googleSignIn {
    _google ??= GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId:
          OAuthConfig.googleServerClientId.isNotEmpty ? OAuthConfig.googleServerClientId : null,
      clientId: OAuthConfig.googleIosClientId.isNotEmpty ? OAuthConfig.googleIosClientId : null,
    );
    return _google!;
  }

  Future<OAuthCredentials> signInWithGoogle() async {
    if (!OAuthConfig.isGoogleConfigured) {
      throw OAuthSignInException(
        'Google Sign-In is not configured. Set GOOGLE_SERVER_CLIENT_ID (and GOOGLE_IOS_CLIENT_ID on iOS) via --dart-define.',
      );
    }

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw OAuthSignInException('Sign-in cancelled', cancelled: true);
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw OAuthSignInException(
          'Google did not return an id token. Check GOOGLE_SERVER_CLIENT_ID matches a Web client in Google Cloud.',
        );
      }

      return OAuthCredentials(idToken: idToken, email: account.email);
    } on OAuthSignInException {
      rethrow;
    } catch (e) {
      throw OAuthSignInException('Google sign-in failed: $e');
    }
  }

  Future<OAuthCredentials> signInWithApple() async {
    if (!OAuthConfig.isAppleConfigured) {
      throw OAuthSignInException('Sign in with Apple is not available on this platform.');
    }

    try {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        throw OAuthSignInException(
          'Sign in with Apple is not available. Enable the capability in Xcode (com.alanz.gains).',
        );
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw OAuthSignInException('Apple did not return an identity token.');
      }

      return OAuthCredentials(
        idToken: idToken,
        email: credential.email?.trim().isNotEmpty == true ? credential.email!.trim() : null,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw OAuthSignInException('Sign-in cancelled', cancelled: true);
      }
      throw OAuthSignInException('Apple sign-in failed: ${e.message}');
    } on OAuthSignInException {
      rethrow;
    } catch (e) {
      throw OAuthSignInException('Apple sign-in failed: $e');
    }
  }

  Future<void> signOutGoogle() async {
    if (_google != null) {
      await _google!.signOut();
    }
  }
}
