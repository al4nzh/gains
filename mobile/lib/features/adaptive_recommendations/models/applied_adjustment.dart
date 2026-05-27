import 'package:gains/features/adaptive_recommendations/models/adaptive_recommendation.dart';

class AppliedAdjustment {
  const AppliedAdjustment({
    required this.recommendationId,
    required this.type,
    this.targetExerciseId,
    this.targetRoutineExerciseId,
    this.targetMuscleGroup,
    required this.change,
  });

  final String recommendationId;
  final String type;
  final String? targetExerciseId;
  final String? targetRoutineExerciseId;
  final String? targetMuscleGroup;
  final SuggestedChange change;

  factory AppliedAdjustment.fromJson(Map<String, dynamic> json) {
    return AppliedAdjustment(
      recommendationId: json['recommendation_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      targetExerciseId: json['target_exercise_id'] as String?,
      targetRoutineExerciseId: json['target_routine_exercise_id'] as String?,
      targetMuscleGroup: json['target_muscle_group'] as String?,
      change: SuggestedChange.fromJson(json['change']),
    );
  }
}
