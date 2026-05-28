import 'package:gains/features/adaptive_recommendations/models/applied_adjustment.dart';
import 'package:gains/features/analytics/models/exercise_detail.dart';
import 'package:gains/features/routines/models/routine_exercise.dart';
import 'package:gains/features/workouts/models/workout_set.dart';

const defaultTargetSets = 3;

class WorkoutSetSlot {
  const WorkoutSetSlot({
    required this.setNumber,
    this.logged,
    this.prefill,
  });

  final int setNumber;
  final WorkoutSet? logged;
  final SetLoadSummary? prefill;
}

class WorkoutExercisePlan {
  const WorkoutExercisePlan({
    required this.exerciseId,
    required this.exerciseName,
    this.targetSets,
    this.targetRepMin,
    this.targetRepMax,
    this.restSeconds,
    this.notes,
    required this.slots,
    this.lastBestSet,
  });

  final String exerciseId;
  final String exerciseName;
  final int? targetSets;
  final int? targetRepMin;
  final int? targetRepMax;
  final int? restSeconds;
  final String? notes;
  final List<WorkoutSetSlot> slots;
  final SetLoadSummary? lastBestSet;

  int get slotCount => slots.length;
}

List<WorkoutExercisePlan> buildWorkoutPlan({
  List<RoutineExercise>? routineExercises,
  required List<WorkoutSet> loggedSets,
  required Map<String, SetLoadSummary?> prefills,
}) {
  final loggedByExercise = <String, List<WorkoutSet>>{};
  for (final s in loggedSets) {
    loggedByExercise.putIfAbsent(s.exerciseId, () => []).add(s);
  }
  for (final sets in loggedByExercise.values) {
    sets.sort((a, b) => a.setNumber.compareTo(b.setNumber));
  }

  final plans = <WorkoutExercisePlan>[];
  final seen = <String>{};

  if (routineExercises != null) {
    final sorted = [...routineExercises]..sort((a, b) => a.position.compareTo(b.position));
    for (final re in sorted) {
      seen.add(re.exerciseId);
      plans.add(_planForExercise(
        exerciseId: re.exerciseId,
        exerciseName: re.exerciseName,
        targetSets: re.targetSets ?? defaultTargetSets,
        targetRepMin: re.targetRepMin,
        targetRepMax: re.targetRepMax,
        restSeconds: re.restSeconds,
        notes: re.notes,
        logged: loggedByExercise[re.exerciseId] ?? [],
        prefill: prefills[re.exerciseId],
      ));
    }
  }

  for (final entry in loggedByExercise.entries) {
    if (seen.contains(entry.key)) continue;
    final first = entry.value.first;
    plans.add(_planForExercise(
      exerciseId: entry.key,
      exerciseName: first.exerciseName,
      targetSets: entry.value.length > defaultTargetSets ? entry.value.length : defaultTargetSets,
      logged: entry.value,
      prefill: prefills[entry.key],
    ));
  }

  if (plans.isEmpty && routineExercises == null) {
    return plans;
  }

  return plans;
}

/// Applies session-only adjustments from POST /adaptive-recommendations/apply.
List<WorkoutExercisePlan> applyAdaptiveAdjustments(
  List<WorkoutExercisePlan> plan,
  List<AppliedAdjustment> adjustments,
) {
  if (adjustments.isEmpty) return plan;

  var next = [...plan];

  for (final adj in adjustments) {
    switch (adj.type) {
      case 'swap_exercise':
        final fromId = adj.targetExerciseId;
        final toId = adj.change.replaceExerciseId;
        final toName = adj.change.replaceExerciseName;
        if (fromId == null || toId == null || toName == null || toName.isEmpty) {
          continue;
        }
        final idx = next.indexWhere((p) => p.exerciseId == fromId);
        if (idx == -1) continue;
        final e = next[idx];
        next[idx] = WorkoutExercisePlan(
          exerciseId: toId,
          exerciseName: toName,
          targetSets: e.targetSets,
          targetRepMin: e.targetRepMin,
          targetRepMax: e.targetRepMax,
          restSeconds: e.restSeconds,
          notes: e.notes,
          slots: e.slots,
          lastBestSet: null,
        );
        break;
      case 'reduce_volume':
        final delta = adj.change.setsDelta;
        if (delta == null || delta >= 0) continue;
        final targetId = adj.targetExerciseId;
        if (targetId == null) continue;
        next = next.map((p) {
          if (p.exerciseId != targetId) return p;
          final baseSets = p.targetSets ?? p.slots.length;
          final newSets = (baseSets + delta).clamp(1, 99);
          return _trimPlanSlots(p, newSets);
        }).toList();
        break;
      case 'reduce_intensity':
      case 'deload':
        next = _applyWeightAdjustment(next, adj, decrease: true);
        break;
      case 'increase_weight':
        next = _applyWeightAdjustment(next, adj, decrease: false);
        break;
      default:
        break;
    }
  }

  return next;
}

