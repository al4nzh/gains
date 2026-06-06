import 'package:flutter/material.dart';
import 'package:gains/core/preferences/body_units_preference.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/home/models/home_summary.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';
import 'package:gains/features/home/presentation/widgets/home_week_activity.dart';
import 'package:gains/features/recovery/utils/local_checkin_date.dart';
import 'package:provider/provider.dart';

class HomeStatsSection extends StatelessWidget {
  const HomeStatsSection({
    super.key,
    required this.data,
    required this.weekTrained,
    required this.streakDays,
  });

  final HomeSummary data;
  final List<bool> weekTrained;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: _VolumeStatCard(
                windowDays: data.weeklyVolumeWindowDays,
                volumeKg: data.weeklyVolumeKg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: _StreakCard(
                streakDays: streakDays,
                weekTrained: weekTrained,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ConsistencyCard(consistency: data.workoutConsistency),
      ],
    );
  }
}

class _VolumeStatCard extends StatelessWidget {
  const _VolumeStatCard({
    required this.windowDays,
    required this.volumeKg,
  });

  final int windowDays;
  final double volumeKg;

  @override
  Widget build(BuildContext context) {
    final units = context.watch<BodyUnitsPreference>().units;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${windowDays}d volume',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              formatVolumeKg(volumeKg, units),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.streakDays,
    required this.weekTrained,
  });

  final int streakDays;
  final List<bool> weekTrained;

  @override
  Widget build(BuildContext context) {
    final active = streakDays > 0;
    final flameColor = active ? const Color(0xFFFF6B35) : AppColors.textMuted;
    final days = lastSevenLocalDays();
    final todayKey = LocalCheckinDate.today();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryMuted.withValues(alpha: 0.22),
              AppColors.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: flameColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active
                            ? AppColors.primary.withValues(alpha: 0.45)
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      color: flameColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$streakDays',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: active ? AppColors.textPrimary : AppColors.textSecondary,
                                    height: 1,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              streakDays == 1 ? 'day' : 'days',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        Text(
                          'Workout streak',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final day = days[i];
                  final trained = i < weekTrained.length && weekTrained[i];
                  final isToday = LocalCheckinDate.format(day) == todayKey;
                  return _WeekDayDot(
                    label: weekdayLetter(day),
                    trained: trained,
                    isToday: isToday,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDayDot extends StatelessWidget {
  const _WeekDayDot({
    required this.label,
    required this.trained,
    required this.isToday,
  });

  final String label;
  final bool trained;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: isToday ? 22 : 18,
          height: isToday ? 22 : 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: trained ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: trained
                  ? AppColors.primary
                  : (isToday ? AppColors.primary.withValues(alpha: 0.55) : AppColors.border),
              width: isToday ? 2 : 1.5,
            ),
            boxShadow: trained
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: trained
              ? const Icon(Icons.check, size: 11, color: AppColors.onPrimary)
              : null,
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.consistency});

  final WorkoutConsistency consistency;

  @override
  Widget build(BuildContext context) {
    final avg = consistency.avgPerWeek;
    final total = consistency.completedLast28Days;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: AppColors.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Training rhythm',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                avg.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      height: 1,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'workouts / week',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$total sessions in the last 28 days',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ConsistencyGauge(avgPerWeek: avg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual hint: 0–7 scale mapped to weekly average (caps at 7 for display).
class _ConsistencyGauge extends StatelessWidget {
  const _ConsistencyGauge({required this.avgPerWeek});

  final double avgPerWeek;

  @override
  Widget build(BuildContext context) {
    final fill = (avgPerWeek / 5).clamp(0.0, 1.0);

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: fill,
              strokeWidth: 5,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
              strokeCap: StrokeCap.round,
            ),
          ),
          Icon(
            Icons.calendar_month_outlined,
            size: 20,
            color: AppColors.primary.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }
}
