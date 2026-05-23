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

  Future<User> me() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/me');
      return User.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
