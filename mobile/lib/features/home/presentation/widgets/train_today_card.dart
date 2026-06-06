import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/home/models/home_summary.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

class TrainTodayCard extends StatelessWidget {
  const TrainTodayCard({super.key, required this.recommendation});

  final TrainTodayRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final rec = recommendation;
    final buttonLabel = switch (rec.action) {
      'resume_workout' => 'Resume ${rec.routineName}',
      'browse_routines' => 'Browse routines',
      _ => 'Start ${rec.routineName}',
    };

    return Card(
      color: AppColors.primaryMuted.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Train next',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              rec.routineName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (rec.reasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Why',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              ...rec.reasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: Icon(Icons.circle, size: 5, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _onPrimaryAction(context, rec),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _onPrimaryAction(BuildContext context, TrainTodayRecommendation rec) {
    switch (rec.action) {
      case 'resume_workout':
        final workoutId = rec.workoutId;
        if (workoutId == null || workoutId.isEmpty) {
          context.push('/train/start');
          return;
        }
        context.push('/train/workout/$workoutId');
      case 'browse_routines':
        context.read<ShellTabRefresh>().bump(ShellTab.routines);
        context.go('/routines');
      case 'start_routine':
        final routineId = rec.routineId;
        if (routineId == null || routineId.isEmpty) {
          context.push('/train/start');
          return;
        }
        context.push('/train/start?routineId=$routineId');
      default:
        context.push('/train/start');
    }
  }
}
