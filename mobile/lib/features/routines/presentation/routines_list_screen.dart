import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/exercises/data/exercise_api.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine.dart';
import 'package:gains/features/routines/presentation/widgets/routine_muscles_mini_diagram.dart';
import 'package:gains/features/routines/presentation/widgets/routine_dialogs.dart';
import 'package:gains/features/shell/shell_tab_auto_refresh.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

class RoutinesListScreen extends StatefulWidget {
  const RoutinesListScreen({super.key});

  @override
  State<RoutinesListScreen> createState() => _RoutinesListScreenState();
}

class _RoutinesListScreenState extends State<RoutinesListScreen> with ShellTabAutoRefresh {
  RoutineApi? _api;
  List<RoutineSummary> _routines = [];
  Map<String, String> _exerciseIdToMuscleGroup = {};
  String? _error;
  bool _loading = true;

  @override
  int get shellTabIndex => ShellTab.routines;

  @override
  void onShellTabRefresh() => _load(silent: true);

  RoutineApi get api => _api ??= RoutineApi(context.read<ApiClient>());

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
      final listFuture = api.listRoutines();
      final muscleMapFuture = ExerciseApi(client).loadMuscleGroupMap();

      final list = await listFuture;
      final muscleMap = await muscleMapFuture;
      if (!mounted) return;
      setState(() {
        _routines = list;
        _exerciseIdToMuscleGroup = muscleMap;
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
        _error = 'Could not load routines';
        _loading = false;
      });
    }
  }

  Future<void> _createRoutine() async {
    final name = await promptRoutineName(context);
    if (name == null || !mounted) return;

    try {
      final routine = await api.createRoutine(name: name.isEmpty ? null : name);
      if (!mounted) return;
      await context.push('/routines/${routine.id}');
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Routines')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'routines_ai',
            onPressed: () => context.push('/routines/generate'),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI plan'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'routines_new',
            onPressed: _createRoutine,
            icon: const Icon(Icons.add),
            label: const Text('New routine'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  void _openTemplates() => context.push('/routine-templates');

  Widget _buildBody() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _TemplateLibraryEntryCard(onTap: _openTemplates),
        const SizedBox(height: 20),
        if (_loading && _routines.isEmpty) ...[
          const SizedBox(height: 32),
          const Center(child: CircularProgressIndicator()),
        ] else if (_error != null && _routines.isEmpty) ...[
          Text(
            'Your routines',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(child: OutlinedButton(onPressed: _load, child: const Text('Retry'))),
        ] else if (_routines.isEmpty) ...[
          Text(
            'Your routines',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            'No routines yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Start from a ready-made template above, or create a blank routine.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _openTemplates,
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Browse template library'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _createRoutine,
            icon: const Icon(Icons.add),
            label: const Text('Create blank routine'),
          ),
        ] else ...[
          Text(
            'Your routines',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          ..._routines.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RoutineListCard(
                  routine: r,
                  api: api,
                  exerciseIdToMuscleGroup: _exerciseIdToMuscleGroup,
                  onTap: () async {
                    await context.push('/routines/${r.id}');
                    _load();
                  },
                ),
              )),
        ],
      ],
    );
  }
}

/// Prominent entry to pre-built routine templates (not the user's saved routines).
class _TemplateLibraryEntryCard extends StatelessWidget {
  const _TemplateLibraryEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryMuted.withValues(alpha: 0.35),
                AppColors.surface,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.library_books_outlined, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Template library',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ready-made plans (push, pull, legs…) — copy one to your routines',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutineListCard extends StatelessWidget {
  const _RoutineListCard({
    required this.routine,
    required this.api,
    required this.exerciseIdToMuscleGroup,
    required this.onTap,
  });

  final RoutineSummary routine;
  final RoutineApi api;
  final Map<String, String> exerciseIdToMuscleGroup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = routine;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '${r.exerciseCount} exercises',
                        if (r.description != null && r.description!.isNotEmpty) r.description!,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (exerciseIdToMuscleGroup.isNotEmpty)
                RoutineMusclesMiniDiagram(
                  routineId: r.id,
                  routineApi: api,
                  exerciseIdToMuscleGroup: exerciseIdToMuscleGroup,
                  viewSize: 56,
                )
              else
                const SizedBox(width: 118, height: 56),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
