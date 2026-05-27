import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine.dart';
import 'package:gains/features/workouts/presentation/muscle_group_mapping.dart';
import 'package:gains/features/workouts/presentation/widgets/session_muscles_diagram.dart';

/// Front + back muscle highlights for a routine (list card).
class RoutineMusclesMiniDiagram extends StatefulWidget {
  const RoutineMusclesMiniDiagram({
    super.key,
    required this.routineId,
    required this.routineApi,
    required this.exerciseIdToMuscleGroup,
    this.viewSize = 56,
  });

  final String routineId;
  final RoutineApi routineApi;
  final Map<String, String> exerciseIdToMuscleGroup;
  final double viewSize;

  @override
  State<RoutineMusclesMiniDiagram> createState() => _RoutineMusclesMiniDiagramState();
}

class _RoutineMusclesMiniDiagramState extends State<RoutineMusclesMiniDiagram> {
  late Future<Routine> _routineFuture;

  @override
  void initState() {
    super.initState();
    _routineFuture = widget.routineApi.getRoutine(widget.routineId);
  }

  @override
  void didUpdateWidget(covariant RoutineMusclesMiniDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routineId != widget.routineId) {
      _routineFuture = widget.routineApi.getRoutine(widget.routineId);
    }
  }

  double get _totalWidth => widget.viewSize * 2 + 6;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Routine>(
      future: _routineFuture,
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

        final routine = snapshot.data!;
        final exerciseIds = routine.exercises.map((e) => e.exerciseId).toSet();
        final highlighted = highlightedMusclesForExerciseIds(
          exerciseIds: exerciseIds,
          exerciseIdToMuscleGroup: widget.exerciseIdToMuscleGroup,
        );

        return MuscleMiniDiagramPair(
          highlightedMuscles: highlighted,
          viewSize: widget.viewSize,
        );
      },
    );
  }
}
