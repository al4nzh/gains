/// Response from `POST /ai/analyze-workout/:workoutId` (cached or newly generated).
class WorkoutAnalysisInsight {
  const WorkoutAnalysisInsight({
    required this.id,
    required this.workoutId,
    required this.insightType,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String workoutId;
  final String insightType;
  final String title;
  final String message;
  final DateTime createdAt;

  factory WorkoutAnalysisInsight.fromJson(Map<String, dynamic> json) {
    return WorkoutAnalysisInsight(
      id: json['id'] as String,
      workoutId: json['workout_id'] as String,
      insightType: json['insight_type'] as String? ?? 'workout_analysis',
      title: json['title'] as String? ?? 'Workout analysis',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
