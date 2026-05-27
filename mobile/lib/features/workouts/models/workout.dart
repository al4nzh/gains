import 'package:gains/features/adaptive_recommendations/models/applied_adjustment.dart';
import 'package:gains/features/workouts/models/finish_stats.dart';
import 'package:gains/features/workouts/models/workout_set.dart';

class Workout {
  const Workout({
    required this.id,
    this.routineId,
    this.name,
    required this.startedAt,
    this.completedAt,
    this.totalVolumeKg,
    this.durationSeconds,
    this.finishStats,
    required this.sets,
    this.adaptiveAdjustments = const [],
  });

  final String id;
  final String? routineId;
  final String? name;
  final DateTime startedAt;
  final DateTime? completedAt;
  final double? totalVolumeKg;
  final int? durationSeconds;
  final FinishStats? finishStats;
  final List<WorkoutSet> sets;
  final List<AppliedAdjustment> adaptiveAdjustments;

  bool get isInProgress => completedAt == null;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    return 'Workout';
  }

  factory Workout.fromJson(Map<String, dynamic> json) {
    FinishStats? stats;
    final rawStats = json['stats'];
    if (rawStats is Map<String, dynamic>) {
      stats = FinishStats.fromJson(rawStats);
    }

    final sets = (json['sets'] as List<dynamic>? ?? [])
        .map((e) => WorkoutSet.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        final nameCmp = a.exerciseName.compareTo(b.exerciseName);
        if (nameCmp != 0) return nameCmp;
        return a.setNumber.compareTo(b.setNumber);
      });

    final adjustments = (json['adaptive_adjustments'] as List<dynamic>? ?? [])
        .map((e) => AppliedAdjustment.fromJson(e as Map<String, dynamic>))
        .toList();

    return Workout(
      id: json['id'] as String,
      routineId: json['routine_id'] as String?,
      name: json['name'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      totalVolumeKg: (json['total_volume_kg'] as num?)?.toDouble(),
      durationSeconds: json['duration_seconds'] as int?,
      finishStats: stats,
      sets: sets,
      adaptiveAdjustments: adjustments,
    );
  }
}

class ExerciseSetGroup {
  const ExerciseSetGroup({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  final String exerciseId;
  final String exerciseName;
  final List<WorkoutSet> sets;
}

List<ExerciseSetGroup> groupSetsByExercise(List<WorkoutSet> sets) {
  final map = <String, ExerciseSetGroup>{};
  for (final s in sets) {
    final existing = map[s.exerciseId];
    if (existing == null) {
      map[s.exerciseId] = ExerciseSetGroup(
        exerciseId: s.exerciseId,
        exerciseName: s.exerciseName,
        sets: [s],
      );
    } else {
      map[s.exerciseId] = ExerciseSetGroup(
        exerciseId: s.exerciseId,
        exerciseName: s.exerciseName,
        sets: [...existing.sets, s],
      );
    }
  }
  return map.values.toList();
}
