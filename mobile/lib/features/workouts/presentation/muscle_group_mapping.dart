import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';
import 'package:gains/features/workouts/models/finish_stats.dart';
import 'package:gains/features/workouts/models/workout.dart';

/// Maps Gains catalog `muscle_group` values to [Muscle] regions on the body SVG.
Set<Muscle> musclesForCatalogGroup(String muscleGroup) {
  switch (muscleGroup.toLowerCase()) {
    case 'chest':
      return {Muscle.chestLeft, Muscle.chestRight};
    case 'shoulders':
      return {
        Muscle.deltsLeft,
        Muscle.deltsRight,
        Muscle.trapsLeft,
        Muscle.trapsRight,
      };
    case 'arms':
      return {
        Muscle.bicepsLeft,
        Muscle.bicepsRight,
        Muscle.tricepsLeft,
        Muscle.tricepsRight,
        Muscle.forearmsLeft,
        Muscle.forearmsRight,
      };
    case 'back':
      return {
        Muscle.latsBackLeft,
        Muscle.latsBackRight,
        Muscle.lowerLatsBackLeft,
        Muscle.lowerLatsBackRight,
        Muscle.trapsLeft,
        Muscle.trapsRight,
      };
    case 'legs':
      return {
        Muscle.quadsLeft,
        Muscle.quadsRight,
        Muscle.hamstringsLeft,
        Muscle.hamstringsRight,
        Muscle.glutesLeft,
        Muscle.glutesRight,
        Muscle.calvesLeft,
        Muscle.calvesRight,
      };
    case 'core':
      return {Muscle.abs};
    case 'full_body':
      return Muscle.values.toSet();
    default:
      return {};
  }
}

/// Highlight set for [InteractiveBodySvg] from logged exercises in this session.
Set<Muscle> highlightedMusclesForSession({
  required FinishStats stats,
  Workout? workout,
  required Map<String, String> exerciseIdToMuscleGroup,
}) {
  final groups = <String>{};

  for (final e in stats.e1rmByExercise) {
    final g = exerciseIdToMuscleGroup[e.exerciseId];
    if (g != null && g.isNotEmpty) groups.add(g);
  }

  if (workout != null) {
    for (final s in workout.sets) {
      final g = exerciseIdToMuscleGroup[s.exerciseId];
      if (g != null && g.isNotEmpty) groups.add(g);
    }
  }

  final muscles = <Muscle>{};
  for (final g in groups) {
    muscles.addAll(musclesForCatalogGroup(g));
  }
  return muscles;
}

/// Catalog muscle_group values for a set of exercise IDs.
Set<String> catalogMuscleGroupsForExerciseIds({
  required Set<String> exerciseIds,
  required Map<String, String> exerciseIdToMuscleGroup,
}) {
  final groups = <String>{};
  for (final id in exerciseIds) {
    final g = exerciseIdToMuscleGroup[id];
    if (g != null && g.isNotEmpty) groups.add(g);
  }
  return groups;
}

/// Highlight set for [InteractiveBodySvg] from a set of exercise IDs.
Set<Muscle> highlightedMusclesForExerciseIds({
  required Set<String> exerciseIds,
  required Map<String, String> exerciseIdToMuscleGroup,
}) {
  final groups = catalogMuscleGroupsForExerciseIds(
    exerciseIds: exerciseIds,
    exerciseIdToMuscleGroup: exerciseIdToMuscleGroup,
  );

  final muscles = <Muscle>{};
  for (final g in groups) {
    muscles.addAll(musclesForCatalogGroup(g));
  }
  return muscles;
}
