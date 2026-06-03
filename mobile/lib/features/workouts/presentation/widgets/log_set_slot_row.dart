import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/features/analytics/models/exercise_detail.dart';
import 'package:gains/features/workouts/data/workout_api.dart';
import 'package:gains/features/workouts/models/workout_set.dart';
import 'package:provider/provider.dart';

class LogSetSlotRow extends StatefulWidget {
  const LogSetSlotRow({
    super.key,
    required this.workoutId,
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    this.logged,
    this.prefill,
    this.draftReps,
    this.draftWeight,
    required this.onDraftChanged,
    required this.onSetSaved,
    required this.onSetDeleted,
  });

  final String workoutId;
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final WorkoutSet? logged;
  final SetLoadSummary? prefill;
  final String? draftReps;
  final String? draftWeight;
  final void Function(String reps, String weight) onDraftChanged;
  final void Function(WorkoutSet set) onSetSaved;
  final VoidCallback onSetDeleted;

  @override
  State<LogSetSlotRow> createState() => _LogSetSlotRowState();
}

class _LogSetSlotRowState extends State<LogSetSlotRow> with AutomaticKeepAliveClientMixin {
  static const _minSavingVisible = Duration(milliseconds: 400);

  late final TextEditingController _reps;
  late final TextEditingController _weight;
  bool _saving = false;
  bool _suppressDraftNotify = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: _resolveReps());
    _weight = TextEditingController(text: _resolveWeight());
    _reps.addListener(_notifyDraft);
    _weight.addListener(_notifyDraft);
  }

  @override
  void didUpdateWidget(LogSetSlotRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logged?.id != widget.logged?.id) {
      _setTextSilently(_reps, _resolveReps());
      _setTextSilently(_weight, _resolveWeight());
    } else if (widget.draftReps != oldWidget.draftReps && widget.draftReps != _reps.text) {
      _setTextSilently(_reps, widget.draftReps ?? _resolveReps());
    } else if (widget.draftWeight != oldWidget.draftWeight && widget.draftWeight != _weight.text) {
      _setTextSilently(_weight, widget.draftWeight ?? _resolveWeight());
    }
  }

  void _notifyDraft() {
    if (_suppressDraftNotify) return;
    widget.onDraftChanged(_reps.text, _weight.text);
  }

  void _setTextSilently(TextEditingController c, String next) {
    if (c.text == next) return;
    _suppressDraftNotify = true;
    final selection = TextSelection.collapsed(offset: next.length);
    c.value = TextEditingValue(
      text: next,
      selection: selection,
      composing: TextRange.empty,
    );
    _suppressDraftNotify = false;
  }

  String _resolveReps() {
    if (widget.draftReps != null && widget.draftReps!.isNotEmpty) return widget.draftReps!;
    if (widget.logged != null) return widget.logged!.reps.toString();
    if (widget.prefill?.reps != null) return widget.prefill!.reps.toString();
    return '';
  }

  String _resolveWeight() {
    if (widget.draftWeight != null && widget.draftWeight!.isNotEmpty) return widget.draftWeight!;
    if (widget.logged != null) {
      final w = widget.logged!.weightKg;
      return w % 1 == 0 ? w.toInt().toString() : w.toString();
    }
    if (widget.prefill?.weightKg != null) {
      final w = widget.prefill!.weightKg!;
      return w % 1 == 0 ? w.toInt().toString() : w.toString();
    }
    return '';
  }

  @override
  void dispose() {
    _reps.removeListener(_notifyDraft);
    _weight.removeListener(_notifyDraft);
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _waitMinSavingDuration(DateTime started) async {
    final elapsed = DateTime.now().difference(started);
    final remaining = _minSavingVisible - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  Future<void> _save() async {
    final reps = int.tryParse(_reps.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    if (reps == null || reps <= 0 || weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid reps and weight')),
      );
      return;
    }

    final api = WorkoutApi(context.read<ApiClient>());
    final started = DateTime.now();
    setState(() => _saving = true);
    try {
      final saved = widget.logged != null
          ? await api.updateSet(
              widget.workoutId,
              widget.logged!.id,
              reps: reps,
              weightKg: weight,
            )
          : await api.addSet(
              widget.workoutId,
              exerciseId: widget.exerciseId,
              reps: reps,
              weightKg: weight,
              setNumber: widget.setNumber,
            );
      await _waitMinSavingDuration(started);
      if (!mounted) return;
      widget.onSetSaved(saved);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final set = widget.logged;
    if (set == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove set?'),
        content: Text('Remove set ${set.setNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final api = WorkoutApi(context.read<ApiClient>());
    final started = DateTime.now();
    setState(() => _saving = true);
    try {
      await api.deleteSet(widget.workoutId, set.id);
      await _waitMinSavingDuration(started);
      if (!mounted) return;
      widget.onSetDeleted();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isLogged = widget.logged != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 52,
              child: Text(
                'Set ${widget.setNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: AnimatedOpacity(
                opacity: _saving ? 0.5 : 1,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: _saving,
                  child: GainsTextField(
                    controller: _reps,
                    label: 'Reps',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedOpacity(
                opacity: _saving ? 0.5 : 1,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: _saving,
                  child: GainsTextField(
                    controller: _weight,
                    label: 'kg',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _LogSetActionButton(
              saving: _saving,
              isLogged: isLogged,
              onPressed: _save,
            ),
            if (isLogged)
              AnimatedOpacity(
                opacity: _saving ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: _saving,
                  child: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
                    onPressed: _delete,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogSetActionButton extends StatelessWidget {
  const _LogSetActionButton({
    required this.saving,
    required this.isLogged,
    required this.onPressed,
  });

  final bool saving;
  final bool isLogged;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SizedBox(
        height: 40,
        child: FilledButton(
          onPressed: saving ? null : onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(84, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: saving
                ? SizedBox(
                    key: const ValueKey('saving'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.25,
                      color: onPrimary,
                    ),
                  )
                : Row(
                    key: const ValueKey('idle'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isLogged ? Icons.check : Icons.add, size: 18),
                      const SizedBox(width: 6),
                      Text(isLogged ? 'Update' : 'Log'),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
