import 'package:gains/features/analytics/models/exercise_detail.dart';

/// One row from `GET /analytics/exercises`.
class ExerciseProgressionRow {
  const ExerciseProgressionRow({
    required this.exerciseId,
    required this.exerciseName,
    this.latestBestSet,
    required this.latestE1rmKg,
    required this.absoluteBestE1rmKg,
    this.absoluteBestSet,
    required this.e1rmChangeKg,
    this.e1rmChangePct,
    required this.dataPoints,
    required this.trend,
  });

  final String exerciseId;
  final String exerciseName;
  final SetLoadSummary? latestBestSet;
  final double latestE1rmKg;
  final double absoluteBestE1rmKg;
  final SetLoadSummary? absoluteBestSet;
  final double e1rmChangeKg;
  final double? e1rmChangePct;
  final int dataPoints;
  final String trend;

  factory ExerciseProgressionRow.fromJson(Map<String, dynamic> json) {
    return ExerciseProgressionRow(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      latestBestSet: json['latest_best_set'] != null
          ? SetLoadSummary.fromJson(json['latest_best_set'] as Map<String, dynamic>)
          : null,
      latestE1rmKg: (json['latest_e1rm_kg'] as num).toDouble(),
      absoluteBestE1rmKg: (json['absolute_best_e1rm_kg'] as num).toDouble(),
      absoluteBestSet: json['absolute_best_set'] != null
          ? SetLoadSummary.fromJson(json['absolute_best_set'] as Map<String, dynamic>)
          : null,
      e1rmChangeKg: (json['e1rm_change_kg'] as num?)?.toDouble() ?? 0,
      e1rmChangePct: (json['e1rm_change_pct'] as num?)?.toDouble(),
      dataPoints: json['data_points'] as int? ?? 0,
      trend: json['trend'] as String? ?? 'flat',
    );
  }
}
