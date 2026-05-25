import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine.dart';
import 'package:gains/features/workouts/data/workout_api.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = context.read<ApiClient>();
    _workoutApi = WorkoutApi(client);
    _routineApi = RoutineApi(client);
  }

  @override
  void initState() {
    super.initState();
    _selectedRoutineId = widget.routineId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoutines());
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

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final workout = await _workoutApi.startWorkout(
        routineId: _selectedRoutineId,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (!mounted) return;
      context.pushReplacement('/train/workout/${workout.id}');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: () => setState(() => _selectedRoutineId = null),
            ),
            ..._routines.map(
              (r) => _RoutineOption(
                title: r.name,
                subtitle: '${r.exerciseCount} exercises',
                selected: _selectedRoutineId == r.id,
                onTap: () => setState(() => _selectedRoutineId = r.id),
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
