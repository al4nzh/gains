import 'package:gains/features/auth/models/token_pair.dart';
import 'package:gains/features/auth/models/user.dart';

class AuthResponse {
  const AuthResponse({required this.user, required this.tokens});

  final User user;
  final TokenPair tokens;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      tokens: TokenPair.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }
}
