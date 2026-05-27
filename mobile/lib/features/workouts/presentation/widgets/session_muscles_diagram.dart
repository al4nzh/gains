import 'package:flutter/material.dart';
import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';

/// Front + back body diagram with muscles worked highlighted (read-only).
class SessionMusclesDiagram extends StatelessWidget {
  const SessionMusclesDiagram({
    super.key,
    this.title = 'Muscles trained this session',
    required this.highlightedMuscles,
    this.trainedGroupLabels = const [],
  });

  final String title;
  final Set<Muscle> highlightedMuscles;
  final List<String> trainedGroupLabels;

  static const _diagramHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _BodyViewPanel(
                      label: 'Front',
                      isFront: true,
                      highlightedMuscles: highlightedMuscles,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _BodyViewPanel(
                      label: 'Back',
                      isFront: false,
                      highlightedMuscles: highlightedMuscles,
                    )),
                  ],
                ),
                if (trainedGroupLabels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: trainedGroupLabels.map((g) {
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
                            color: AppColors.primary.withValues(alpha: 0.85),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ] else if (highlightedMuscles.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Muscle groups unavailable.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tiny read-only muscle diagram for list cards.
class MuscleMiniDiagram extends StatelessWidget {
  const MuscleMiniDiagram({
    super.key,
    required this.highlightedMuscles,
    this.isFront = true,
    this.size = 44,
  });

  final Set<Muscle> highlightedMuscles;
  final bool isFront;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: InteractiveBodySvg(
        isFront: isFront,
        selectedMuscles: highlightedMuscles,
        enableSelection: false,
        highlightColor: AppColors.primary.withValues(alpha: 0.82),
        disabledColor: AppColors.border.withValues(alpha: 0.35),
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Front + back mini diagrams for routine list cards.
class MuscleMiniDiagramPair extends StatelessWidget {
  const MuscleMiniDiagramPair({
    super.key,
    required this.highlightedMuscles,
    this.viewSize = 56,
    this.gap = 6,
  });

  final Set<Muscle> highlightedMuscles;
  final double viewSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MuscleMiniDiagram(
          highlightedMuscles: highlightedMuscles,
          isFront: true,
          size: viewSize,
        ),
        SizedBox(width: gap),
        MuscleMiniDiagram(
          highlightedMuscles: highlightedMuscles,
          isFront: false,
          size: viewSize,
        ),
      ],
    );
  }
}

class _BodyViewPanel extends StatelessWidget {
  const _BodyViewPanel({
    required this.label,
    required this.isFront,
    required this.highlightedMuscles,
  });

  final String label;
  final bool isFront;
  final Set<Muscle> highlightedMuscles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: SessionMusclesDiagram._diagramHeight,
          child: InteractiveBodySvg(
            isFront: isFront,
            selectedMuscles: highlightedMuscles,
            enableSelection: false,
            highlightColor: AppColors.primary.withValues(alpha: 0.82),
            disabledColor: AppColors.border.withValues(alpha: 0.35),
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

List<String> trainedGroupLabelsFromIds(
  Set<String> rawGroups,
) {
  final labels = rawGroups.map(humanizeSnake).toList()..sort();
  return labels;
}
