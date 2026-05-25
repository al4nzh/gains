import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine.dart';
import 'package:gains/features/routines/models/routine_exercise.dart';
import 'package:gains/features/routines/presentation/routine_formatters.dart';
import 'package:gains/features/routines/presentation/widgets/add_exercise_sheet.dart';
import 'package:gains/features/routines/presentation/widgets/edit_exercise_sheet.dart';
import 'package:gains/features/routines/presentation/widgets/routine_dialogs.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({super.key, required this.routineId});

  final String routineId;

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  RoutineApi? _api;
  Routine? _routine;
  String? _error;
  bool _loading = true;

  RoutineApi get api => _api ??= RoutineApi(context.read<ApiClient>());

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
      final routine = await api.getRoutine(widget.routineId);
      if (!mounted) return;
      setState(() {
        _routine = routine;
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
        _error = 'Could not load routine';
        _loading = false;
      });
    }
  }

  Future<void> _editRoutine() async {
    final r = _routine;
    if (r == null) return;

    final edited = await promptEditRoutine(
      context,
      initialName: r.name,
      initialDescription: r.description,
    );
    if (edited == null || !mounted) return;

    try {
      final updated = await api.updateRoutine(
        r.id,
        name: edited.name.isEmpty ? r.name : edited.name,
        description: edited.description.isEmpty ? null : edited.description,
      );
      if (!mounted) return;
      setState(() => _routine = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _addExercise() async {
    final added = await AddExerciseSheet.show(context, widget.routineId);
    if (added == true) _load();
  }

  Future<void> _editExercise(RoutineExercise exercise) async {
    final saved = await EditExerciseSheet.show(
      context,
      routineId: widget.routineId,
      exercise: exercise,
    );
    if (saved == true) _load();
  }

  Future<void> _deleteExercise(RoutineExercise exercise) async {
    final ok = await confirmDelete(context, 'Remove ${exercise.exerciseName} from this routine?');
    if (!ok || !mounted) return;

    try {
      await api.deleteExercise(widget.routineId, exercise.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteRoutine() async {
    final r = _routine;
    if (r == null) return;

    final ok = await confirmDelete(
      context,
      'Delete “${r.name}”? Past workouts that used this routine will be kept.',
      title: 'Delete routine?',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;

    try {
      await api.deleteRoutine(r.id);
      if (!mounted) return;
      context.read<ShellTabRefresh>().bump(ShellTab.routines);
      context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _routine;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) context.read<ShellTabRefresh>().bump(ShellTab.routines);
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(r?.name ?? 'Routine'),
        actions: [
          if (r != null) ...[
            IconButton(
              tooltip: 'Edit routine',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editRoutine,
            ),
            IconButton(
              tooltip: 'Delete routine',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteRoutine,
            ),
          ],
        ],
      ),
      floatingActionButton: r == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
      body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _routine == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _routine == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
              TextButton(onPressed: () => context.pop(), child: const Text('Back')),
            ],
          ),
        ),
      );
    }

    final r = _routine!;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/train/start?routineId=${r.id}'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start workout'),
            ),
          ),
          const SizedBox(height: 16),
          if (r.description != null && r.description!.isNotEmpty) ...[
            Text(
              r.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
          ],
          if (r.exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No exercises yet. Add from the catalog.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...r.exercises.map(_exerciseTile),
        ],
      ),
    );
  }

  Widget _exerciseTile(RoutineExercise e) {
    final subtitle = routineExerciseSubtitle(e);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(e.exerciseName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
            if (e.notes != null && e.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(e.notes!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                _editExercise(e);
              case 'delete':
                _deleteExercise(e);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit targets')),
            PopupMenuItem(value: 'delete', child: Text('Remove')),
          ],
        ),
        onTap: () => _editExercise(e),
      ),
    );
  }
}
