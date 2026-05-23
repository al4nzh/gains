import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/home/models/home_summary.dart';

class HomeApi {
  HomeApi(this._client);

  final ApiClient _client;

  Future<HomeSummary> fetchHome() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/home');
      return HomeSummary.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
