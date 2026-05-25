import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/analytics/data/analytics_api.dart';
import 'package:gains/features/analytics/models/exercise_detail.dart';
import 'package:gains/features/analytics/presentation/analytics_formatters.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';
import 'package:provider/provider.dart';

class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  AnalyticsApi? _api;
  ExerciseDetail? _detail;
  String? _error;
  bool _loading = true;

  AnalyticsApi get api => _api ??= AnalyticsApi(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await api.getExerciseDetail(widget.exerciseId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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
        _error = 'Could not load exercise';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _detail?.exerciseName ?? 'Exercise';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _detail == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.35),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null && _detail == null) {
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

    final detail = _detail!;
    final historyNewestFirst = detail.history.reversed.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      trendIcon(detail.trendSummary),
                      color: trendColor(detail.trendSummary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatTrendLabel(detail.trendSummary),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: trendColor(detail.trendSummary),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Lifetime best e1RM', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  formatE1rmKg(detail.absoluteBestE1rmKg),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (detail.absoluteBestSet != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Set ${formatSetLoad(detail.absoluteBestSet)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
                if (detail.absoluteBestCompletedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    formatRelativeDate(detail.absoluteBestCompletedAt!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (detail.latestComparison != null) ...[
          const SizedBox(height: 12),
          _ComparisonCard(comparison: detail.latestComparison!),
        ],
        const SizedBox(height: 20),
        Text('Session history', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Up to 60 recent workouts',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (historyNewestFirst.isEmpty)
          Text(
            'No sessions yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          )
        else
          ...historyNewestFirst.map((entry) => _HistoryTile(entry: entry)),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.comparison});

  final ExerciseLatestComparison comparison;

  @override
  Widget build(BuildContext context) {
    final e1rmColor = e1rmChangeColor(comparison.e1rmChangeKg);
    final volColor = e1rmChangeColor(comparison.volumeChangeKg);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latest vs previous', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              'Previous: ${formatRelativeDate(comparison.previousCompletedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            _DeltaRow(
              label: 'e1RM',
              value: formatE1rmDelta(comparison.e1rmChangeKg, pct: comparison.e1rmChangePct),
              color: e1rmColor,
            ),
            const SizedBox(height: 8),
            _DeltaRow(
              label: 'Volume',
              value: formatE1rmDelta(
                comparison.volumeChangeKg,
                pct: comparison.volumeChangePct,
              ),
              color: volColor,
            ),
            if (comparison.bestSetPrevious != null || comparison.bestSetCurrent != null) ...[
              const SizedBox(height: 12),
              if (comparison.bestSetPrevious != null)
                Text(
                  'Previous top set ${formatSetLoad(comparison.bestSetPrevious)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (comparison.bestSetCurrent != null)
                Text(
                  'Latest top set ${formatSetLoad(comparison.bestSetCurrent)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final ExerciseHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final hasPr = entry.prs.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: hasPr
            ? const Icon(Icons.emoji_events_outlined, color: AppColors.primary)
            : null,
        title: Text(
          formatRelativeDate(entry.completedAt),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top set ${formatSetLoad(entry.bestSet)}'),
            Text(
              'e1RM ${formatE1rmKg(entry.bestE1rmKg)} · ${formatVolumeKg(entry.volumeKg)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
