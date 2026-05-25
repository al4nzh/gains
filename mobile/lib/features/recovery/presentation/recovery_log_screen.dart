import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/recovery/data/recovery_api.dart';
import 'package:gains/features/recovery/models/recovery_checkin.dart';
import 'package:gains/features/recovery/utils/local_checkin_date.dart';
import 'package:provider/provider.dart';

class RecoveryLogScreen extends StatefulWidget {
  const RecoveryLogScreen({super.key});

  @override
  State<RecoveryLogScreen> createState() => _RecoveryLogScreenState();
}

class _RecoveryLogScreenState extends State<RecoveryLogScreen> {
  RecoveryApi? _api;
  List<RecoveryCheckin> _checkins = [];
  String? _error;
  bool _loading = true;

  RecoveryApi get api => _api ??= RecoveryApi(context.read<ApiClient>());

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
      final list = await api.listCheckins(
        from: LocalCheckinDate.daysAgo(29),
        to: LocalCheckinDate.today(),
      );
      if (!mounted) return;
      setState(() {
        _checkins = list.reversed.toList();
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
        _error = 'Could not load recovery log';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recovery log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _checkins.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.35),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null && _checkins.isEmpty) {
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Last 30 days',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_checkins.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Text(
                  'No check-ins yet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Log daily readiness from Home to build your recovery history.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          ..._checkins.map((c) => _CheckinCard(checkin: c)),
      ],
    );
  }
}

class _CheckinCard extends StatelessWidget {
  const _CheckinCard({required this.checkin});

  final RecoveryCheckin checkin;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return iso;
    final dt = DateTime(y, m, d);
    final today = LocalCheckinDate.today();
    if (iso == today) return 'Today';
    final yesterday = LocalCheckinDate.daysAgo(1);
    if (iso == yesterday) return 'Yesterday';
    return '${_weekdays[dt.weekday - 1]}, ${_months[m - 1]} $d';
  }

  String _formatSleep(double hours) {
    if (hours == hours.roundToDouble()) return '${hours.toInt()}h sleep';
    return '${hours.toStringAsFixed(1)}h sleep';
  }

  @override
  Widget build(BuildContext context) {
    final notes = checkin.notes?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(checkin.checkinDate),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                _EnergyBadge(level: checkin.energyReadiness),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MetricChip(icon: Icons.bedtime_outlined, label: _formatSleep(checkin.sleepHours)),
                _MetricChip(
                  icon: Icons.local_fire_department_outlined,
                  label: '${checkin.caloriesKcal} kcal',
                ),
                _MetricChip(
                  icon: Icons.egg_outlined,
                  label: '${checkin.proteinG}g protein',
                ),
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                notes,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnergyBadge extends StatelessWidget {
  const _EnergyBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryMuted.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Energy $level/5',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
