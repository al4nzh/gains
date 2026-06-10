import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/preferences/body_units_preference.dart';
import 'package:gains/features/analytics/presentation/analytics_formatters.dart';
import 'package:gains/features/ai/data/ai_api.dart';
import 'package:gains/features/ai/models/workout_insight.dart';
import 'package:gains/core/units/body_units.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';
import 'package:gains/core/theme/app_theme.dart';
import 'package:gains/features/exercises/data/exercise_api.dart';
import 'package:gains/features/workouts/data/workout_api.dart';
import 'package:gains/features/workouts/models/finish_stats.dart';
import 'package:gains/features/workouts/models/workout.dart';
import 'package:gains/features/workouts/presentation/muscle_group_mapping.dart';
import 'package:gains/features/workouts/presentation/widgets/session_muscles_diagram.dart';
import 'package:gains/features/subscription/presentation/paywall_sheet.dart';
import 'package:gains/features/subscription/services/subscription_service.dart';
import 'package:gains/features/subscription/utils/premium_errors.dart';
import 'package:gains/features/workouts/presentation/widgets/workout_share_card.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.workoutId,
    this.initialStats,
  });

  final String workoutId;
  final FinishStats? initialStats;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  final _shareCapture = ScreenshotController();
  Workout? _workout;
  FinishStats? _stats;
  Map<String, String> _exerciseMuscleGroup = {};
  WorkoutAnalysisInsight? _insight;
  String? _error;
  bool _loading = true;
  bool _analyzing = false;
  bool _sharing = false;
  bool _insightExpanded = false;

  @override
  void initState() {
    super.initState();
    _stats = widget.initialStats;
    if (_stats != null) _loading = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_workout != null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = context.read<ApiClient>();
      final api = WorkoutApi(client);
      final workoutFuture = api.getWorkout(widget.workoutId);
      final muscleFuture = ExerciseApi(client)
          .loadMuscleGroupMap()
          .catchError((_) => <String, String>{});
      final workout = await workoutFuture;
      final muscleMap = await muscleFuture;
      if (!mounted) return;
      setState(() {
        _workout = workout;
        _stats ??= workout.finishStats;
        _exerciseMuscleGroup = muscleMap;
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
        _error = 'Could not load summary';
        _loading = false;
      });
    }
  }

  void _leaveSummary() {
    context.read<ShellTabRefresh>().bumpMany([ShellTab.home, ShellTab.train, ShellTab.progress]);
    context.go('/train');
  }

  void _onPopInvoked(bool didPop) {
    if (didPop) {
      context.read<ShellTabRefresh>().bumpMany([ShellTab.home, ShellTab.train, ShellTab.progress]);
    }
  }

  String _aiErrorMessage(ApiException e) {
    if (e.statusCode == 503) return 'AI is unavailable (server needs OPENAI_API_KEY).';
    if (e.statusCode == 400) return e.message;
    return e.message;
  }

  Future<void> _analyzeWithAi() async {
    if (_analyzing) return;
    if (!context.read<SubscriptionService>().isPremium) {
      await showPaywallSheet(context);
      return;
    }

    setState(() {
      _analyzing = true;
      _insightExpanded = true;
    });

    try {
      final unitSystem = context.read<BodyUnitsPreference>().apiUnitSystem;
      final insight = await AiApi(context.read<ApiClient>()).analyzeWorkout(
        widget.workoutId,
        unitSystem: unitSystem,
      );
      if (!mounted) return;
      setState(() {
        _insight = insight;
        _analyzing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      if (e.isPremiumRequired) {
        await showPaywallForApiError(context, e);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_aiErrorMessage(e))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not analyze workout')),
      );
    }
  }

  String? _shareAiOneLiner() {
    final title = _insight?.title.trim();
    if (title != null && title.isNotEmpty) return title;
    return null;
  }

  Future<void> _shareSummary(FinishStats stats) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final title = _workout?.displayName ?? 'Workout';
      final sessionWorkout = _workout;
      final sessionBests = sessionWorkout != null
          ? shareBestSetsFromLoggedSets(sessionWorkout.sets)
          : <ShareSessionBestSet>[];
      final rawGroups = <String>{};
      for (final e in stats.e1rmByExercise) {
        final g = _exerciseMuscleGroup[e.exerciseId];
        if (g != null && g.isNotEmpty) rawGroups.add(g);
      }
      if (sessionWorkout != null) {
        for (final s in sessionWorkout.sets) {
          final g = _exerciseMuscleGroup[s.exerciseId];
          if (g != null && g.isNotEmpty) rawGroups.add(g);
        }
      }
      final highlighted = highlightedMusclesForSession(
        stats: stats,
        workout: sessionWorkout,
        exerciseIdToMuscleGroup: _exerciseMuscleGroup,
      );
      final units = context.read<BodyUnitsPreference>().units;
      final bytes = await _shareCapture.captureFromWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: Theme(
              data: AppTheme.dark,
              child: Material(
                type: MaterialType.transparency,
                child: WorkoutShareCard(
                  workoutTitle: title,
                  stats: stats,
                  sessionBests: sessionBests,
                  units: units,
                  aiOneLiner: _shareAiOneLiner(),
                  highlightedMuscles: highlighted,
                  trainedGroupLabels: trainedGroupLabelsFromIds(rawGroups),
                ),
              ),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 3,
      );
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'gains-workout.png')],
        text: 'Workout complete on Gains',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share summary')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final workout = _workout;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(workout?.displayName ?? 'Workout complete'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _leaveSummary,
        ),
        actions: [
          if (stats != null)
            IconButton(
              tooltip: 'Share story',
              onPressed: _sharing ? null : () => _shareSummary(stats!),
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
            ),
        ],
      ),
      body: _buildBody(stats),
      ),
    );
  }

  Widget _buildBody(FinishStats? stats) {
    if (_loading && stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && stats == null) {
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
    if (stats == null) {
      return const Center(child: Text('No summary available'));
    }

    final elo = stats.strengthElo;
    final sessionWorkout = _workout;
    final highlighted = highlightedMusclesForSession(
      stats: stats,
      workout: sessionWorkout,
      exerciseIdToMuscleGroup: _exerciseMuscleGroup,
    );
    final rawGroups = <String>{};
    for (final e in stats.e1rmByExercise) {
      final g = _exerciseMuscleGroup[e.exerciseId];
      if (g != null && g.isNotEmpty) rawGroups.add(g);
    }
    if (sessionWorkout != null) {
      for (final s in sessionWorkout.sets) {
        final g = _exerciseMuscleGroup[s.exerciseId];
        if (g != null && g.isNotEmpty) rawGroups.add(g);
      }
    }

    final units = context.watch<BodyUnitsPreference>().units;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Nice work!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Volume', value: formatVolumeKg(stats.totalVolumeKg, units))),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: 'Duration', value: formatDuration(stats.durationSeconds))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Sets', value: '${stats.setCount}')),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: 'Exercises', value: '${stats.exerciseCount}')),
          ],
        ),
        const SizedBox(height: 24),
        SessionMusclesDiagram(
          highlightedMuscles: highlighted,
          trainedGroupLabels: trainedGroupLabelsFromIds(rawGroups),
        ),
        if (elo != null && !elo.skipped) ...[
          const SizedBox(height: 24),
          Text(
            'Strength Elo',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '${elo.after}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatEloChange(elo.delta),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: elo.delta >= 0 ? Colors.greenAccent : AppColors.textSecondary,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '30d ${formatEloChange(elo.change30d)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (stats.prs.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Personal records',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ...stats.prs.map(
            (pr) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(pr.exerciseName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'e1RM ${formatE1rmKg(pr.previousBestE1rmKg, units)} → ${formatE1rmKg(pr.newBestE1rmKg, units)}',
                ),
                leading: const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
              ),
            ),
          ),
        ],
        if (stats.e1rmByExercise.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Best e1RM this session',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ...stats.e1rmByExercise.map(
            (e) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                title: Text(e.exerciseName),
                trailing: Text(
                  formatE1rmKg(e.bestE1rmKg, units),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'AI coach',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        if (_insight != null && _insightExpanded) ...[
          _WorkoutInsightCard(insight: _insight!, units: units),
          const SizedBox(height: 8),
        ],
        if (_analyzing) ...[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Analyzing your session…\nThis can take up to a minute.',
                      style: TextStyle(color: AppColors.textSecondary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_insight == null)
          OutlinedButton.icon(
            onPressed: _analyzing ? null : _analyzeWithAi,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Analyze with AI'),
          )
        else
          TextButton(
            onPressed: () => setState(() => _insightExpanded = !_insightExpanded),
            child: Text(_insightExpanded ? 'Hide analysis' : 'Show analysis'),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _sharing ? null : () => _shareSummary(stats),
          icon: const Icon(Icons.ios_share),
          label: const Text('Share to story'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _leaveSummary,
          child: const Text('Back to Train'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _WorkoutInsightCard extends StatelessWidget {
  const _WorkoutInsightCard({required this.insight, required this.units});

  final WorkoutAnalysisInsight insight;
  final BodyUnitSystem units;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryMuted.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    BodyUnits.formatAiWeightUnitsInText(insight.title, units),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._insightMessageParagraphs(context, BodyUnits.formatAiWeightUnitsInText(insight.message, units)),
          ],
        ),
      ),
    );
  }
}

List<Widget> _insightMessageParagraphs(BuildContext context, String message) {
  final paragraphs = message.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();
  if (paragraphs.isEmpty) {
    return [
      Text(
        message.trim(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: AppColors.textSecondary,
            ),
      ),
    ];
  }
  return [
    for (var i = 0; i < paragraphs.length; i++) ...[
      if (i > 0) const SizedBox(height: 8),
      Text(
        paragraphs[i].trim(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: AppColors.textSecondary,
              fontWeight: _insightParagraphStartsWithLabel(paragraphs[i])
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
      ),
    ],
  ];
}

bool _insightParagraphStartsWithLabel(String paragraph) {
  final trimmed = paragraph.trim().toLowerCase();
  return trimmed.startsWith('likely reason:') || trimmed.startsWith('next move:');
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
