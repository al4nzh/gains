import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/home/presentation/widgets/gym_archetype_info.dart';
import 'package:gains/features/home/presentation/widgets/share_gains_identity.dart';
import 'package:gains/features/profile/models/gym_archetype.dart';
import 'package:gains/features/subscription/presentation/paywall_sheet.dart';

class GymArchetypeCard extends StatefulWidget {
  const GymArchetypeCard({
    super.key,
    required this.archetype,
    required this.isPremium,
    this.strengthElo,
    this.strengthEloRank,
  });

  final GymArchetype archetype;
  final bool isPremium;
  final int? strengthElo;
  final String? strengthEloRank;

  @override
  State<GymArchetypeCard> createState() => _GymArchetypeCardState();
}

class _GymArchetypeCardState extends State<GymArchetypeCard> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing || !widget.archetype.unlocked) return;
    setState(() => _sharing = true);
    try {
      await shareGainsIdentity(
        context,
        archetype: widget.archetype,
        strengthElo: widget.strengthElo,
        strengthEloRank: widget.strengthEloRank,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final archetype = widget.archetype;
    final theme = Theme.of(context);

    if (!widget.isPremium) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.workspace_premium_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gains Identity', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Unlock your gym archetype and shareable identity card with Premium.',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => showPaywallSheet(context),
                      child: const Text('Upgrade to Premium'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!archetype.unlocked) {
      final remaining = (archetype.workoutsRequired - archetype.workoutsCompleted).clamp(0, 99);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: AppColors.textSecondary.withValues(alpha: 0.8)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Gains Identity', style: theme.textTheme.titleSmall),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'About gym archetypes',
                          onPressed: () => showGymArchetypeInfoSheet(context, archetype: archetype),
                          icon: const Icon(Icons.info_outline, size: 20),
                          color: AppColors.textMuted,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remaining == 1
                          ? 'Finish 1 more workout to unlock your Gains Identity.'
                          : 'Finish $remaining more workouts to unlock your Gains Identity.',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final label = archetype.primaryLabel ?? 'Gains Identity';
    final tagline = archetype.primaryTagline;
    final secondary = archetype.secondaryLabel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'GAINS IDENTITY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Share identity card',
                  onPressed: _sharing ? null : _share,
                  icon: _sharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share, size: 20),
                  color: AppColors.textMuted,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  tooltip: 'About gym archetypes',
                  onPressed: () => showGymArchetypeInfoSheet(context, archetype: archetype),
                  icon: const Icon(Icons.info_outline, size: 20),
                  color: AppColors.textMuted,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (tagline != null && tagline.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                tagline,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (secondary != null && secondary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Secondary trait · $secondary',
                  style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
