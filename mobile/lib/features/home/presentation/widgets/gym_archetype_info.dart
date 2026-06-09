import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/profile/models/gym_archetype.dart';

/// All gym archetypes (mirrors server catalog).
class GymArchetypeCatalogEntry {
  const GymArchetypeCatalogEntry({
    required this.id,
    required this.label,
    required this.tagline,
    required this.hint,
  });

  final String id;
  final String label;
  final String tagline;
  final String hint;
}

const gymArchetypeCatalog = <GymArchetypeCatalogEntry>[
  GymArchetypeCatalogEntry(
    id: 'back_day_demon',
    label: 'Back Day Demon',
    tagline: 'Every day is pull day if you believe hard enough.',
    hint: 'High back volume and lots of pull-focused sessions.',
  ),
  GymArchetypeCatalogEntry(
    id: 'bench_merchant',
    label: 'Bench Merchant',
    tagline: 'The barbell bench is your personality trait.',
    hint: 'Chest-heavy training with plenty of bench work.',
  ),
  GymArchetypeCatalogEntry(
    id: 'pr_goblin',
    label: 'PR Goblin',
    tagline: 'You smell a new max from three racks away.',
    hint: 'Frequent personal records across your workouts.',
  ),
  GymArchetypeCatalogEntry(
    id: 'leg_day_fugitive',
    label: 'Leg Day Fugitive',
    tagline: 'Legs are optional. Allegedly.',
    hint: 'Upper-body bias with very little leg volume.',
  ),
  GymArchetypeCatalogEntry(
    id: 'powerbuilder',
    label: 'Powerbuilder',
    tagline: 'Heavy compounds, then more reps. Both.',
    hint: 'Big barbell lifts with a mix of heavy and higher-rep work.',
  ),
  GymArchetypeCatalogEntry(
    id: 'aesthetic_merchant',
    label: 'Aesthetic Merchant',
    tagline: 'Mirror muscles are a legitimate asset class.',
    hint: 'Lots of arms, shoulders, chest, and isolation work.',
  ),
  GymArchetypeCatalogEntry(
    id: 'comeback_arc',
    label: 'Comeback Arc',
    tagline: "You took a break. Now you're back on the plot.",
    hint: 'Returned after a long gap with recent momentum.',
  ),
  GymArchetypeCatalogEntry(
    id: 'consistency_demon',
    label: 'Consistency Demon',
    tagline: 'You just keep showing up. Unhinged.',
    hint: 'Steady weekly frequency and active streaks.',
  ),
];

void showGymArchetypeInfoSheet(BuildContext context, {GymArchetype? archetype}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: _GymArchetypeInfoContent(archetype: archetype),
      ),
    ),
  );
}

class _GymArchetypeInfoContent extends StatelessWidget {
  const _GymArchetypeInfoContent({this.archetype});

  final GymArchetype? archetype;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.45,
        );
    final title = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );

    final primaryId = archetype?.primaryArchetype;
    final secondaryId = archetype?.secondaryTrait;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Gym archetype', style: title)),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              color: AppColors.textMuted,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'A memeable training identity based on your real workout logs — not random AI. '
          'We score how you actually train and pick the best match.',
          style: body,
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'How it works',
          children: [
            Text(
              'After you finish at least 3 workouts, Gains analyzes your recent sessions: '
              'muscle groups, exercise mix, PR rate, consistency, and session patterns.',
              style: body,
            ),
            const SizedBox(height: 8),
            Text(
              'Each archetype earns points from your data. Your highest score becomes your '
              'primary archetype. If a second type scores close enough, it shows as a secondary trait.',
              style: body,
            ),
          ],
        ),
        if (archetype != null && archetype!.unlocked) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Your result',
            children: [
              Text(
                'Primary: ${archetype!.primaryLabel ?? '—'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (archetype!.secondaryLabel != null && archetype!.secondaryLabel!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Secondary trait: ${archetype!.secondaryLabel}',
                  style: body,
                ),
              ],
            ],
          ),
        ] else if (archetype != null) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Locked',
            children: [
              Text(
                'You have ${archetype!.workoutsCompleted} of ${archetype!.workoutsRequired} '
                'workouts needed to unlock your archetype.',
                style: body,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'All archetypes',
          children: [
            Text(
              'Any of these can become your primary or secondary trait depending on how you train:',
              style: body,
            ),
            const SizedBox(height: 12),
            for (final entry in gymArchetypeCatalog)
              _ArchetypeListTile(
                entry: entry,
                isPrimary: entry.id == primaryId,
                isSecondary: entry.id == secondaryId,
              ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

class _ArchetypeListTile extends StatelessWidget {
  const _ArchetypeListTile({
    required this.entry,
    required this.isPrimary,
    required this.isSecondary,
  });

  final GymArchetypeCatalogEntry entry;
  final bool isPrimary;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    final highlighted = isPrimary || isSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.primaryMuted.withValues(alpha: 0.12) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
                if (isPrimary)
                  _Badge(label: 'You', color: AppColors.primary),
                if (isSecondary)
                  Padding(
                    padding: EdgeInsets.only(left: isPrimary ? 6 : 0),
                    child: _Badge(label: 'Trait', color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.tagline,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
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
