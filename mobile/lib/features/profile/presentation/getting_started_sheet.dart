import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:gains/features/profile/models/profile.dart';
import 'package:gains/features/profile/models/starter_plan_recommendation.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine_template.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

/// First-run prompt after onboarding: personalized starter plan from templates.
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
  StarterPlanRecommendation? _plan;
  List<RoutineTemplateSummary> _planTemplates = const [];
  RoutineTemplateSummary? _firstTemplate;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  RoutineApi get api => _api ??= RoutineApi(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = context.read<AuthSession>().profile;
      final plan = recommendStarterPlan(profile ?? const Profile(userId: ''));
      final all = await api.listTemplates();
      final resolved = resolveStarterTemplates(all, plan);
      RoutineTemplateSummary? first;
      for (final template in resolved) {
        if (template.id == plan.firstTemplateId) {
          first = template;
          break;
        }
      }
      first ??= resolved.isNotEmpty ? resolved.first : null;
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _planTemplates = resolved;
        _firstTemplate = first;
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
        _error = 'Could not load starter plan';
        _loading = false;
      });
    }
  }

  Future<void> _addProgram() async {
    if (_planTemplates.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final template in _planTemplates) {
        await api.copyTemplate(template.id);
      }
      if (!mounted) return;
      Navigator.pop(context);
      context.read<ShellTabRefresh>().bump(ShellTab.routines);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _planTemplates.length == 1
                ? 'Routine added'
                : '${_planTemplates.length} routines added',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startFirstOnly() async {
    final first = _firstTemplate ?? (_planTemplates.isNotEmpty ? _planTemplates.first : null);
    if (first == null) return;
    setState(() => _busy = true);
    try {
      final routine = await api.copyTemplate(first.id);
      if (!mounted) return;
      Navigator.pop(context);
      context.read<ShellTabRefresh>().bump(ShellTab.routines);
      context.push('/train/start?routineId=${routine.id}');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthSession>().profile;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final plan = _plan;
    final first = _firstTemplate;

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
              'Your starter plan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (profile != null)
              Text(
                starterPlanContextLine(profile),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              )
            else if (plan != null) ...[
              Text(
                plan.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                plan.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              ..._planTemplates.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fitness_center, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                ),
                            ],
                          ),
                        ),
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
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy || _planTemplates.isEmpty ? null : _addProgram,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _planTemplates.length == 1
                            ? 'Add to my routines'
                            : 'Add all ${_planTemplates.length} to my routines',
                      ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy || first == null ? null : _startFirstOnly,
                child: Text('Start ${first?.name ?? 'workout'} now'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Explore home first'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
