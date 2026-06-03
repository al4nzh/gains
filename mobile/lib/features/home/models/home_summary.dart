class HomeSummary {
  const HomeSummary({
    this.strengthElo,
    this.strengthEloRank,
    this.strengthEloPercentile,
    this.eloChange30d,
    required this.sharpness,
    this.latestWorkout,
    required this.weeklyVolumeKg,
    required this.weeklyVolumeWindowDays,
    required this.workoutConsistency,
    required this.streakDays,
  });

  final int? strengthElo;
  final String? strengthEloRank;
  final int? strengthEloPercentile;
  final int? eloChange30d;
  final SharpnessOverview sharpness;
  final WorkoutSnapshot? latestWorkout;
  final double weeklyVolumeKg;
  final int weeklyVolumeWindowDays;
  final WorkoutConsistency workoutConsistency;
  final int streakDays;

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    return HomeSummary(
      strengthElo: json['strength_elo'] as int?,
      strengthEloRank: json['strength_elo_rank'] as String?,
      strengthEloPercentile: json['strength_elo_percentile'] as int?,
      eloChange30d: json['elo_change_30d'] as int?,
      sharpness: SharpnessOverview.fromJson(
        json['sharpness'] as Map<String, dynamic>? ?? {},
      ),
      latestWorkout: json['latest_workout'] != null
          ? WorkoutSnapshot.fromJson(json['latest_workout'] as Map<String, dynamic>)
          : null,
      weeklyVolumeKg: (json['weekly_volume_kg'] as num?)?.toDouble() ?? 0,
      weeklyVolumeWindowDays: json['weekly_volume_window_days'] as int? ?? 7,
      workoutConsistency: WorkoutConsistency.fromJson(
        json['workout_consistency'] as Map<String, dynamic>? ?? {},
      ),
      streakDays: json['streak_days'] as int? ?? 0,
    );
  }
}

class SharpnessOverview {
  const SharpnessOverview({
    required this.score,
    required this.sleep01,
    required this.energy01,
    required this.protein01,
    required this.calories01,
    this.targetKcal,
    this.targetProteinG,
    required this.activityLevelResolved,
    required this.calorieActivityMultiplier,
  });

  final int score;
  final double sleep01;
  final double energy01;
  final double protein01;
  final double calories01;
  final int? targetKcal;
  final int? targetProteinG;
  final String activityLevelResolved;
  final double calorieActivityMultiplier;

  factory SharpnessOverview.fromJson(Map<String, dynamic> json) {
    return SharpnessOverview(
      score: json['score'] as int? ?? 0,
      sleep01: (json['sleep_0_1'] as num?)?.toDouble() ?? 0,
      energy01: (json['energy_0_1'] as num?)?.toDouble() ?? 0,
      protein01: (json['protein_alignment_0_1'] as num?)?.toDouble() ?? 0,
      calories01: (json['calorie_alignment_0_1'] as num?)?.toDouble() ?? 0,
      targetKcal: json['target_calories_kcal'] as int?,
      targetProteinG: json['target_protein_g'] as int?,
      activityLevelResolved: json['activity_level_resolved'] as String? ?? 'moderate',
      calorieActivityMultiplier:
          (json['calorie_activity_multiplier'] as num?)?.toDouble() ?? 1,
    );
  }
}

class WorkoutSnapshot {
  const WorkoutSnapshot({
    required this.workoutId,
    required this.completedAt,
    required this.totalVolumeKg,
    required this.durationSeconds,
    required this.setCount,
  });

  final String workoutId;
  final DateTime completedAt;
  final double totalVolumeKg;
  final int durationSeconds;
  final int setCount;

  factory WorkoutSnapshot.fromJson(Map<String, dynamic> json) {
    return WorkoutSnapshot(
      workoutId: json['workout_id'] as String,
      completedAt: DateTime.parse(json['completed_at'] as String),
      totalVolumeKg: (json['total_volume_kg'] as num).toDouble(),
      durationSeconds: json['duration_seconds'] as int,
      setCount: json['set_count'] as int,
    );
  }
}

class WorkoutConsistency {
  const WorkoutConsistency({
    required this.completedLast28Days,
    required this.avgPerWeek,
  });

  final int completedLast28Days;
  final double avgPerWeek;

  factory WorkoutConsistency.fromJson(Map<String, dynamic> json) {
    return WorkoutConsistency(
      completedLast28Days: json['completed_last_28_days'] as int? ?? 0,
      avgPerWeek: (json['avg_per_week'] as num?)?.toDouble() ?? 0,
    );
  }
}
