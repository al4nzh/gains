import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine_template.dart';
import 'package:provider/provider.dart';

/// First-run prompt after profile setup: copy a template or start a workout.
Future<void> showGettingStartedSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _GettingStartedSheet(),
  );
}

class _GettingStartedSheet extends StatefulWidget {
  const _GettingStartedSheet();

  @override
  State<_GettingStartedSheet> createState() => _GettingStartedSheetState();
}

class _GettingStartedSheetState extends State<_GettingStartedSheet> {
  RoutineApi? _api;
  List<RoutineTemplateSummary> _templates = [];
  bool _loading = true;
  String? _error;
  String? _busyTemplateId;

  RoutineApi get api => _api ??= RoutineApi(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await api.listTemplates();
      if (!mounted) return;
      setState(() {
        _templates = list.take(4).toList();
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

  Future<void> _useTemplate(RoutineTemplateSummary t) async {
    setState(() => _busyTemplateId = t.id);
    try {
      final routine = await api.copyTemplate(t.id);
      if (!mounted) return;
      Navigator.pop(context);
      context.push('/train/start?routineId=${routine.id}');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busyTemplateId = null);
    }
  }

  void _startEmpty() {
    Navigator.pop(context);
    context.push('/train/start');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'You\'re set up',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a quick way to log your first session.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              )
            else
              ..._templates.map((t) {
                final busy = _busyTemplateId == t.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _useTemplate(t),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (t.description != null && t.description!.isNotEmpty)
                                  Text(
                                    t.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          if (busy)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Text(
                              '${t.exerciseCount} ex',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busyTemplateId != null ? null : _startEmpty,
              child: const Text('Start empty workout'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Explore home first'),
            ),
          ],
        ),
      ),
    );
  }
}
