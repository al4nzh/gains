class SetLoadSummary {
  const SetLoadSummary({this.reps, this.weightKg});

  final int? reps;
  final double? weightKg;

  factory SetLoadSummary.fromJson(Map<String, dynamic> json) {
    return SetLoadSummary(
      reps: json['reps'] as int?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
    );
  }

  bool get hasValues => reps != null && reps! > 0 && weightKg != null && weightKg! > 0;
}

class ExerciseHistoryEntry {
  const ExerciseHistoryEntry({
    required this.workoutId,
    required this.completedAt,
    required this.bestSet,
    required this.bestE1rmKg,
    required this.volumeKg,
    this.prs = const [],
  });

  final String workoutId;
  final DateTime completedAt;
  final SetLoadSummary bestSet;
  final double bestE1rmKg;
  final double volumeKg;
  final List<ExerciseHistoryPr> prs;

  factory ExerciseHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ExerciseHistoryEntry(
      workoutId: json['workout_id'] as String,
      completedAt: DateTime.parse(json['completed_at'] as String),
      bestSet: SetLoadSummary.fromJson(json['best_set'] as Map<String, dynamic>),
      bestE1rmKg: (json['best_e1rm_kg'] as num).toDouble(),
      volumeKg: (json['volume_kg'] as num?)?.toDouble() ?? 0,
      prs: (json['prs'] as List<dynamic>? ?? [])
          .map((e) => ExerciseHistoryPr.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExerciseHistoryPr {
  const ExerciseHistoryPr({
    required this.exerciseId,
    required this.exerciseName,
    required this.previousBestE1rmKg,
    required this.newBestE1rmKg,
  });

  final String exerciseId;
  final String exerciseName;
  final double previousBestE1rmKg;
  final double newBestE1rmKg;

  factory ExerciseHistoryPr.fromJson(Map<String, dynamic> json) {
    return ExerciseHistoryPr(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      previousBestE1rmKg: (json['previous_best_e1rm_kg'] as num).toDouble(),
      newBestE1rmKg: (json['new_best_e1rm_kg'] as num).toDouble(),
    );
  }
}

class ExerciseLatestComparison {
  const ExerciseLatestComparison({
    required this.previousCompletedAt,
    required this.e1rmChangeKg,
    this.e1rmChangePct,
    required this.volumeChangeKg,
    this.volumeChangePct,
    this.bestSetPrevious,
    this.bestSetCurrent,
  });

  final DateTime previousCompletedAt;
  final double e1rmChangeKg;
  final double? e1rmChangePct;
  final double volumeChangeKg;
  final double? volumeChangePct;
  final SetLoadSummary? bestSetPrevious;
  final SetLoadSummary? bestSetCurrent;

  factory ExerciseLatestComparison.fromJson(Map<String, dynamic> json) {
    return ExerciseLatestComparison(
      previousCompletedAt: DateTime.parse(json['previous_completed_at'] as String),
      e1rmChangeKg: (json['e1rm_change_kg'] as num).toDouble(),
      e1rmChangePct: (json['e1rm_change_pct'] as num?)?.toDouble(),
      volumeChangeKg: (json['volume_change_kg'] as num?)?.toDouble() ?? 0,
      volumeChangePct: (json['volume_change_pct'] as num?)?.toDouble(),
      bestSetPrevious: json['best_set_previous'] != null
          ? SetLoadSummary.fromJson(json['best_set_previous'] as Map<String, dynamic>)
          : null,
      bestSetCurrent: json['best_set_current'] != null
          ? SetLoadSummary.fromJson(json['best_set_current'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ExerciseDetail {
  const ExerciseDetail({
    required this.exerciseId,
    required this.exerciseName,
    required this.absoluteBestE1rmKg,
    this.absoluteBestSet,
    this.absoluteBestWorkoutId,
    this.absoluteBestCompletedAt,
    required this.history,
    this.latestComparison,
    required this.trendSummary,
  });

  final String exerciseId;
  final String exerciseName;
  final double absoluteBestE1rmKg;
  final SetLoadSummary? absoluteBestSet;
  final String? absoluteBestWorkoutId;
  final DateTime? absoluteBestCompletedAt;
  final List<ExerciseHistoryEntry> history;
  final ExerciseLatestComparison? latestComparison;
  final String trendSummary;

  /// Most recent completed session's best set (history is oldest → newest).
  SetLoadSummary? get lastBestSet {
    if (history.isEmpty) return null;
    final best = history.last.bestSet;
    return best.hasValues ? best : null;
  }

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) {
    return ExerciseDetail(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      absoluteBestE1rmKg: (json['absolute_best_e1rm_kg'] as num?)?.toDouble() ?? 0,
      absoluteBestSet: json['absolute_best_set'] != null
          ? SetLoadSummary.fromJson(json['absolute_best_set'] as Map<String, dynamic>)
          : null,
      absoluteBestWorkoutId: json['absolute_best_workout_id'] as String?,
      absoluteBestCompletedAt: json['absolute_best_completed_at'] != null
          ? DateTime.parse(json['absolute_best_completed_at'] as String)
          : null,
      history: (json['history'] as List<dynamic>? ?? [])
          .map((e) => ExerciseHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      latestComparison: json['latest_comparison'] != null
          ? ExerciseLatestComparison.fromJson(
              json['latest_comparison'] as Map<String, dynamic>,
            )
          : null,
      trendSummary: json['trend_summary'] as String? ?? 'no_data',
    );
  }
}
