import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/adaptive_recommendations/models/adaptive_recommendation.dart';

class AdaptiveRecommendationsApi {
  AdaptiveRecommendationsApi(this._client);

  final ApiClient _client;

  Future<AdaptiveRecommendationsResponse> getForRoutine(String routineId) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/adaptive-recommendations/routine/$routineId',
      );
      return AdaptiveRecommendationsResponse.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ApplyAdaptiveRecommendationResponse> apply({
    required String workoutId,
    required String recommendationId,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/adaptive-recommendations/apply',
        data: {
          'workout_id': workoutId,
          'recommendation_id': recommendationId,
        },
      );
      return ApplyAdaptiveRecommendationResponse.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

