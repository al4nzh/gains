import 'package:gains/features/routines/models/routine_exercise.dart';
import 'package:gains/features/routines/models/routine_template.dart';

String formatRepRange(int? min, int? max) {
  if (min != null && max != null) {
    if (min == max) return '$min reps';
    return '$min–$max reps';
  }
  if (min != null) return '$min+ reps';
  if (max != null) return '≤$max reps';
  return '';
}

String formatSetsReps(int? sets, int? repMin, int? repMax) {
  final parts = <String>[];
  if (sets != null) parts.add('$sets sets');
  final reps = formatRepRange(repMin, repMax);
  if (reps.isNotEmpty) parts.add(reps);
  return parts.join(' · ');
}

String formatRest(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  if (seconds < 60) return '${seconds}s rest';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s > 0 ? '${m}m ${s}s rest' : '${m}m rest';
}

String exerciseLineSubtitle({
  int? sets,
  int? repMin,
  int? repMax,
  int? restSeconds,
}) {
  final parts = <String>[
    formatSetsReps(sets, repMin, repMax),
    formatRest(restSeconds),
  ]..removeWhere((p) => p.isEmpty);
  return parts.join(' · ');
}

String routineExerciseSubtitle(RoutineExercise e) => exerciseLineSubtitle(
      sets: e.targetSets,
      repMin: e.targetRepMin,
      repMax: e.targetRepMax,
      restSeconds: e.restSeconds,
    );

String templateExerciseSubtitle(RoutineTemplateExercise e) => exerciseLineSubtitle(
      sets: e.targetSets,
      repMin: e.targetRepMin,
      repMax: e.targetRepMax,
      restSeconds: e.restSeconds,
    );
