import 'package:flutter/material.dart';
import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/analytics/presentation/analytics_formatters.dart';
import 'package:gains/features/analytics/models/exercise_detail.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';
import 'package:gains/features/workouts/models/finish_stats.dart';
import 'package:gains/features/workouts/models/workout_set.dart';
import 'package:gains/features/workouts/presentation/widgets/session_muscles_diagram.dart';

/// Best set per exercise for the share card (from logged workout sets).
class ShareSessionBestSet {
  const ShareSessionBestSet({
    required this.exerciseId,
    required this.exerciseName,
    required this.reps,
    required this.weightKg,
    required this.bestE1rmKg,
  });

  final String exerciseId;
  final String exerciseName;
  final int reps;
  final double weightKg;
  final double bestE1rmKg;

  String get setLabel => formatSetLoad(SetLoadSummary(reps: reps, weightKg: weightKg));
}

/// Brzycki e1RM — keep in sync with server [strength.Estimate1RMBrzycki].
double shareEstimateE1rmKg(double weightKg, int reps) {
  if (reps <= 0 || weightKg <= 0) return 0;
  if (reps == 1) return weightKg;
  return weightKg * (36 / (37 - reps));
}

List<ShareSessionBestSet> shareBestSetsFromLoggedSets(List<WorkoutSet> sets) {
  final byExercise = <String, ShareSessionBestSet>{};
  for (final s in sets) {
    if (s.reps <= 0 || s.weightKg <= 0) continue;
    final e1 = shareEstimateE1rmKg(s.weightKg, s.reps);
    if (e1 <= 0) continue;
    final prev = byExercise[s.exerciseId];
    if (prev == null || e1 > prev.bestE1rmKg) {
      byExercise[s.exerciseId] = ShareSessionBestSet(
        exerciseId: s.exerciseId,
        exerciseName: s.exerciseName,
        reps: s.reps,
        weightKg: s.weightKg,
        bestE1rmKg: e1,
      );
    }
  }
  return byExercise.values.toList()..sort((a, b) => b.bestE1rmKg.compareTo(a.bestE1rmKg));
}

/// Fixed 9:16 story layout for Instagram / share sheet.
class WorkoutShareCard extends StatelessWidget {
  const WorkoutShareCard({
    super.key,
    required this.workoutTitle,
    required this.stats,
    required this.sessionBests,
    this.aiOneLiner,
    this.highlightedMuscles = const {},
    this.trainedGroupLabels = const [],
  });

  final String workoutTitle;
  final FinishStats stats;
  final List<ShareSessionBestSet> sessionBests;
  final String? aiOneLiner;
  final Set<Muscle> highlightedMuscles;
  final List<String> trainedGroupLabels;

  static const width = 360.0;
  static const height = 640.0;

  static const _maxLifts = 5;
  static const _maxMuscleLabels = 6;

  @override
  Widget build(BuildContext context) {
    final bestByExercise = {for (final s in sessionBests) s.exerciseId: s};
    final prs = stats.prs;
    final prExerciseIds = prs.map((p) => p.exerciseId).toSet();
    final otherLifts = sessionBests.where((s) => !prExerciseIds.contains(s.exerciseId)).take(_maxLifts).toList();
    final otherOverflow = sessionBests.where((s) => !prExerciseIds.contains(s.exerciseId)).length - otherLifts.length;
    final muscleLabels = trainedGroupLabels.take(_maxMuscleLabels).toList();
    final muscleOverflow = trainedGroupLabels.length - muscleLabels.length;
    final showMuscles = highlightedMuscles.isNotEmpty || muscleLabels.isNotEmpty;
    final showAi = aiOneLiner != null && aiOneLiner!.trim().isNotEmpty;

    String setLabelFor(String exerciseId) {
      final best = bestByExercise[exerciseId];
      if (best != null) return best.setLabel;
      return '—';
    }

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0C0C0E),
              Color(0xFF141418),
              Color(0xFF1A0A10),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, showAi ? 36 : 44, 24, showAi ? 24 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'GAINS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                workoutTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ShareStatChip(
                      label: 'Volume',
                      value: formatVolumeKg(stats.totalVolumeKg),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ShareStatChip(
                      label: 'Duration',
                      value: formatDuration(stats.durationSeconds),
                    ),
                  ),
                ],
              ),
              if (prs.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _ShareSectionTitle(icon: Icons.emoji_events_outlined, label: 'PRs'),
                const SizedBox(height: 8),
                for (final pr in prs)
                  _ShareLineRow(
                    left: pr.exerciseName,
                    right: setLabelFor(pr.exerciseId),
                    accent: true,
                  ),
              ],
              if (otherLifts.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _ShareSectionTitle(icon: Icons.fitness_center, label: 'Session bests'),
                const SizedBox(height: 8),
                for (final lift in otherLifts)
                  _ShareLineRow(
                    left: lift.exerciseName,
                    right: lift.setLabel,
                  ),
                if (otherOverflow > 0)
                  _ShareOverflowText('+$otherOverflow more exercise${otherOverflow == 1 ? '' : 's'}'),
              ],
              if (showMuscles) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (highlightedMuscles.isNotEmpty)
                      MuscleMiniDiagramPair(
                        highlightedMuscles: highlightedMuscles,
                        viewSize: 84,
                        gap: 6,
                      ),
                    if (highlightedMuscles.isNotEmpty && muscleLabels.isNotEmpty)
                      const SizedBox(width: 14),
                    if (muscleLabels.isNotEmpty)
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final label in muscleLabels)
                              _ShareMuscleChip(label: label),
                            if (muscleOverflow > 0)
                              _ShareMuscleChip(label: '+$muscleOverflow'),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (showAi) ...[
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          aiOneLiner!.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else
                const Spacer(),
              Text(
                'gainsai.net',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  color: AppColors.textMuted.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareSectionTitle extends StatelessWidget {
  const _ShareSectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _ShareStatChip extends StatelessWidget {
  const _ShareStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareLineRow extends StatelessWidget {
  const _ShareLineRow({
    required this.left,
    required this.right,
    this.accent = false,
  });

  final String left;
  final String right;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: accent ? FontWeight.w700 : FontWeight.w600,
                color: accent ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            right,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accent ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareOverflowText extends StatelessWidget {
  const _ShareOverflowText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
      ),
    );
  }
}

class _ShareMuscleChip extends StatelessWidget {
  const _ShareMuscleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
