import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/workouts/models/workout.dart';
import 'package:gains/features/workouts/presentation/train_workout_helpers.dart';

class TrainHistoryTile extends StatelessWidget {
  const TrainHistoryTile({
    super.key,
    required this.workout,
    required this.routineNames,
    required this.muscleGroups,
    required this.onTap,
  });

  final Workout workout;
  final Map<String, String> routineNames;
  final List<String> muscleGroups;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPr = workoutHadPr(workout);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: hasPr
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.45),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    workout.displayNameFor(routineNames),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (hasPr) const _PrBadge(),
                              ],
                            ),
                            if (muscleGroups.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _MuscleGroupChips(groups: muscleGroups),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              workoutSessionSubtitle(workout),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrBadge extends StatelessWidget {
  const _PrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏆', style: TextStyle(fontSize: 11, height: 1.1)),
          SizedBox(width: 3),
          Text(
            'PR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleGroupChips extends StatelessWidget {
  const _MuscleGroupChips({required this.groups});

  final List<String> groups;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: groups.map((g) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            g,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.primary.withValues(alpha: 0.72),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class TrainDateSectionHeader extends StatelessWidget {
  const TrainDateSectionHeader({required this.title, this.isToday = false});

  final String title;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
              color: isToday ? AppColors.textPrimary : AppColors.textSecondary,
            ),
      ),
    );
  }
}
