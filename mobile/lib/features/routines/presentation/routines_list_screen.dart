import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine.dart';
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
      final list = await api.listRoutines();
      if (!mounted) return;
      setState(() {
        _routines = list;
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
          child: ListTile(
            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              [
                '${r.exerciseCount} exercises',
                if (r.description != null && r.description!.isNotEmpty) r.description!,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await context.push('/routines/${r.id}');
              _load();
            },
          ),
        );
      },
    );
  }
}
