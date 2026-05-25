import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:gains/features/home/data/home_api.dart';
import 'package:gains/features/home/models/home_summary.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';
import 'package:gains/features/recovery/data/recovery_api.dart';
import 'package:gains/features/recovery/models/recovery_checkin.dart';
import 'package:gains/features/recovery/presentation/widgets/daily_readiness_card.dart';
import 'package:gains/features/recovery/utils/local_checkin_date.dart';
import 'package:gains/features/shell/shell_tab_auto_refresh.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ShellTabAutoRefresh {
  HomeApi? _homeApi;
  RecoveryApi? _recoveryApi;
  HomeSummary? _data;
  RecoveryCheckinStatus? _readinessStatus;
  String? _error;
  bool _loading = true;
  bool _readinessDismissedSession = false;

  @override
  int get shellTabIndex => ShellTab.home;

  @override
  void onShellTabRefresh() => _load(silent: true);

  HomeApi get homeApi => _homeApi ??= HomeApi(context.read<ApiClient>());
  RecoveryApi get recoveryApi => _recoveryApi ??= RecoveryApi(context.read<ApiClient>());

  String get _todayLocal => LocalCheckinDate.today();

  bool get _shouldShowReadinessCard {
    if (_readinessDismissedSession) return false;
    if (LocalCheckinDate.isBefore5Am()) return false;
    final status = _readinessStatus;
    if (status == null) return false;
    return status.shouldPrompt && !status.hasCheckinToday;
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
      final data = await homeApi.fetchHome();
      RecoveryCheckinStatus? readiness;
      if (!_readinessDismissedSession && !LocalCheckinDate.isBefore5Am()) {
        try {
          readiness = await recoveryApi.getStatus(_todayLocal);
        } catch (_) {
          readiness = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _readinessStatus = readiness;
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
        _error = 'Could not load home';
        _loading = false;
      });
    }
  }

  void _onQuickAction(String label) {
    switch (label) {
      case 'Start workout':
        context.push('/train/start');
      case 'Coach':
        context.read<ShellTabRefresh>().bump(ShellTab.coach);
        context.go('/coach');
      case 'Body fat scan':
        context.push('/physique-scans');
    }
  }

  void _dismissReadiness() {
    setState(() => _readinessDismissedSession = true);
  }

  void _onReadinessSubmitted() {
    setState(() {
      _readinessDismissedSession = true;
      _readinessStatus = null;
    });
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final initial = session.user?.email.isNotEmpty == true
        ? session.user!.email[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceElevated,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.35),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null && _data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final data = _data!;
    final showReadiness = _shouldShowReadinessCard;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (showReadiness) ...[
          DailyReadinessCard(
            checkinDate: _todayLocal,
            defaultCalories: data.sharpness.targetKcal,
            defaultProtein: data.sharpness.targetProteinG,
            initialExpanded: false,
            onSubmitted: _onReadinessSubmitted,
            onDismissed: _dismissReadiness,
          ),
          const SizedBox(height: 12),
        ],
        _EloCard(data: data),
        const SizedBox(height: 12),
        _SharpnessCard(sharpness: data.sharpness),
        const SizedBox(height: 12),
        _TargetsCard(sharpness: data.sharpness),
        const SizedBox(height: 12),
        _LatestWorkoutCard(workout: data.latestWorkout),
        const SizedBox(height: 12),
        _StatsRow(data: data),
        const SizedBox(height: 20),
        Text('Quick actions', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
          _QuickActions(onAction: _onQuickAction),
      ],
    );
  }
}

class _EloCard extends StatelessWidget {
  const _EloCard({required this.data});

  final HomeSummary data;

  @override
  Widget build(BuildContext context) {
    final elo = data.strengthElo;
    final rank = data.strengthEloRank;
    final change = data.eloChange30d;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Strength Elo', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  elo?.toString() ?? '—',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1,
                      ),
                ),
                const SizedBox(width: 12),
                if (rank != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      humanizeSnake(rank),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '30d ${formatEloChange(change)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _changeColor(change),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _changeColor(int? delta) {
    if (delta == null || delta == 0) return AppColors.textSecondary;
    return delta > 0 ? AppColors.success : AppColors.error;
  }
}

class _SharpnessCard extends StatelessWidget {
  const _SharpnessCard({required this.sharpness});

  final SharpnessOverview sharpness;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sharpness', style: Theme.of(context).textTheme.labelLarge),
                Text(
                  '${sharpness.score}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Based on last 7 days of check-ins',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            _MetricBar(label: 'Sleep', value: sharpness.sleep01),
            const SizedBox(height: 6),
            _MetricBar(label: 'Energy', value: sharpness.energy01),
            const SizedBox(height: 6),
            _MetricBar(label: 'Protein', value: sharpness.protein01),
            const SizedBox(height: 6),
            _MetricBar(label: 'Calories', value: sharpness.calories01),
          ],
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetsCard extends StatelessWidget {
  const _TargetsCard({required this.sharpness});

  final SharpnessOverview sharpness;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Daily targets', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              'From your profile (goal, weight, activity)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TargetTile(
                    label: 'Calories',
                    value: sharpness.targetKcal?.toString() ?? '—',
                    unit: 'kcal',
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.border),
                Expanded(
                  child: _TargetTile(
                    label: 'Protein',
                    value: sharpness.targetProteinG?.toString() ?? '—',
                    unit: 'g',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(unit, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _LatestWorkoutCard extends StatelessWidget {
  const _LatestWorkoutCard({required this.workout});

  final WorkoutSnapshot? workout;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latest workout', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            if (workout == null)
              Text(
                'No completed workouts yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              )
            else ...[
              Text(
                formatRelativeDate(workout!.completedAt),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatVolumeKg(workout!.totalVolumeKg)} · ${formatDuration(workout!.durationSeconds)} · ${workout!.setCount} sets',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});

  final HomeSummary data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: '${data.weeklyVolumeWindowDays}d volume',
            value: formatVolumeKg(data.weeklyVolumeKg),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: 'Streak',
            value: '${data.streakDays}d',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: '28d avg/wk',
            value: data.workoutConsistency.avgPerWeek.toStringAsFixed(1),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAction});

  final void Function(String label) onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionButton(
          icon: Icons.play_arrow_rounded,
          label: 'Start workout',
          primary: true,
          onTap: () => onAction('Start workout'),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Coach',
            onTap: () => onAction('Coach'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _ActionButton(
            icon: Icons.camera_alt_outlined,
            label: 'Body fat scan',
            onTap: () => onAction('Body fat scan'),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
