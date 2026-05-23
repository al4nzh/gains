import 'package:gains/features/routines/models/routine_exercise.dart';

class RoutineSummary {
  const RoutineSummary({
    required this.id,
    required this.name,
    this.description,
    required this.exerciseCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final int exerciseCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RoutineSummary.fromJson(Map<String, dynamic> json) {
    return RoutineSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      exerciseCount: json['exercise_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class Routine extends RoutineSummary {
  const Routine({
    required super.id,
    required super.name,
    super.description,
    required super.exerciseCount,
    required super.createdAt,
    required super.updatedAt,
    required this.exercises,
  });

  final List<RoutineExercise> exercises;

  factory Routine.fromJson(Map<String, dynamic> json) {
    final exercises = (json['exercises'] as List<dynamic>? ?? [])
        .map((e) => RoutineExercise.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return Routine(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      exerciseCount: json['exercise_count'] as int? ?? exercises.length,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      exercises: exercises,
    );
  }
}
