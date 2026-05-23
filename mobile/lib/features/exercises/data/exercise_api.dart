import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/exercises/models/catalog_exercise.dart';

class ExerciseApi {
  ExerciseApi(this._client);

  final ApiClient _client;

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
