class FinishStats {
  const FinishStats({
    required this.totalVolumeKg,
    required this.durationSeconds,
    required this.setCount,
    required this.exerciseCount,
    required this.e1rmByExercise,
    required this.prs,
    this.strengthElo,
  });

  final double totalVolumeKg;
  final int durationSeconds;
  final int setCount;
  final int exerciseCount;
  final List<E1rmExerciseStat> e1rmByExercise;
  final List<PrStat> prs;
  final FinishEloStat? strengthElo;

  factory FinishStats.fromJson(Map<String, dynamic> json) {
    return FinishStats(
      totalVolumeKg: (json['total_volume_kg'] as num).toDouble(),
      durationSeconds: json['duration_seconds'] as int,
      setCount: json['set_count'] as int,
      exerciseCount: json['exercise_count'] as int,
      e1rmByExercise: (json['e1rm_by_exercise'] as List<dynamic>? ?? [])
          .map((e) => E1rmExerciseStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      prs: (json['prs'] as List<dynamic>? ?? [])
          .map((e) => PrStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      strengthElo: json['strength_elo'] != null
          ? FinishEloStat.fromJson(json['strength_elo'] as Map<String, dynamic>)
          : null,
    );
  }
}

class E1rmExerciseStat {
  const E1rmExerciseStat({
    required this.exerciseId,
    required this.exerciseName,
    required this.bestE1rmKg,
  });

  final String exerciseId;
  final String exerciseName;
  final double bestE1rmKg;

  factory E1rmExerciseStat.fromJson(Map<String, dynamic> json) {
    return E1rmExerciseStat(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      bestE1rmKg: (json['best_e1rm_kg'] as num).toDouble(),
    );
  }
}

class PrStat {
  const PrStat({
    required this.exerciseId,
    required this.exerciseName,
    required this.previousBestE1rmKg,
    required this.newBestE1rmKg,
  });

  final String exerciseId;
  final String exerciseName;
  final double previousBestE1rmKg;
  final double newBestE1rmKg;

  factory PrStat.fromJson(Map<String, dynamic> json) {
    return PrStat(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      previousBestE1rmKg: (json['previous_best_e1rm_kg'] as num).toDouble(),
      newBestE1rmKg: (json['new_best_e1rm_kg'] as num).toDouble(),
    );
  }
}

class FinishEloStat {
  const FinishEloStat({
    required this.before,
    required this.after,
    required this.delta,
    required this.change30d,
    required this.bodyweightKg,
    required this.sessionScoreBw,
    this.skipped = false,
  });

  final int before;
  final int after;
  final int delta;
  final int change30d;
  final double bodyweightKg;
  final double sessionScoreBw;
  final bool skipped;

  factory FinishEloStat.fromJson(Map<String, dynamic> json) {
    return FinishEloStat(
      before: json['before'] as int,
      after: json['after'] as int,
      delta: json['delta'] as int,
      change30d: json['change_30d'] as int,
      bodyweightKg: (json['bodyweight_kg'] as num).toDouble(),
      sessionScoreBw: (json['session_score_bw'] as num).toDouble(),
      skipped: json['skipped'] as bool? ?? false,
    );
  }
}
