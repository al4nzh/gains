import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';

class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final progress = (step + 1) / totalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Step ${step + 1} of $totalSteps',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                  ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppColors.surfaceElevated,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
