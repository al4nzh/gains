import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/workouts/models/finish_stats.dart';
import 'package:gains/features/workouts/models/workout.dart';
import 'package:gains/features/workouts/models/workout_set.dart';

class WorkoutApi {
  WorkoutApi(this._client);

  final ApiClient _client;

  Future<List<Workout>> listWorkouts() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/workouts');
      final list = response.data!['workouts'] as List<dynamic>;
      return list.map((e) => Workout.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Workout> getWorkout(String id) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/workouts/$id');
      return Workout.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Workout> startWorkout({String? routineId, String? name}) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/workouts',
        data: {
          if (routineId != null) 'routine_id': routineId,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );
      return Workout.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<WorkoutSet> addSet(
    String workoutId, {
    required String exerciseId,
    required int reps,
    required double weightKg,
    int? setNumber,
    double? rpe,
    bool isFailure = false,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/workouts/$workoutId/sets',
        data: {
          'exercise_id': exerciseId,
          'reps': reps,
          'weight_kg': weightKg,
          if (setNumber != null) 'set_number': setNumber,
          if (rpe != null) 'rpe': rpe,
          'is_failure': isFailure,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return WorkoutSet.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<WorkoutSet> updateSet(
    String workoutId,
    String setId, {
    int? reps,
    double? weightKg,
    double? rpe,
    bool? isFailure,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (reps != null) body['reps'] = reps;
      if (weightKg != null) body['weight_kg'] = weightKg;
      if (rpe != null) body['rpe'] = rpe;
      if (isFailure != null) body['is_failure'] = isFailure;
      if (notes != null) body['notes'] = notes;

      final response = await _client.dio.put<Map<String, dynamic>>(
        '/workouts/$workoutId/sets/$setId',
        data: body,
      );
      return WorkoutSet.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteSet(String workoutId, String setId) async {
    try {
      await _client.dio.delete<void>('/workouts/$workoutId/sets/$setId');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<FinishStats> finishWorkout(String workoutId, {String? notes}) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/workouts/$workoutId/finish',
        data: notes != null && notes.trim().isNotEmpty ? {'notes': notes.trim()} : {},
      );
      return FinishStats.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
