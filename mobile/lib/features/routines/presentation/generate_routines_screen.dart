import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/features/ai/data/ai_api.dart';
import 'package:gains/features/ai/models/clarification.dart';
import 'package:gains/features/ai/models/routine_draft.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:gains/features/routines/presentation/routine_formatters.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:gains/features/subscription/presentation/premium_locked_view.dart';
import 'package:gains/features/subscription/services/subscription_service.dart';
import 'package:gains/features/subscription/utils/premium_errors.dart';
import 'package:provider/provider.dart';

enum _GeneratePhase { prompt, loading, clarification, preview, confirming }

class GenerateRoutinesScreen extends StatefulWidget {
  const GenerateRoutinesScreen({super.key});

  @override
  State<GenerateRoutinesScreen> createState() => _GenerateRoutinesScreenState();
}

class _GenerateRoutinesScreenState extends State<GenerateRoutinesScreen> {
  final _messageController = TextEditingController();
  AiApi? _api;

  _GeneratePhase _phase = _GeneratePhase.prompt;
  AiClarification? _clarification;
  String? _draftId;
  String? _planTitle;
  List<DraftRoutine> _previewRoutines = [];

  AiApi get api => _api ??= AiApi(context.read<ApiClient>());

  String _aiErrorMessage(ApiException e) {
    if (e.statusCode == 503) {
      return 'AI is unavailable (server needs OPENAI_API_KEY).';
    }
    return e.message;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe the plan you want')),
      );
      return;
    }

    setState(() {
      _phase = _GeneratePhase.loading;
      _clarification = null;
    });

    try {
      final result = await api.generateRoutines(message);
      if (!mounted) return;

      if (result.isClarification) {
        setState(() {
          _phase = _GeneratePhase.clarification;
          _clarification = result.clarification;
        });
        return;
      }

      setState(() {
        _phase = _GeneratePhase.preview;
        _draftId = result.draftId;
        _planTitle = result.title;
        _previewRoutines = result.routines ?? [];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _phase = _GeneratePhase.prompt);
      if (e.isPremiumRequired) {
        await showPaywallForApiError(context, e);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_aiErrorMessage(e))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _GeneratePhase.prompt);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not generate routines')),
      );
    }
  }

  Future<void> _confirm() async {
    final draftId = _draftId;
    if (draftId == null) return;

    setState(() => _phase = _GeneratePhase.confirming);

    try {
      await api.confirmRoutineDraft(draftId);
      if (!mounted) return;

      context.read<ShellTabRefresh>().bump(ShellTab.routines);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${_previewRoutines.length} routine${_previewRoutines.length == 1 ? '' : 's'}',
          ),
        ),
      );
      context.go('/routines');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _phase = _GeneratePhase.preview);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_aiErrorMessage(e))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _GeneratePhase.preview);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save routines')),
      );
    }
  }

  void _backToPrompt() {
    setState(() {
      _phase = _GeneratePhase.prompt;
      _clarification = null;
      _draftId = null;
      _planTitle = null;
      _previewRoutines = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SubscriptionService>().isPremium) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Generate with AI'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: const PremiumLockedView(
          title: 'AI routine generator is Premium',
          description:
              'Describe your goals and get a full program draft. Building routines manually from templates stays free.',
          icon: Icons.auto_awesome_outlined,
        ),
      );
    }

    final needsProfile = context.watch<AuthSession>().needsOnboarding;
    final loading = _phase == _GeneratePhase.loading || _phase == _GeneratePhase.confirming;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Generate with AI'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: loading ? null : () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              if (needsProfile) ...[
                Card(
                  color: AppColors.primaryMuted.withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete your profile first',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Goal, experience, and activity level help the AI build a better plan.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => context.push('/onboarding'),
                          child: const Text('Finish profile'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_phase == _GeneratePhase.prompt ||
                  _phase == _GeneratePhase.clarification) ...[
                Text(
                  'Describe your plan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Example: 4-day upper/lower for strength, shoulder-friendly pressing.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),
                GainsTextField(
                  controller: _messageController,
                  label: 'Your request',
                  hint: '4-day upper/lower, 60 min sessions…',
                  minLines: 3,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                ),
                if (_phase == _GeneratePhase.clarification && _clarification != null) ...[
                  const SizedBox(height: 20),
                  _ClarificationCard(clarification: _clarification!),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: needsProfile || loading ? null : _generate,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      _phase == _GeneratePhase.clarification ? 'Try again' : 'Generate plan',
                    ),
                  ),
                ),
              ],
              if (_phase == _GeneratePhase.preview) ...[
                Text(
                  _planTitle ?? 'Preview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review before saving — nothing is stored until you confirm.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),
                ..._previewRoutines.map((r) => _DraftRoutineCard(routine: r)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: loading ? null : _backToPrompt,
                  child: const Text('Edit request'),
                ),
              ],
            ],
          ),
          if (loading)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('AI is building your plan…'),
                        SizedBox(height: 4),
                        Text(
                          'This can take up to a minute',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _phase == _GeneratePhase.preview
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : _confirm,
                        child: const Text('Confirm & save routines'),
                      ),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _ClarificationCard extends StatelessWidget {
  const _ClarificationCard({required this.clarification});

  final AiClarification clarification;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Need clarification',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(clarification.message),
            if (clarification.possibleMatches.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Did you mean:',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              ...clarification.possibleMatches.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${m.exerciseName}', style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DraftRoutineCard extends StatelessWidget {
  const _DraftRoutineCard({required this.routine});

  final DraftRoutine routine;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              routine.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            if (routine.description != null && routine.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                routine.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            ...routine.exercises.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(e.exerciseName),
                subtitle: Text(
                  exerciseLineSubtitle(
                    sets: e.targetSets,
                    repMin: e.targetRepMin,
                    repMax: e.targetRepMax,
                    restSeconds: e.restSeconds,
                  ),
                ),
                trailing: e.notes != null && e.notes!.isNotEmpty
                    ? IconButton(
                        tooltip: e.notes,
                        icon: const Icon(Icons.notes_outlined, size: 18),
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(e.exerciseName),
                              content: Text(e.notes!),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
