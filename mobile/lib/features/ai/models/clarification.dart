class ExerciseMatch {
  const ExerciseMatch({
    required this.exerciseId,
    required this.exerciseName,
  });

  final String exerciseId;
  final String exerciseName;

  factory ExerciseMatch.fromJson(Map<String, dynamic> json) {
    return ExerciseMatch(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
    );
  }
}

class AiClarification {
  const AiClarification({
    required this.required,
    required this.message,
    this.possibleMatches = const [],
  });

  final bool required;
  final String message;
  final List<ExerciseMatch> possibleMatches;

  factory AiClarification.fromJson(Map<String, dynamic> json) {
    return AiClarification(
      required: json['clarification_required'] as bool? ?? true,
      message: json['message'] as String? ?? '',
      possibleMatches: (json['possible_matches'] as List<dynamic>? ?? [])
          .map((e) => ExerciseMatch.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
