class RoutineTemplateSummary {
  const RoutineTemplateSummary({
    required this.id,
    required this.name,
    this.description,
    required this.exerciseCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final int exerciseCount;
  final DateTime createdAt;

  factory RoutineTemplateSummary.fromJson(Map<String, dynamic> json) {
    return RoutineTemplateSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      exerciseCount: json['exercise_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class RoutineTemplateExercise {
  const RoutineTemplateExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.position,
    this.targetSets,
    this.targetRepMin,
    this.targetRepMax,
    this.restSeconds,
    this.notes,
  });

  final String id;
  final String exerciseId;
  final String exerciseName;
  final int position;
  final int? targetSets;
  final int? targetRepMin;
  final int? targetRepMax;
  final int? restSeconds;
  final String? notes;

  factory RoutineTemplateExercise.fromJson(Map<String, dynamic> json) {
    return RoutineTemplateExercise(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      position: json['position'] as int,
      targetSets: json['target_sets'] as int?,
      targetRepMin: json['target_rep_min'] as int?,
      targetRepMax: json['target_rep_max'] as int?,
      restSeconds: json['rest_seconds'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

class RoutineTemplate extends RoutineTemplateSummary {
  const RoutineTemplate({
    required super.id,
    required super.name,
    super.description,
    required super.exerciseCount,
    required super.createdAt,
    required this.exercises,
  });

  final List<RoutineTemplateExercise> exercises;

  factory RoutineTemplate.fromJson(Map<String, dynamic> json) {
    final exercises = (json['exercises'] as List<dynamic>? ?? [])
        .map((e) => RoutineTemplateExercise.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return RoutineTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      exerciseCount: json['exercise_count'] as int? ?? exercises.length,
      createdAt: DateTime.parse(json['created_at'] as String),
      exercises: exercises,
    );
  }
}
