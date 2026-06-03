import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/home/presentation/widgets/elo_rank_visual.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';

/// Bottom sheet explaining Strength Elo on Home.
void showStrengthEloInfoSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: _StrengthEloInfoContent(),
      ),
    ),
  );
}

class _StrengthEloInfoContent extends StatelessWidget {
  const _StrengthEloInfoContent();

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.45,
        );
    final title = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Strength Elo', style: title),
        const SizedBox(height: 12),
        Text(
          'A single strength rating (like chess Elo) based on how strong you are '
          'for your bodyweight — not just how much weight is on the bar.',
          style: body,
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Benchmark lifts',
          children: [
            Text(
              'Only these main barbell lifts count toward Strength Elo:',
              style: body,
            ),
            const SizedBox(height: 10),
            const _BenchmarkLiftList(),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'How it updates',
          children: [
            Text(
              'After you finish a workout with at least one of those benchmark lifts, '
              'we compare your best estimated 1-rep maxes to your profile bodyweight '
              'and adjust your score.',
              style: body,
            ),
            const SizedBox(height: 8),
            Text(
              'You need bodyweight on your profile and at least two different benchmark '
              'lifts logged over time before Elo can appear or change. Other exercises '
              '(curls, machines, etc.) do not affect Elo.',
              style: body,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Ranks',
          children: [
            Text(
              'Your tier is based on your current Strength Elo score:',
              style: body,
            ),
            const SizedBox(height: 10),
            const _RankThresholdList(),
            const SizedBox(height: 8),
            Text(
              'Ratings are capped at 3600. On Home, the ring shows how close you are to the next rank (not used at Platinum — that is the highest tier).',
              style: body,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Percentile',
          children: [
            Text(
              'When enough lifters on Gains have a Strength Elo, Home shows how you '
              'compare — e.g. “72nd percentile” or “Top 12%”. It counts only people with '
              'an unlocked rating, not everyone on the app.',
              style: body,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: '30-day change',
          children: [
            Text(
              'The green or red number under your score is how many Elo points '
              'you gained or lost in the last 30 days from completed benchmark sessions.',
              style: body,
            ),
          ],
        ),
      ],
    );
  }
}

class _RankThresholdList extends StatelessWidget {
  const _RankThresholdList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tier in EloRankTiers.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: eloRankColor(tier.key).withValues(alpha: 0.12),
                    border: Border.all(
                      color: eloRankColor(tier.key).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    humanizeSnake(tier.key)[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: eloRankColor(tier.key),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    EloRankTiers.eloRangeLabel(tier),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BenchmarkLiftList extends StatelessWidget {
  const _BenchmarkLiftList();

  static const _lifts = [
    'Bench press',
    'Squat',
    'Deadlift',
    'OHP (overhead press)',
    'Barbell row',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final name in _lifts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }
}
