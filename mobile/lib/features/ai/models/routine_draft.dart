import 'package:gains/features/ai/models/clarification.dart';

class DraftRoutineExercise {
  const DraftRoutineExercise({
    required this.exerciseId,
    required this.exerciseName,
    this.targetSets,
    this.targetRepMin,
    this.targetRepMax,
    this.restSeconds,
    this.notes,
  });

  final String exerciseId;
  final String exerciseName;
  final int? targetSets;
  final int? targetRepMin;
  final int? targetRepMax;
  final int? restSeconds;
  final String? notes;

  factory DraftRoutineExercise.fromJson(Map<String, dynamic> json) {
    return DraftRoutineExercise(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      targetSets: json['target_sets'] as int?,
      targetRepMin: json['target_rep_min'] as int?,
      targetRepMax: json['target_rep_max'] as int?,
      restSeconds: json['rest_seconds'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

class DraftRoutine {
  const DraftRoutine({
    required this.name,
    this.description,
    required this.exercises,
  });

  final String name;
  final String? description;
  final List<DraftRoutineExercise> exercises;

  factory DraftRoutine.fromJson(Map<String, dynamic> json) {
    return DraftRoutine(
      name: json['name'] as String,
      description: json['description'] as String?,
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => DraftRoutineExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GenerateRoutinesResult {
  const GenerateRoutinesResult.preview({
    required this.draftId,
    required this.title,
    required this.routines,
  }) : clarification = null;

  const GenerateRoutinesResult.clarify(this.clarification)
      : draftId = null,
        title = null,
        routines = null;

  final String? draftId;
  final String? title;
  final List<DraftRoutine>? routines;
  final AiClarification? clarification;

  bool get isClarification => clarification != null;

  factory GenerateRoutinesResult.fromJson(Map<String, dynamic> json) {
    if (json['clarification'] != null) {
      return GenerateRoutinesResult.clarify(
        AiClarification.fromJson(json['clarification'] as Map<String, dynamic>),
      );
    }
    return GenerateRoutinesResult.preview(
      draftId: json['draft_id'] as String,
      title: json['title'] as String? ?? 'Generated plan',
      routines: (json['routines'] as List<dynamic>? ?? [])
          .map((e) => DraftRoutine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
