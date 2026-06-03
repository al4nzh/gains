import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';
import 'package:gains/features/exercises/data/exercise_api.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine_template.dart';
import 'package:gains/features/routines/presentation/routine_formatters.dart';
import 'package:gains/features/routines/presentation/widgets/routine_dialogs.dart';
import 'package:gains/features/workouts/presentation/muscle_group_mapping.dart';
import 'package:gains/features/workouts/presentation/widgets/session_muscles_diagram.dart';
import 'package:provider/provider.dart';

class TemplateDetailScreen extends StatefulWidget {
  const TemplateDetailScreen({super.key, required this.templateId});

  final String templateId;

  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<TemplateDetailScreen> {
  RoutineApi? _api;
  RoutineTemplate? _template;
  Set<Muscle> _highlightedMuscles = {};
  List<String> _trainedGroupLabels = [];
  String? _error;
  bool _loading = true;
  bool _copying = false;

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
      final templateFuture = api.getTemplate(widget.templateId);
      final muscleMapFuture = ExerciseApi(client).loadMuscleGroupMap();
      final template = await templateFuture;
      final muscleMap = await muscleMapFuture;
      if (!mounted) return;
      final exerciseIds = template.exercises.map((e) => e.exerciseId).toSet();
      final groups = catalogMuscleGroupsForExerciseIds(
        exerciseIds: exerciseIds,
        exerciseIdToMuscleGroup: muscleMap,
      );
      final highlighted = highlightedMusclesForExerciseIds(
        exerciseIds: exerciseIds,
        exerciseIdToMuscleGroup: muscleMap,
      );
      setState(() {
        _template = template;
        _highlightedMuscles = highlighted;
        _trainedGroupLabels = trainedGroupLabelsFromIds(groups);
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
        _error = 'Could not load template';
        _loading = false;
      });
    }
  }

  Future<void> _useTemplate() async {
    final t = _template;
    if (t == null || _copying) return;

    final name = await promptRoutineName(context, initial: t.name);
    if (!mounted || name == null) return;

    setState(() => _copying = true);
    try {
      final routine = await api.copyTemplate(
        widget.templateId,
        name: name.isEmpty ? null : name,
      );
      if (!mounted) return;
      context.pushReplacement('/routines/${routine.id}');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _template;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(t?.name ?? 'Template')),
      bottomNavigationBar: t == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ElevatedButton(
                  onPressed: _copying ? null : _useTemplate,
                  child: _copying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Use this template'),
                ),
              ),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _template == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _template == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final t = _template!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (t.description != null && t.description!.isNotEmpty) ...[
          Text(
            t.description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          '${t.exerciseCount} exercises',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
        ),
        if (t.exercises.isNotEmpty) ...[
          const SizedBox(height: 16),
          SessionMusclesDiagram(
            title: 'Muscles targeted by this template',
            highlightedMuscles: _highlightedMuscles,
            trainedGroupLabels: _trainedGroupLabels,
          ),
        ],
        const SizedBox(height: 12),
        ...t.exercises.map((e) {
          final subtitle = templateExerciseSubtitle(e);
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
            ),
          );
        }),
        const SizedBox(height: 72),
      ],
    );
  }
}
