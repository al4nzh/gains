import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/profile/models/profile.dart';
import 'package:gains/features/profile/models/profile_update.dart';

class ProfileApi {
  ProfileApi(this._client);

  final ApiClient _client;

  Future<Profile> getProfile() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/profile');
      return Profile.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Profile> updateProfile(ProfileUpdate update) async {
    try {
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/profile',
        data: update.toJson(),
      );
      return Profile.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
