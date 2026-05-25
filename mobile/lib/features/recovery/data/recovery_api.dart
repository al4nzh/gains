import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/recovery/models/recovery_checkin.dart';

class RecoveryApi {
  RecoveryApi(this._client);

  final ApiClient _client;

  Future<RecoveryCheckinStatus> getStatus(String checkinDate) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/recovery-checkins/status',
        queryParameters: {'checkin_date': checkinDate},
      );
      return RecoveryCheckinStatus.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<RecoveryCheckin> submitCheckin(RecoveryCheckinInput input) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/recovery-checkins',
        data: input.toJson(),
      );
      return RecoveryCheckin.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
