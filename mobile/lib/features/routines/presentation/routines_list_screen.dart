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
      appBar: AppBar(
        title: const Text('Routines'),
        actions: [
          IconButton(
            tooltip: 'Generate with AI',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => context.push('/routines/generate'),
          ),
          IconButton(
            tooltip: 'Template library',
            icon: const Icon(Icons.library_books_outlined),
            onPressed: () => context.push('/routine-templates'),
          ),
        ],
      ),
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

  Widget _buildBody() {
    if (_loading && _routines.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _routines.isEmpty) {
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
    if (_routines.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Text(
            'No routines yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Create one or copy from a template.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: _routines.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = _routines[i];
        return Card(
          child: InkWell(
            onTap: () async {
              await context.push('/routines/${r.id}');
              _load();
            },
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
                  if (_exerciseIdToMuscleGroup.isNotEmpty)
                    RoutineMusclesMiniDiagram(
                      routineId: r.id,
                      routineApi: api,
                      exerciseIdToMuscleGroup: _exerciseIdToMuscleGroup,
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
      },
    );
  }
}
