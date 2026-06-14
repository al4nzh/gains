import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/features/adaptive_recommendations/data/adaptive_recommendations_api.dart';
import 'package:gains/features/adaptive_recommendations/models/adaptive_recommendation.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/exercises/data/exercise_api.dart';
import 'package:gains/features/exercises/presentation/widgets/exercise_gif_thumbnail.dart';
import 'package:gains/features/routines/models/routine.dart';
import 'package:gains/features/routines/models/routine_exercise.dart';
import 'package:gains/features/workouts/data/workout_api.dart';
import 'package:gains/features/workouts/models/workout.dart';
import 'package:gains/features/workouts/presentation/widgets/active_workout_dialogs.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:gains/features/subscription/presentation/premium_teaser_card.dart';
import 'package:gains/features/subscription/services/subscription_service.dart';
import 'package:gains/features/subscription/utils/premium_errors.dart';
import 'package:provider/provider.dart';

class StartWorkoutScreen extends StatefulWidget {
  const StartWorkoutScreen({super.key, this.routineId});

  final String? routineId;

  @override
  State<StartWorkoutScreen> createState() => _StartWorkoutScreenState();
}

class _StartWorkoutScreenState extends State<StartWorkoutScreen> {
  final _name = TextEditingController();

  List<RoutineSummary> _routines = [];
  String? _selectedRoutineId;
  bool _loadingRoutines = true;
  bool _starting = false;
  String? _error;

  late final WorkoutApi _workoutApi;
  late final RoutineApi _routineApi;
  late final AdaptiveRecommendationsApi _adaptiveApi;
  late final ExerciseApi _exerciseApi;

  Routine? _selectedRoutine;
  Map<String, String> _gifsByExerciseId = {};
  bool _loadingPreview = false;

