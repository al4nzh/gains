import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/analytics/data/analytics_api.dart';
import 'package:gains/features/analytics/models/exercise_detail.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine_exercise.dart';
import 'package:gains/features/routines/presentation/routine_formatters.dart';
import 'package:gains/features/workouts/data/workout_api.dart';
import 'package:gains/features/workouts/models/workout.dart';
import 'package:gains/features/workouts/presentation/widgets/add_exercise_sheet.dart';
import 'package:gains/features/workouts/presentation/widgets/log_set_slot_row.dart';
import 'package:gains/features/workouts/presentation/workout_plan.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  WorkoutApi? _api;
  Workout? _workout;
  List<WorkoutExercisePlan> _plan = [];
  final Map<String, ({String reps, String weight})> _drafts = {};
  String? _error;
  bool _loading = true;
  bool _finishing = false;

  WorkoutApi get api => _api ??= WorkoutApi(context.read<ApiClient>());

  String _slotKey(String exerciseId, int setNumber) => '$exerciseId:$setNumber';

  void _updateDraft(String exerciseId, int setNumber, String reps, String weight) {
    final key = _slotKey(exerciseId, setNumber);
    final hasReps = reps.trim().isNotEmpty;
    final hasWeight = weight.trim().isNotEmpty;
    if (!hasReps && !hasWeight) {
      if (_drafts.remove(key) != null) setState(() {});
      return;
    }
    final next = (reps: reps, weight: weight);
    final prev = _drafts[key];
    if (prev?.reps == next.reps && prev?.weight == next.weight) return;
    setState(() => _drafts[key] = next);
  }

  void _clearDraft(String exerciseId, int setNumber) {
    if (_drafts.remove(_slotKey(exerciseId, setNumber)) != null) {
      setState(() {});
    }
  }

  void _onSetChanged(String exerciseId, int setNumber) {
    _clearDraft(exerciseId, setNumber);
    _load(silent: true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final client = context.read<ApiClient>();
      final workoutApi = WorkoutApi(client);
      final workout = await workoutApi.getWorkout(widget.workoutId);
      if (!mounted) return;
      if (!workout.isInProgress) {
        context.pushReplacement('/train/workout/${widget.workoutId}/summary');
        return;
      }

      List<RoutineExercise>? routineExercises;
      if (workout.routineId != null) {
        final routine = await RoutineApi(client).getRoutine(workout.routineId!);
        routineExercises = routine.exercises;
      }

      final exerciseIds = <String>{
        ...?routineExercises?.map((e) => e.exerciseId),
        ...workout.sets.map((s) => s.exerciseId),
      };

      final prefills = exerciseIds.isEmpty
          ? <String, SetLoadSummary?>{}
          : await AnalyticsApi(client).lastBestSetsForExercises(exerciseIds);

      final plan = buildWorkoutPlan(
        routineExercises: routineExercises,
        loggedSets: workout.sets,
        prefills: prefills,
      );

      if (!mounted) return;
      setState(() {
        _workout = workout;
        _plan = plan;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load workout';
        _loading = false;
      });
    }
  }

  Future<void> _addExercise() async {
    final added = await AddExerciseSheet.show(context, widget.workoutId);
    if (added == true) _load();
  }

  Future<void> _finish() async {
    final w = _workout;
    if (w == null || _finishing) return;

    if (w.sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log at least one set before finishing')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish workout?'),
        content: const Text('This will save your session and update stats.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finish')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _finishing = true);
    try {
      final stats = await api.finishWorkout(widget.workoutId);
      if (!mounted) return;
      context.read<ShellTabRefresh>().bumpMany([ShellTab.home, ShellTab.train, ShellTab.progress]);
      context.pushReplacement(
        '/train/workout/${widget.workoutId}/summary',
        extra: stats,
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _workout;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) context.read<ShellTabRefresh>().bump(ShellTab.train);
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(w?.displayName ?? 'Workout'),
        actions: [
          if (w != null && w.isInProgress)
            TextButton(
              onPressed: _finishing ? null : _finish,
              child: _finishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Finish'),
            ),
        ],
      ),
      floatingActionButton: w != null && w.isInProgress
          ? FloatingActionButton.extended(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            )
          : null,
      body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _workout == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _workout == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_plan.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No exercises yet.\nTap Add exercise to start logging.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        for (final exercise in _plan) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (exercise.targetRepMin != null || exercise.targetRepMax != null)
                  Text(
                    formatRepRange(exercise.targetRepMin, exercise.targetRepMax),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                if (exercise.lastBestSet != null && exercise.lastBestSet!.hasValues)
                  Text(
                    formatLastBestSet(exercise.lastBestSet),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary),
                  ),
              ],
            ),
          ),
          for (final slot in exercise.slots)
            LogSetSlotRow(
              key: ValueKey('${exercise.exerciseId}-${slot.setNumber}'),
              workoutId: widget.workoutId,
              exerciseId: exercise.exerciseId,
              exerciseName: exercise.exerciseName,
              setNumber: slot.setNumber,
              logged: slot.logged,
              prefill: slot.prefill,
              draftReps: _drafts[_slotKey(exercise.exerciseId, slot.setNumber)]?.reps,
              draftWeight: _drafts[_slotKey(exercise.exerciseId, slot.setNumber)]?.weight,
              onDraftChanged: (reps, weight) => _updateDraft(
                exercise.exerciseId,
                slot.setNumber,
                reps,
                weight,
              ),
              onChanged: () => _onSetChanged(exercise.exerciseId, slot.setNumber),
            ),
        ],
      ],
    );
  }
}
