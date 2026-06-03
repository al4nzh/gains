import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';

/// Rank thresholds — keep in sync with [internal/strength/bwelo.go] RankLabel.
abstract final class EloRankTiers {
  static const iron = _Tier('iron', 100, 820);
  static const bronze = _Tier('bronze', 820, 980);
  static const silver = _Tier('silver', 980, 1140);
  static const gold = _Tier('gold', 1140, 1320);
  static const platinum = _Tier('platinum', 1320, 3600);

  static const all = [iron, bronze, silver, gold, platinum];

  static _Tier tierForElo(int elo) {
    for (final t in all.reversed) {
      if (elo >= t.min) return t;
    }
    return iron;
  }

  static _Tier? nextTierAfter(String? rankKey) {
    if (rankKey == null) return iron;
    final idx = all.indexWhere((t) => t.key == rankKey);
    if (idx < 0 || idx >= all.length - 1) return null;
    return all[idx + 1];
  }

  /// Human-readable Elo band for info UI (max is exclusive in [RankLabel]).
  static String eloRangeLabel(_Tier tier) {
    final name = humanizeSnake(tier.key);
    if (tier.key == 'platinum') {
      return '$name · ${tier.min}+';
    }
    return '$name · ${tier.min}–${tier.max - 1}';
  }
}

class _Tier {
  const _Tier(this.key, this.min, this.max);
  final String key;
  final int min;
  final int max;
}

Color eloRankColor(String? rankKey) {
  switch (rankKey) {
    case 'bronze':
      return const Color(0xFFCD7F32);
    case 'silver':
      return const Color(0xFFC0C0C8);
    case 'gold':
      return const Color(0xFFEAB308);
    case 'platinum':
      return AppColors.primary;
    case 'iron':
    default:
      return AppColors.textMuted;
  }
}

/// Right-side visual: rank badge; lower tiers show progress to the next rank.
class EloRankVisual extends StatelessWidget {
  const EloRankVisual({
    super.key,
    required this.elo,
    this.rankKey,
    this.percentile,
  });

  final int? elo;
  final String? rankKey;
  final int? percentile;

  @override
  Widget build(BuildContext context) {
    if (elo == null) {
      return const _LockedRankLadder();
    }

    final tier = EloRankTiers.tierForElo(elo!);
    final rank = rankKey ?? tier.key;
    final color = eloRankColor(rank);
    final isPlatinum = rank == 'platinum';

    if (isPlatinum) {
      return _PlatinumBadge(color: color, percentile: percentile);
    }

    final next = EloRankTiers.nextTierAfter(rank)!;
    final progress = _progressToNextTier(elo!, tier);
    final ptsToNext = (next.min - elo!).clamp(0, 9999);

    return SizedBox(
      width: 108,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: AppColors.border,
                    color: color,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                _RankCenterBadge(
                  label: _rankInitial(rank),
                  color: color,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            humanizeSnake(rank),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          if (percentile != null) ...[
            const SizedBox(height: 2),
            _EloPercentileCaption(percentile: percentile!),
          ],
          const SizedBox(height: 2),
          Text(
            '$ptsToNext to ${humanizeSnake(next.key)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Progress from current Elo toward the next tier's minimum (not used for Platinum).
  double _progressToNextTier(int elo, _Tier tier) {
    final span = tier.max - tier.min;
    if (span <= 0) return 0;
    return ((elo - tier.min) / span).clamp(0.08, 1.0);
  }

  String _rankInitial(String rank) {
    final label = humanizeSnake(rank);
    return label.isNotEmpty ? label[0].toUpperCase() : '?';
  }
}

class _EloPercentileCaption extends StatelessWidget {
  const _EloPercentileCaption({required this.percentile});

  final int percentile;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatStrengthPercentile(percentile),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
      textAlign: TextAlign.center,
    );
  }
}

/// Max rank — no “next tier” ring; solid badge instead.
class _PlatinumBadge extends StatelessWidget {
  const _PlatinumBadge({required this.color, this.percentile});

  final Color color;
  final int? percentile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.55), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 36,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Platinum',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          if (percentile != null)
            _EloPercentileCaption(percentile: percentile!)
          else
            Text(
              'Top tier · 1,320+',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _RankCenterBadge extends StatelessWidget {
  const _RankCenterBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

class _LockedRankLadder extends StatelessWidget {
  const _LockedRankLadder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < EloRankTiers.all.length; i++) ...[
            if (i > 0)
              Container(
                width: 2,
                height: 6,
                color: AppColors.border,
              ),
            _LadderDot(
              label: humanizeSnake(EloRankTiers.all[i].key),
              color: eloRankColor(EloRankTiers.all[i].key),
              dimmed: true,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Unlock with\nbenchmark lifts',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  height: 1.3,
                ),
          ),
        ],
      ),
    );
  }
}

class _LadderDot extends StatelessWidget {
  const _LadderDot({
    required this.label,
    required this.color,
    this.dimmed = false,
  });

  final String label;
  final Color color;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = dimmed ? color.withValues(alpha: 0.35) : color;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: dimmed ? AppColors.textMuted : c,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}
