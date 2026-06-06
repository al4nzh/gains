import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/auth/models/auth_response.dart';
import 'package:gains/features/auth/models/user.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<AuthResponse> register(String email, String password) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email.trim(), 'password': password},
        options: Options(extra: const {'skipAuth': true}),
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
        options: Options(extra: const {'skipAuth': true}),
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<AuthResponse> loginGoogle(String idToken) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/google',
        data: {'id_token': idToken},
        options: Options(extra: const {'skipAuth': true}),
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<AuthResponse> loginApple(String idToken) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/apple',
        data: {'id_token': idToken},
        options: Options(extra: const {'skipAuth': true}),
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _client.dio.delete<void>('/me');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<User> me() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/me');
      return User.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<User> verifyEmail(String token) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/verify-email',
        data: {'token': token.trim()},
        options: Options(extra: const {'skipAuth': true}),
      );
      return User.fromJson(response.data!['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> resendVerification() async {
    try {
      await _client.dio.post<void>('/auth/resend-verification');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _client.dio.post<void>(
        '/auth/forgot-password',
        data: {'email': email.trim()},
        options: Options(extra: const {'skipAuth': true}),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> resetPassword(String token, String password) async {
    try {
      await _client.dio.post<void>(
        '/auth/reset-password',
        data: {'token': token.trim(), 'password': password},
        options: Options(extra: const {'skipAuth': true}),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
