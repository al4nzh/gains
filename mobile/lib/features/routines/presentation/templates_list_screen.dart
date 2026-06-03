import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/exercises/data/exercise_api.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine_template.dart';
import 'package:gains/features/routines/presentation/widgets/template_muscles_mini_diagram.dart';
import 'package:provider/provider.dart';

class TemplatesListScreen extends StatefulWidget {
  const TemplatesListScreen({super.key});

  @override
  State<TemplatesListScreen> createState() => _TemplatesListScreenState();
}

class _TemplatesListScreenState extends State<TemplatesListScreen> {
  RoutineApi? _api;
  List<RoutineTemplateSummary> _templates = [];
  Map<String, String> _exerciseIdToMuscleGroup = {};
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
      final client = context.read<ApiClient>();
      final listFuture = api.listTemplates();
      final muscleMapFuture = ExerciseApi(client).loadMuscleGroupMap();

      final list = await listFuture;
      final muscleMap = await muscleMapFuture;
      if (!mounted) return;
      setState(() {
        _templates = list;
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
        _error = 'Could not load templates';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Template library')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _templates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _templates.isEmpty) {
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
    if (_templates.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Text(
            'No templates available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = _templates[i];
        return _TemplateListCard(
          template: t,
          api: api,
          exerciseIdToMuscleGroup: _exerciseIdToMuscleGroup,
          onTap: () => context.push('/routine-templates/${t.id}'),
        );
      },
    );
  }
}

class _TemplateListCard extends StatelessWidget {
  const _TemplateListCard({
    required this.template,
    required this.api,
    required this.exerciseIdToMuscleGroup,
    required this.onTap,
  });

  final RoutineTemplateSummary template;
  final RoutineApi api;
  final Map<String, String> exerciseIdToMuscleGroup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = template;
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
                      t.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '${t.exerciseCount} exercises',
                        if (t.description != null && t.description!.isNotEmpty) t.description!,
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
                TemplateMusclesMiniDiagram(
                  templateId: t.id,
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
