import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/exercises/models/catalog_exercise.dart';

class ExerciseApi {
  ExerciseApi(this._client);

  final ApiClient _client;

  /// Exercise id → muscle_group for catalog lookups (paginated).
  Future<Map<String, String>> loadMuscleGroupMap() async {
    final map = <String, String>{};
    var offset = 0;
    const pageSize = 100;
    while (true) {
      final batch = await list(limit: pageSize, offset: offset);
      if (batch.isEmpty) break;
      for (final e in batch) {
        final mg = e.muscleGroup?.trim();
        if (mg != null && mg.isNotEmpty) map[e.id] = mg;
      }
      if (batch.length < pageSize) break;
      offset += pageSize;
      if (offset > 10000) break;
    }
    return map;
  }

  Future<List<CatalogExercise>> list({int limit = 50, int offset = 0}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/exercises',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final list = response.data!['exercises'] as List<dynamic>? ?? [];
      return list.map((e) => CatalogExercise.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Returns exercise id → GIF URL (ExerciseDB via backend).
  Future<Map<String, String>> lookupGifs(List<String> exerciseIds) async {
    final ids = exerciseIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/exercises/gifs',
        data: {'exercise_ids': ids},
      );
      final raw = response.data!['gifs'] as Map<String, dynamic>? ?? {};
      return raw.map((k, v) => MapEntry(k, v as String));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<CatalogExercise>> search(String query, {int limit = 30}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/exercises/search',
        queryParameters: {'q': query.trim(), 'limit': limit},
      );
      final list = response.data!['exercises'] as List<dynamic>;
      return list.map((e) => CatalogExercise.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
