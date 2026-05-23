class RoutineExercise {
  const RoutineExercise({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.exerciseName,
    required this.position,
    this.targetSets,
    this.targetRepMin,
    this.targetRepMax,
    this.targetRpe,
    this.restSeconds,
    this.notes,
  });

  final String id;
  final String routineId;
  final String exerciseId;
  final String exerciseName;
  final int position;
  final int? targetSets;
  final int? targetRepMin;
  final int? targetRepMax;
  final double? targetRpe;
  final int? restSeconds;
  final String? notes;

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    return RoutineExercise(
      id: json['id'] as String,
      routineId: json['routine_id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      position: json['position'] as int,
      targetSets: json['target_sets'] as int?,
      targetRepMin: json['target_rep_min'] as int?,
      targetRepMax: json['target_rep_max'] as int?,
      targetRpe: (json['target_rpe'] as num?)?.toDouble(),
      restSeconds: json['rest_seconds'] as int?,
      notes: json['notes'] as String?,
    );
  }
}
