import 'package:flutter/material.dart';
import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/workouts/presentation/muscle_group_mapping.dart';
import 'package:gains/features/workouts/presentation/widgets/session_muscles_diagram.dart';

/// Front + back muscle highlights for a routine template (list card).
class TemplateMusclesMiniDiagram extends StatefulWidget {
  const TemplateMusclesMiniDiagram({
    super.key,
    required this.templateId,
    required this.routineApi,
    required this.exerciseIdToMuscleGroup,
    this.viewSize = 56,
  });

  final String templateId;
  final RoutineApi routineApi;
  final Map<String, String> exerciseIdToMuscleGroup;
  final double viewSize;

  @override
  State<TemplateMusclesMiniDiagram> createState() => _TemplateMusclesMiniDiagramState();
}

class _TemplateMusclesMiniDiagramState extends State<TemplateMusclesMiniDiagram> {
  late Future<Set<Muscle>> _highlightedFuture;

  @override
  void initState() {
    super.initState();
    _highlightedFuture = _loadHighlighted();
  }

  @override
  void didUpdateWidget(covariant TemplateMusclesMiniDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.templateId != widget.templateId ||
        oldWidget.exerciseIdToMuscleGroup != widget.exerciseIdToMuscleGroup) {
      _highlightedFuture = _loadHighlighted();
    }
  }

  Future<Set<Muscle>> _loadHighlighted() async {
    final template = await widget.routineApi.getTemplate(widget.templateId);
    final exerciseIds = template.exercises.map((e) => e.exerciseId).toSet();
    return highlightedMusclesForExerciseIds(
      exerciseIds: exerciseIds,
      exerciseIdToMuscleGroup: widget.exerciseIdToMuscleGroup,
    );
  }

  double get _totalWidth => widget.viewSize * 2 + 6;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<Muscle>>(
      future: _highlightedFuture,
      builder: (context, snapshot) {
        final hasData = snapshot.connectionState == ConnectionState.done && snapshot.hasData;
        if (!hasData) {
          return SizedBox(
            width: _totalWidth,
            height: widget.viewSize,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        }

        return MuscleMiniDiagramPair(
          highlightedMuscles: snapshot.data!,
          viewSize: widget.viewSize,
        );
      },
    );
  }
}
