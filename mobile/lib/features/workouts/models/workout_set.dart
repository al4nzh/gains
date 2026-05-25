class WorkoutSet {
  const WorkoutSet({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
    required this.weightKg,
    this.rpe,
    this.isFailure = false,
    this.notes,
  });

  final String id;
  final String workoutId;
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final int reps;
  final double weightKg;
  final double? rpe;
  final bool isFailure;
  final String? notes;

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: json['id'] as String,
      workoutId: json['workout_id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      setNumber: json['set_number'] as int,
      reps: json['reps'] as int,
      weightKg: (json['weight_kg'] as num).toDouble(),
      rpe: (json['rpe'] as num?)?.toDouble(),
      isFailure: json['is_failure'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  String get summary {
    final parts = <String>['$reps × ${weightKg % 1 == 0 ? weightKg.toInt() : weightKg} kg'];
    if (rpe != null) parts.add('RPE ${rpe!.toStringAsFixed(1)}');
    if (isFailure) parts.add('failure');
    return parts.join(' · ');
  }
}
