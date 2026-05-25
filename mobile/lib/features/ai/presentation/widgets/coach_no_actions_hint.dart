import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';

/// Shown when the coach message suggests changes but no Accept/Reject cards arrived.
class CoachNoActionsHint extends StatelessWidget {
  const CoachNoActionsHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No apply buttons this time — the coach must send structured actions, not only text. '
                'Try: “Add bench press to my Beginner Full Body routine: 3 sets, 8–12 reps.”',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool coachMessageImpliesActions(String message) {
  final lower = message.toLowerCase();
  const cues = [
    'propose',
    'suggest',
    'add ',
    'remove ',
    'replace ',
    'let me know if you want',
    "here's what",
    'i will add',
    "i'll add",
    'integrate',
    'incorporate',
  ];
  return cues.any(lower.contains);
}
