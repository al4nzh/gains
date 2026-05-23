import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/routines/models/routine.dart';
import 'package:gains/features/routines/models/routine_exercise.dart';
import 'package:gains/features/routines/models/routine_template.dart';

class RoutineApi {
  RoutineApi(this._client);

  final ApiClient _client;

  Future<List<RoutineSummary>> listRoutines() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/routines');
      final list = response.data!['routines'] as List<dynamic>;
      return list.map((e) => RoutineSummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Routine> getRoutine(String id) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/routines/$id');
      return Routine.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Routine> createRoutine({String? name, String? description}) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/routines',
        data: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
        },
      );
      return Routine.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Routine> updateRoutine(
    String id, {
    String? name,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;

      final response = await _client.dio.put<Map<String, dynamic>>(
        '/routines/$id',
        data: body,
      );
      return Routine.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<RoutineExercise> addExercise(
    String routineId, {
    required String exerciseId,
    int? targetSets,
    int? targetRepMin,
    int? targetRepMax,
    double? targetRpe,
    int? restSeconds,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/routines/$routineId/exercises',
        data: {
          'exercise_id': exerciseId,
          if (targetSets != null) 'target_sets': targetSets,
          if (targetRepMin != null) 'target_rep_min': targetRepMin,
          if (targetRepMax != null) 'target_rep_max': targetRepMax,
          if (targetRpe != null) 'target_rpe': targetRpe,
          if (restSeconds != null) 'rest_seconds': restSeconds,
          if (notes != null) 'notes': notes,
        },
      );
      return RoutineExercise.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<RoutineExercise> updateExercise(
    String routineId,
    String routineExerciseId, {
    int? targetSets,
    int? targetRepMin,
    int? targetRepMax,
    double? targetRpe,
    int? restSeconds,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (targetSets != null) body['target_sets'] = targetSets;
      if (targetRepMin != null) body['target_rep_min'] = targetRepMin;
      if (targetRepMax != null) body['target_rep_max'] = targetRepMax;
      if (targetRpe != null) body['target_rpe'] = targetRpe;
      if (restSeconds != null) body['rest_seconds'] = restSeconds;
      if (notes != null) body['notes'] = notes;

      final response = await _client.dio.put<Map<String, dynamic>>(
        '/routines/$routineId/exercises/$routineExerciseId',
        data: body,
      );
      return RoutineExercise.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteExercise(String routineId, String routineExerciseId) async {
    try {
      await _client.dio.delete<void>('/routines/$routineId/exercises/$routineExerciseId');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<RoutineTemplateSummary>> listTemplates() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/routine-templates');
      final list = response.data!['templates'] as List<dynamic>;
      return list
          .map((e) => RoutineTemplateSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<RoutineTemplate> getTemplate(String id) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/routine-templates/$id');
      return RoutineTemplate.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Routine> copyTemplate(String templateId, {String? name}) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/routine-templates/$templateId/copy',
        data: name != null && name.trim().isNotEmpty ? {'name': name.trim()} : {},
      );
      return Routine.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
