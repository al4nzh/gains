class SuggestedChange {
  const SuggestedChange({
    this.setsDelta,
    this.weightDeltaKg,
    this.weightDeltaPct,
    this.replaceExerciseId,
    this.replaceExerciseName,
  });

  final int? setsDelta;
  final double? weightDeltaKg;
  final double? weightDeltaPct;
  final String? replaceExerciseId;
  final String? replaceExerciseName;

  factory SuggestedChange.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const SuggestedChange();
    }
    return SuggestedChange(
      setsDelta: (json['sets_delta'] as num?)?.toInt(),
      weightDeltaKg: (json['weight_delta_kg'] as num?)?.toDouble(),
      weightDeltaPct: (json['weight_delta_pct'] as num?)?.toDouble(),
      replaceExerciseId: json['replace_exercise_id'] as String?,
      replaceExerciseName: json['replace_exercise_name'] as String?,
    );
  }

  /// Short human-readable summary for the card subtitle.
  String get summary {
    if (setsDelta != null && setsDelta != 0) {
      final sign = setsDelta! > 0 ? '+' : '';
      return '$sign$setsDelta set${setsDelta!.abs() == 1 ? '' : 's'}';
    }
    if (weightDeltaKg != null && weightDeltaKg != 0) {
      final sign = weightDeltaKg! > 0 ? '+' : '';
      return '$sign${weightDeltaKg!.toStringAsFixed(1)} kg';
    }
    if (weightDeltaPct != null && weightDeltaPct != 0) {
      return '${weightDeltaPct!.toStringAsFixed(0)}% intensity';
    }
    if (replaceExerciseName != null && replaceExerciseName!.isNotEmpty) {
      return 'Swap to $replaceExerciseName';
    }
    return '';
  }
}

class AdaptiveRecommendationContextSummary {
  const AdaptiveRecommendationContextSummary({
    this.sharpnessScore,
    this.latestSleepHours,
    this.latestEnergy,
    this.hasInjuryNotes = false,
    this.recoveryCheckinOk = false,
  });

  final int? sharpnessScore;
  final double? latestSleepHours;
  final int? latestEnergy;
  final bool hasInjuryNotes;
  final bool recoveryCheckinOk;

  factory AdaptiveRecommendationContextSummary.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const AdaptiveRecommendationContextSummary();
    }
    return AdaptiveRecommendationContextSummary(
      sharpnessScore: (json['sharpness_score'] as num?)?.toInt(),
      latestSleepHours: (json['latest_sleep_hours'] as num?)?.toDouble(),
      latestEnergy: (json['latest_energy'] as num?)?.toInt(),
      hasInjuryNotes: json['has_injury_notes'] as bool? ?? false,
      recoveryCheckinOk: json['recovery_checkin_ok'] as bool? ?? false,
    );
  }

  String? get subtitle {
    final parts = <String>[];
    if (sharpnessScore != null) parts.add('Sharpness $sharpnessScore');
    if (latestSleepHours != null) parts.add('Sleep ${latestSleepHours!.toStringAsFixed(1)}h');
    if (latestEnergy != null) parts.add('Energy $latestEnergy/5');
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}

class AdaptiveRecommendation {
  const AdaptiveRecommendation({
    required this.id,
    required this.type,
    this.targetExerciseId,
    this.targetRoutineExerciseId,
    this.targetMuscleGroup,
    required this.reason,
    required this.message,
    required this.suggestedChange,
    required this.confidence,
  });

  final String id;
  final String type;
  final String? targetExerciseId;
  final String? targetRoutineExerciseId;
  final String? targetMuscleGroup;
  final String reason;
  final String message;
  final SuggestedChange suggestedChange;
  final String confidence;

  factory AdaptiveRecommendation.fromJson(Map<String, dynamic> json) {
    return AdaptiveRecommendation(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      targetExerciseId: json['target_exercise_id'] as String?,
      targetRoutineExerciseId: json['target_routine_exercise_id'] as String?,
      targetMuscleGroup: json['target_muscle_group'] as String?,
      reason: json['reason'] as String? ?? '',
      message: json['message'] as String? ?? '',
      suggestedChange: SuggestedChange.fromJson(json['suggested_change']),
      confidence: json['confidence'] as String? ?? 'medium',
    );
  }
}

class AdaptiveRecommendationsResponse {
  const AdaptiveRecommendationsResponse({
    required this.recommendations,
    this.contextSummary,
  });

  final List<AdaptiveRecommendation> recommendations;
  final AdaptiveRecommendationContextSummary? contextSummary;

  factory AdaptiveRecommendationsResponse.fromJson(Map<String, dynamic> json) {
    final recs = (json['recommendations'] as List<dynamic>? ?? [])
        .map((e) => AdaptiveRecommendation.fromJson(e as Map<String, dynamic>))
        .toList();
    final summaryRaw = json['context_summary'];
    return AdaptiveRecommendationsResponse(
      recommendations: recs,
      contextSummary: summaryRaw == null
          ? null
          : AdaptiveRecommendationContextSummary.fromJson(summaryRaw),
    );
  }
}

class ApplyAdaptiveRecommendationResponse {
  const ApplyAdaptiveRecommendationResponse({this.adaptiveAdjustments});

  final List<Map<String, dynamic>>? adaptiveAdjustments;

  factory ApplyAdaptiveRecommendationResponse.fromJson(Map<String, dynamic> json) {
    final list = json['adaptive_adjustments'] as List<dynamic>?;
    return ApplyAdaptiveRecommendationResponse(
      adaptiveAdjustments:
          list?.map((e) => (e as Map).cast<String, dynamic>()).toList(),
    );
  }
}
