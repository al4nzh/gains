import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/ai/models/clarification.dart';

class CoachClarificationBanner extends StatelessWidget {
  const CoachClarificationBanner({super.key, required this.clarification});

  final AiClarification clarification;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryMuted.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.help_outline, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Clarification needed', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(clarification.message),
            if (clarification.possibleMatches.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Possible exercises:',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              ...clarification.possibleMatches.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• ${m.exerciseName}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
