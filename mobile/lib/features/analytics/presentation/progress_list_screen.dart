import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/analytics/data/analytics_api.dart';
import 'package:gains/features/analytics/models/exercise_progression.dart';
import 'package:gains/core/widgets/skeleton.dart';
import 'package:gains/core/preferences/body_units_preference.dart';
import 'package:gains/features/analytics/presentation/analytics_formatters.dart';
import 'package:gains/features/analytics/presentation/widgets/e1rm_trend_chart.dart';
import 'package:gains/features/shell/shell_tab_auto_refresh.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

class ProgressListScreen extends StatefulWidget {
  const ProgressListScreen({super.key});

  @override
  State<ProgressListScreen> createState() => _ProgressListScreenState();
}

class _ProgressListScreenState extends State<ProgressListScreen> with ShellTabAutoRefresh {
  AnalyticsApi? _api;
  List<ExerciseProgressionRow> _exercises = [];
  final Map<String, List<double>> _sparklineByExerciseId = {};
  String? _error;
  bool _loading = true;
  bool _loadingSparklines = false;

  @override
  int get shellTabIndex => ShellTab.progress;

  @override
  void onShellTabRefresh() => _load(silent: true);

  AnalyticsApi get api => _api ??= AnalyticsApi(context.read<ApiClient>());

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
      final list = await api.listExercises();
      if (!mounted) return;
      setState(() {
        _exercises = list;
        _loading = false;
        _sparklineByExerciseId.clear();
      });
      _primeSparklines(list);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load progress';
        _loading = false;
      });
    }
  }

  void _primeSparklines(List<ExerciseProgressionRow> list) {
    if (_loadingSparklines) return;
    if (list.isEmpty) return;

    final ids = list.map((e) => e.exerciseId).toList();
    if (ids.isEmpty) return;

    _loadingSparklines = true;
    Future(() async {
      try {
        // Fetch in small parallel batches so every card updates after refresh.
        const batchSize = 4;
        for (var i = 0; i < ids.length; i += batchSize) {
          final batch = ids.skip(i).take(batchSize);
          await Future.wait(
            batch.map((id) async {
              try {
                final detail = await api.getExerciseDetail(id);
                final history = detail.history;
                if (history.isEmpty) return;
                final tail = history.length <= 6 ? history : history.sublist(history.length - 6);
                _sparklineByExerciseId[id] = tail.map((h) => h.bestE1rmKg).toList();
              } catch (_) {
                // Ignore per-exercise failures.
              }
            }),
          );
          if (!mounted) return;
          setState(() {});
        }
      } finally {
        _loadingSparklines = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Progress')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _exercises.isEmpty) {
      return const ProgressLoadingSkeleton();
    }
    if (_error != null && _exercises.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (_exercises.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Text(
            'No exercise data yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Finish a workout with logged sets to see e1RM trends here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _exercises.length + 1,
      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 12 : 8),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Text(
            'Based on your last 36 completed workouts',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          );
        }
        final row = _exercises[i - 1];
        return _ExerciseProgressCard(
          row: row,
          sparkline: _sparklineByExerciseId[row.exerciseId],
          onTap: () => context.push('/progress/${row.exerciseId}'),
        );
      },
    );
  }
}

class _ExerciseProgressCard extends StatelessWidget {
  const _ExerciseProgressCard({
    required this.row,
    required this.onTap,
    required this.sparkline,
  });

  final ExerciseProgressionRow row;
  final VoidCallback onTap;
  final List<double>? sparkline;

  @override
  Widget build(BuildContext context) {
    final changeColor = e1rmChangeColor(row.e1rmChangeKg);
    final trend = row.trend;
    final units = context.watch<BodyUnitsPreference>().units;
    final isPr = (row.latestE1rmKg > 0) && (row.latestE1rmKg >= row.absoluteBestE1rmKg - 0.01);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.exerciseName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Latest e1RM ${formatE1rmKg(row.latestE1rmKg, units)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (row.latestBestSet != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Top set ${formatSetLoad(row.latestBestSet, units)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Lifetime best ${formatE1rmKg(row.absoluteBestE1rmKg, units)} · ${row.dataPoints} sessions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isPr) ...[
                    const _PrBadge(),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon(trend), size: 18, color: trendColor(trend)),
                      const SizedBox(width: 4),
                      Text(
                        formatE1rmDelta(row.e1rmChangeKg, units, pct: row.e1rmChangePct),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: changeColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (sparkline != null && sparkline!.length >= 2) ...[
                    E1rmSparkline(values: sparkline!, trend: trend),
                    const SizedBox(height: 6),
                  ],
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrBadge extends StatelessWidget {
  const _PrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏆', style: TextStyle(fontSize: 11, height: 1.1)),
          SizedBox(width: 3),
          Text(
            'PR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
