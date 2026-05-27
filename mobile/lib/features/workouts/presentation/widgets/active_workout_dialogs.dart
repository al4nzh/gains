import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';

enum _ActiveWorkoutAction { resume, discard }

Future<_ActiveWorkoutAction?> _showActiveWorkoutConflictDialog(BuildContext context) {
  return showDialog<_ActiveWorkoutAction>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('You have an active workout'),
      content: const Text(
        'Finish or discard it before starting another session, or resume where you left off.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _ActiveWorkoutAction.discard),
          child: Text(
            'Discard and start new',
            style: TextStyle(color: AppColors.error.withValues(alpha: 0.95)),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _ActiveWorkoutAction.resume),
          child: const Text('Resume workout'),
        ),
      ],
    ),
  );
}

/// Second step before delete — avoid accidental loss of in-progress work.
Future<bool> showDiscardWorkoutConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Discard workout?'),
      content: const Text('Are you sure? This workout won\'t be saved.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Discard',
            style: TextStyle(color: AppColors.error.withValues(alpha: 0.95)),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Resume vs discard-and-restart when [POST /workouts] returns 409.
Future<bool> handleActiveWorkoutConflict({
  required BuildContext context,
  required String activeWorkoutId,
  required Future<void> Function() onDiscardAndRestart,
  required void Function(String workoutId) onResume,
}) async {
  final action = await _showActiveWorkoutConflictDialog(context);
  if (!context.mounted) return false;
  if (action == null) return false;

  if (action == _ActiveWorkoutAction.resume) {
    onResume(activeWorkoutId);
    return true;
  }

  final confirmed = await showDiscardWorkoutConfirmDialog(context);
  if (!context.mounted) return false;
  if (!confirmed) return false;

  await onDiscardAndRestart();
  return true;
}
