import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';
import 'package:gains/features/workouts/data/workout_api.dart';
import 'package:gains/features/workouts/models/workout.dart';
import 'package:gains/features/shell/shell_tab_auto_refresh.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> with ShellTabAutoRefresh {
  WorkoutApi? _api;
  List<Workout> _workouts = [];
  String? _error;
  bool _loading = true;

  @override
  int get shellTabIndex => ShellTab.train;

  @override
  void onShellTabRefresh() => _load(silent: true);

  WorkoutApi get api => _api ??= WorkoutApi(context.read<ApiClient>());

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
      final list = await api.listWorkouts();
      if (!mounted) return;
      setState(() {
        _workouts = list;
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
        _error = 'Could not load workouts';
        _loading = false;
      });
    }
  }

  Workout? get _inProgress {
    for (final w in _workouts) {
      if (w.isInProgress) return w;
    }
    return null;
  }

  List<Workout> get _completed => _workouts.where((w) => !w.isInProgress).toList();

  void _startWorkout() => context.push('/train/start');

  void _openWorkout(Workout w) {
    if (w.isInProgress) {
      context.push('/train/workout/${w.id}');
    } else {
      context.push('/train/workout/${w.id}/summary');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Train')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startWorkout,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start workout'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _workouts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _workouts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: OutlinedButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    final active = _inProgress;
    final completed = _completed;

    if (active == null && completed.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Text(
            'No workouts yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap Start workout to log your first session.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        if (active != null) ...[
          Card(
            color: AppColors.primaryMuted.withValues(alpha: 0.15),
            child: ListTile(
              leading: const Icon(Icons.fitness_center, color: AppColors.primary),
              title: Text(
                active.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('In progress · tap to continue'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openWorkout(active),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'History',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
        ],
        ...completed.map(_historyTile),
      ],
    );
  }

  Widget _historyTile(Workout w) {
    final when = w.completedAt != null ? formatRelativeDate(w.completedAt!) : '';
    final vol = w.totalVolumeKg != null ? formatVolumeKg(w.totalVolumeKg!) : '—';
    final dur = w.durationSeconds != null ? formatDuration(w.durationSeconds!) : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(w.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$when · $vol · $dur'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openWorkout(w),
      ),
    );
  }
}
