import 'package:flutter/material.dart';
import 'package:gains/core/preferences/body_units_preference.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/units/body_units.dart';
import 'package:gains/features/ai/models/coach_action.dart';
import 'package:gains/features/ai/presentation/action_labels.dart';
import 'package:provider/provider.dart';

class CoachActionCard extends StatelessWidget {
  const CoachActionCard({
    super.key,
    required this.action,
    required this.onAccept,
    required this.onReject,
    this.busy = false,
  });

  final CoachAction action;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final units = context.watch<BodyUnitsPreference>().units;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    coachActionTitle(action.actionType),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(describeCoachAction(action, units)),
            if (action.reason != null && action.reason!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                action.reason!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : onAccept,
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
