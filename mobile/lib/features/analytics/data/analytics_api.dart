import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/analytics/models/exercise_detail.dart';
import 'package:gains/features/analytics/models/exercise_progression.dart';

class AnalyticsApi {
  AnalyticsApi(this._client);

  final ApiClient _client;

  Future<List<ExerciseProgressionRow>> listExercises() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/analytics/exercises',
      );
      final list = response.data!['exercises'] as List<dynamic>? ?? [];
      return list
          .map((e) => ExerciseProgressionRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ExerciseDetail> getExerciseDetail(String exerciseId) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/analytics/exercises/$exerciseId',
      );
      return ExerciseDetail.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Map<String, SetLoadSummary?>> lastBestSetsForExercises(
    Iterable<String> exerciseIds,
  ) async {
    final ids = exerciseIds.toSet().toList();
    final out = <String, SetLoadSummary?>{};
    await Future.wait(
      ids.map((id) async {
        try {
          final detail = await getExerciseDetail(id);
          out[id] = detail.lastBestSet;
        } catch (_) {
          out[id] = null;
        }
      }),
    );
    return out;
  }
}