  AdaptiveRecommendationsResponse? _adaptive;
  bool _loadingAdaptive = false;
  bool _ignoredAdaptive = false;
  String? _adaptiveError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = context.read<ApiClient>();
    _workoutApi = WorkoutApi(client);
    _routineApi = RoutineApi(client);
    _adaptiveApi = AdaptiveRecommendationsApi(client);
    _exerciseApi = ExerciseApi(client);
  }

  @override
  void initState() {
    super.initState();
    _selectedRoutineId = widget.routineId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoutines());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoutinePreview());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadRoutines() async {
    try {
      final list = await _routineApi.listRoutines();
      if (!mounted) return;
      setState(() {
        _routines = list;
        _loadingRoutines = false;
        if (_selectedRoutineId != null &&
            !list.any((r) => r.id == _selectedRoutineId)) {
          _selectedRoutineId = null;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingRoutines = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRoutines = false);
    }
  }

  Future<void> _loadRoutinePreview() async {
    final routineId = _selectedRoutineId;
    final isPremium = context.read<SubscriptionService>().isPremium;
    if (routineId == null) {
      if (!mounted) return;
      setState(() {
        _selectedRoutine = null;
        _gifsByExerciseId = {};
        _loadingPreview = false;
        _adaptive = null;
        _loadingAdaptive = false;
        _adaptiveError = null;
        _ignoredAdaptive = false;
      });
      return;
    }

    setState(() {
      _loadingPreview = true;
      _loadingAdaptive = isPremium;
      _adaptiveError = null;
      _adaptive = null;
      _ignoredAdaptive = false;
      _selectedRoutine = null;
      _gifsByExerciseId = {};
    });

    try {
      final routine = await _routineApi.getRoutine(routineId);
      final ids = routine.exercises.map((e) => e.exerciseId).toList();
      final gifs = ids.isEmpty
          ? <String, String>{}
          : await _exerciseApi.lookupGifs(ids);

      AdaptiveRecommendationsResponse? adaptive;
      String? adaptiveError;
      if (isPremium) {
        try {
          adaptive = await _adaptiveApi.getForRoutine(routineId);
        } on ApiException catch (e) {
          if (e.isPremiumRequired) {
            adaptiveError = 'premium_locked';
          } else {
            adaptiveError = e.message;
          }
        } catch (_) {
          adaptiveError = 'Could not load recommendations';
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedRoutine = routine;
        _gifsByExerciseId = gifs;
        _adaptive = adaptive;
        _adaptiveError = adaptiveError;
        _loadingPreview = false;
        _loadingAdaptive = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _adaptiveError = e.message;
        _loadingPreview = false;
        _loadingAdaptive = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adaptiveError = 'Could not load routine preview';
        _loadingPreview = false;
        _loadingAdaptive = false;
      });
    }
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await _createAndOpenWorkout();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isActiveWorkoutConflict) {
        await _resolveActiveWorkoutConflict(e.activeWorkoutId!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _createAndOpenWorkout() async {
    final workout = await _createWorkout();
    if (!mounted) return;
    context.pushReplacement('/train/workout/${workout.id}');
  }

  String? _workoutNameForStart() {
    final customName = _name.text.trim();
    if (customName.isNotEmpty) return customName;

    final routineId = _selectedRoutineId;
    if (routineId == null) return null;

    final fromPreview = _selectedRoutine?.name.trim();
    if (fromPreview != null && fromPreview.isNotEmpty) return fromPreview;

    for (final routine in _routines) {
      if (routine.id == routineId) {
        final routineName = routine.name.trim();
        if (routineName.isNotEmpty) return routineName;
        break;
      }
    }
    return null;
  }

  Future<Workout> _createWorkout() {
    return _workoutApi.startWorkout(
      routineId: _selectedRoutineId,
      name: _workoutNameForStart(),
    );
  }

  Future<void> _applyRecommendation(AdaptiveRecommendation rec) async {
    setState(() => _starting = true);
    try {
      final workout = await _createWorkout();
      await _adaptiveApi.apply(
        workoutId: workout.id,
        recommendationId: rec.id,
      );
      if (!mounted) return;
      // If backend returns `adaptive_adjustments`, we can display it later in
      // the workout screen; for now we just proceed.
      context.pushReplacement('/train/workout/${workout.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isActiveWorkoutConflict) {
        await _resolveActiveWorkoutConflict(e.activeWorkoutId!, pendingApply: rec);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _resolveActiveWorkoutConflict(
    String activeWorkoutId, {
    AdaptiveRecommendation? pendingApply,
  }) async {
    await handleActiveWorkoutConflict(
      context: context,
      activeWorkoutId: activeWorkoutId,
      onResume: (id) {
        if (!mounted) return;
        context.pushReplacement('/train/workout/$id');
      },
      onDiscardAndRestart: () async {
        setState(() => _starting = true);
        try {
          await _workoutApi.discardWorkout(activeWorkoutId);
          final workout = await _createWorkout();
          if (pendingApply != null) {
            await _adaptiveApi.apply(
              workoutId: workout.id,
              recommendationId: pendingApply.id,
            );
          }
          if (!mounted) return;
          context.pushReplacement('/train/workout/${workout.id}');
          if (mounted) context.read<ShellTabRefresh>().bump(ShellTab.train);
        } on ApiException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        } finally {
          if (mounted) setState(() => _starting = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final recs = _adaptive?.recommendations ?? const <AdaptiveRecommendation>[];
    final isPremium = context.select<SubscriptionService, bool>((s) => s.isPremium);
    final showAdaptiveCard = isPremium && !_ignoredAdaptive && !_loadingAdaptive && _selectedRoutineId != null && recs.isNotEmpty;
    final showAdaptivePremiumTeaser = !isPremium && _selectedRoutineId != null && !_loadingAdaptive;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) context.read<ShellTabRefresh>().bump(ShellTab.train);
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Start workout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.primary)),
            const SizedBox(height: 12),
          ],
          GainsTextField(
            controller: _name,
            label: 'Session name (optional)',
            hint: 'e.g. Push day',
          ),
          if (_selectedRoutineId != null) ...[
            const SizedBox(height: 12),
            if (_loadingAdaptive)
              const LinearProgressIndicator(minHeight: 2)
            else if (showAdaptivePremiumTeaser)
              const PremiumTeaserCard(
                title: 'AI workout suggestions',
                description: 'Get smart set and exercise adjustments before each session with Premium.',
                icon: Icons.auto_awesome_outlined,
              )
            else if (_adaptiveError != null && _adaptiveError != 'premium_locked')
              Text(_adaptiveError!, style: const TextStyle(color: AppColors.textMuted))
            else if (showAdaptiveCard)
              _AdaptiveAdjustmentCard(
                recommendation: recs.first,
                contextSummary: _adaptive?.contextSummary,
                applying: _starting,
                onApply: () => _applyRecommendation(recs.first),
                onIgnore: () => setState(() => _ignoredAdaptive = true),
              ),
          ],
          const SizedBox(height: 24),
          Text(
            'From routine (optional)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          if (_loadingRoutines)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else ...[
            _RoutineOption(
              title: 'No routine',
              selected: _selectedRoutineId == null,
                onTap: () {
                setState(() => _selectedRoutineId = null);
                _loadRoutinePreview();
              },
            ),
            ..._routines.map(
              (r) => _RoutineOption(
                title: r.name,
                subtitle: '${r.exerciseCount} exercises',
                selected: _selectedRoutineId == r.id,
                onTap: () {
                  setState(() => _selectedRoutineId = r.id);
                  _loadRoutinePreview();
                },
              ),
            ),
          ],
          if (_selectedRoutineId != null && (_selectedRoutine?.exercises.isNotEmpty ?? false)) ...[
            const SizedBox(height: 24),
            Text(
              'Exercises in this routine',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (_loadingPreview)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else
              ..._selectedRoutine!.exercises.map(
                (e) => _RoutineExercisePreviewTile(
                  exercise: e,
                  gifUrl: _gifsByExerciseId[e.exerciseId],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Demo animations via ExerciseDB',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _starting ? null : _start,
            child: _starting
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Start'),
          ),
        ],
      ),
      ),
    );
  }
}

class _AdaptiveAdjustmentCard extends StatelessWidget {
  const _AdaptiveAdjustmentCard({
    required this.recommendation,
    required this.contextSummary,
    required this.applying,
    required this.onApply,
    required this.onIgnore,
  });

  final AdaptiveRecommendation recommendation;
  final AdaptiveRecommendationContextSummary? contextSummary;
  final bool applying;
  final VoidCallback onApply;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final subtitle = recommendation.reason.trim().isNotEmpty
        ? recommendation.reason.trim()
        : (recommendation.suggestedChange.summary.isNotEmpty
            ? recommendation.suggestedChange.summary
            : contextSummary?.subtitle);

    return Card(
      color: AppColors.primaryMuted.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'AI adjustment',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  recommendation.confidence,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              recommendation.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: applying ? null : onApply,
                    child: applying
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Apply'),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: applying ? null : onIgnore,
                  child: const Text('Ignore'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineExercisePreviewTile extends StatelessWidget {
  const _RoutineExercisePreviewTile({
    required this.exercise,
    this.gifUrl,
  });

  final RoutineExercise exercise;
  final String? gifUrl;

  @override
  Widget build(BuildContext context) {
    final sets = exercise.targetSets;
    final repMin = exercise.targetRepMin;
    final repMax = exercise.targetRepMax;
    String? target;
    if (sets != null && repMin != null && repMax != null) {
      target = '$sets × $repMin–$repMax';
    } else if (sets != null) {
      target = '$sets sets';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ExerciseGifThumbnail(gifUrl: gifUrl, size: kWorkoutExerciseGifSize),
        title: Text(exercise.exerciseName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: target != null ? Text(target) : null,
      ),
    );
  }
}

class _RoutineOption extends StatelessWidget {
  const _RoutineOption({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? AppColors.primaryMuted.withValues(alpha: 0.2) : null,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
        onTap: onTap,
      ),
    );
  }
}
