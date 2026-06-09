import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';

/// Fixed 9:16 story layout for Instagram / share sheet.
class GainsIdentityShareCard extends StatelessWidget {
  const GainsIdentityShareCard({
    super.key,
    required this.primaryLabel,
    this.secondaryLabel,
    this.description,
    this.strengthElo,
    this.strengthEloRank,
  });

  final String primaryLabel;
  final String? secondaryLabel;
  final String? description;
  final int? strengthElo;
  final String? strengthEloRank;

  static const width = 360.0;
  static const height = 640.0;

  @override
  Widget build(BuildContext context) {
    final hasSecondary = secondaryLabel != null && secondaryLabel!.trim().isNotEmpty;
    final desc = description?.trim();
    final hasDesc = desc != null && desc.isNotEmpty;
    final rankLabel = _formatRank(strengthEloRank);

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
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'GAINS IDENTITY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 36),
              Text(
                primaryLabel.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              if (hasSecondary) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
                  ),
                  child: Text(
                    'Secondary trait: $secondaryLabel',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _IdentityStatRow(
                label: 'Strength Elo',
                value: strengthElo?.toString() ?? '—',
                highlight: strengthElo != null,
              ),
              if (rankLabel != null) ...[
                const SizedBox(height: 10),
                _IdentityStatRow(
                  label: 'Rank',
                  value: rankLabel,
                  highlight: true,
                ),
              ],
              if (hasDesc) ...[
                const SizedBox(height: 24),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const Spacer(),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 20),
              const Text(
                'Made with Gains',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Find your Gym Archetype',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'gainsai.net',
                textAlign: TextAlign.center,
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

  static String? _formatRank(String? rank) {
    final raw = rank?.trim();
    if (raw == null || raw.isEmpty) return null;
    return humanizeSnake(raw);
  }
}

class _IdentityStatRow extends StatelessWidget {
  const _IdentityStatRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