List<WorkoutExercisePlan> _applyWeightAdjustment(
  List<WorkoutExercisePlan> plan,
  AppliedAdjustment adj, {
  required bool decrease,
}) {
  final targetId = adj.targetExerciseId;
  if (targetId == null) return plan;

  return plan.map((p) {
    if (p.exerciseId != targetId) return p;

    final base = p.lastBestSet;
    if (base == null || base.weightKg == null || base.weightKg! <= 0) return p;

    var newW = base.weightKg!;
    if (decrease) {
      final pct = adj.change.weightDeltaPct;
      if (pct == null) return p;
      newW = newW * (1 + pct / 100);
      if (newW <= 0) return p;
    } else {
      final delta = adj.change.weightDeltaKg;
      if (delta == null || delta <= 0) return p;
      newW = newW + delta;
    }

    final reps = base.reps ?? 8;
    final newPrefill = SetLoadSummary(reps: reps, weightKg: _roundKg(newW));
    final newSlots = p.slots.map((s) {
      if (s.logged != null) return s;
      return WorkoutSetSlot(
        setNumber: s.setNumber,
        logged: null,
        prefill: newPrefill,
      );
    }).toList();

    return WorkoutExercisePlan(
      exerciseId: p.exerciseId,
      exerciseName: p.exerciseName,
      targetSets: p.targetSets,
      targetRepMin: p.targetRepMin,
      targetRepMax: p.targetRepMax,
      restSeconds: p.restSeconds,
      notes: p.notes,
      slots: newSlots,
      lastBestSet: newPrefill,
    );
  }).toList();
}

double _roundKg(double w) => (w * 10).roundToDouble() / 10;

WorkoutExercisePlan _trimPlanSlots(WorkoutExercisePlan p, int newSetCount) {
  final slots = [...p.slots]..sort((a, b) => a.setNumber.compareTo(b.setNumber));
  final trimmed = slots.take(newSetCount).toList();
  return WorkoutExercisePlan(
    exerciseId: p.exerciseId,
    exerciseName: p.exerciseName,
    targetSets: newSetCount,
    targetRepMin: p.targetRepMin,
    targetRepMax: p.targetRepMax,
    restSeconds: p.restSeconds,
    notes: p.notes,
    slots: trimmed,
    lastBestSet: p.lastBestSet,
  );
}

WorkoutExercisePlan _planForExercise({
  required String exerciseId,
  required String exerciseName,
  required int targetSets,
  int? targetRepMin,
  int? targetRepMax,
  int? restSeconds,
  String? notes,
  required List<WorkoutSet> logged,
  SetLoadSummary? prefill,
}) {
  final loggedByNumber = {for (final s in logged) s.setNumber: s};
  final slotCount = targetSets > logged.length ? targetSets : logged.length;

  final slots = <WorkoutSetSlot>[];
  for (var n = 1; n <= slotCount; n++) {
    slots.add(WorkoutSetSlot(
      setNumber: n,
      logged: loggedByNumber[n],
      prefill: loggedByNumber[n] == null ? prefill : null,
    ));
  }

  return WorkoutExercisePlan(
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    targetSets: targetSets,
    targetRepMin: targetRepMin,
    targetRepMax: targetRepMax,
    restSeconds: restSeconds,
    notes: notes,
    slots: slots,
    lastBestSet: prefill,
  );
}

String formatLastBestSet(SetLoadSummary? s) {
  if (s == null || !s.hasValues) return '';
  final w = s.weightKg!;
  final weight = w % 1 == 0 ? w.toInt().toString() : w.toStringAsFixed(1);
  return 'Last: ${s.reps} × $weight kg';
}
