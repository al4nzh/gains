import 'package:gains/core/units/body_units.dart';
import 'package:gains/features/ai/models/coach_action.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';
import 'package:gains/features/routines/presentation/routine_formatters.dart';

String coachActionTitle(String actionType) {
  switch (actionType) {
    case 'update_goal':
      return 'Update goal';
    case 'update_injury_notes':
      return 'Update injury notes';
    case 'update_bodyweight':
      return 'Update bodyweight';
    case 'update_height':
      return 'Update height';
    case 'add_exercise_to_routine':
      return 'Add exercise';
    case 'remove_exercise_from_routine':
      return 'Remove exercise';
    case 'replace_exercise_in_routine':
      return 'Replace exercise';
    case 'update_routine_exercise_sets':
      return 'Update sets';
    case 'update_routine_exercise_rep_range':
      return 'Update rep range';
    case 'update_routine_exercise_rest_seconds':
      return 'Update rest';
    case 'rename_routine':
      return 'Rename routine';
    default:
      return humanizeSnake(actionType);
  }
}

String describeCoachAction(CoachAction action, BodyUnitSystem units) {
  final p = action.payload ?? {};
  switch (action.actionType) {
    case 'update_goal':
      final goal = p['goal']?.toString();
      return goal != null ? 'Set goal to ${humanizeSnake(goal)}' : 'Update training goal';
    case 'update_injury_notes':
      final notes = p['injury_notes']?.toString();
      return notes != null && notes.isNotEmpty ? 'Set injury notes: $notes' : 'Clear or update injury notes';
    case 'update_bodyweight':
      final w = p['weight_kg'];
      if (w is num) {
        return 'Set bodyweight to ${BodyUnits.formatWeightDisplay(w.toDouble(), units)}';
      }
      return 'Update bodyweight';
    case 'update_height':
      final h = p['height_cm'];
      if (h is num) {
        return 'Set height to ${BodyUnits.formatHeightDisplay(h.toDouble(), units)}';
      }
      return 'Update height';
    case 'rename_routine':
      final name = p['name']?.toString();
      return name != null ? 'Rename routine to “$name”' : 'Rename routine';
    case 'add_exercise_to_routine':
      final name = p['exercise_name']?.toString() ?? 'exercise';
      final detail = exerciseLineSubtitle(
        sets: p['target_sets'] as int?,
        repMin: p['target_rep_min'] as int?,
        repMax: p['target_rep_max'] as int?,
        restSeconds: p['rest_seconds'] as int?,
      );
      return detail.isEmpty ? 'Add $name to routine' : 'Add $name · $detail';
    case 'remove_exercise_from_routine':
      return 'Remove an exercise from your routine';
    case 'replace_exercise_in_routine':
      final oldName = p['exercise_name']?.toString();
      final newName = p['new_exercise_name']?.toString();
      if (oldName != null && newName != null) return 'Replace $oldName with $newName';
      return 'Replace an exercise in your routine';
    case 'update_routine_exercise_sets':
      final sets = p['target_sets'];
      return sets != null ? 'Set target sets to $sets' : 'Update target sets';
    case 'update_routine_exercise_rep_range':
      final min = p['target_rep_min'] as int?;
      final max = p['target_rep_max'] as int?;
      final reps = formatRepRange(min, max);
      return reps.isNotEmpty ? 'Set rep range to $reps' : 'Update rep range';
    case 'update_routine_exercise_rest_seconds':
      final rest = p['rest_seconds'] as int?;
      final label = formatRest(rest);
      return label.isNotEmpty ? 'Set $label' : 'Update rest time';
    default:
      return coachActionTitle(action.actionType);
  }
}
