import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/features/analytics/data/analytics_api.dart';
import 'package:gains/features/analytics/models/exercise_detail.dart';
import 'package:gains/features/exercises/data/exercise_api.dart';
import 'package:gains/features/exercises/models/catalog_exercise.dart';
import 'package:gains/features/workouts/data/workout_api.dart';
import 'package:gains/features/workouts/presentation/workout_plan.dart';
import 'package:provider/provider.dart';

class AddExerciseSheet extends StatefulWidget {
  const AddExerciseSheet({super.key, required this.workoutId});

  final String workoutId;

  static Future<bool?> show(BuildContext context, String workoutId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: AddExerciseSheet(workoutId: workoutId),
      ),
    );
  }

  @override
  State<AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<AddExerciseSheet> {
  final _search = TextEditingController();
  final _repsCtrls = List.generate(defaultTargetSets, (_) => TextEditingController());
  final _weightCtrls = List.generate(defaultTargetSets, (_) => TextEditingController());

  Timer? _debounce;
  List<CatalogExercise> _results = [];
  CatalogExercise? _selected;
  SetLoadSummary? _prefill;
  bool _searching = false;
  bool _loadingPrefill = false;
  bool _saving = false;

  late final ExerciseApi _exerciseApi;
  late final WorkoutApi _workoutApi;
  late final AnalyticsApi _analyticsApi;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = context.read<ApiClient>();
    _exerciseApi = ExerciseApi(client);
    _workoutApi = WorkoutApi(client);
    _analyticsApi = AnalyticsApi(client);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    for (final c in _repsCtrls) {
      c.dispose();
    }
    for (final c in _weightCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyPrefill(SetLoadSummary? prefill) {
    for (var i = 0; i < defaultTargetSets; i++) {
      _repsCtrls[i].text = prefill?.reps?.toString() ?? '';
      if (prefill?.weightKg != null) {
        final w = prefill!.weightKg!;
        _weightCtrls[i].text = w % 1 == 0 ? w.toInt().toString() : w.toString();
      } else {
        _weightCtrls[i].text = '';
      }
    }
  }

  Future<void> _selectExercise(CatalogExercise ex) async {
    setState(() {
      _selected = ex;
      _loadingPrefill = true;
    });
    try {
      final detail = await _analyticsApi.getExerciseDetail(ex.id);
      if (!mounted) return;
      _prefill = detail.lastBestSet;
      _applyPrefill(_prefill);
      setState(() => _loadingPrefill = false);
    } catch (_) {
      if (!mounted) return;
      _prefill = null;
      _applyPrefill(null);
      setState(() => _loadingPrefill = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      try {
        final items = await _exerciseApi.search(value);
        if (!mounted) return;
        setState(() {
          _results = items;
          _searching = false;
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _saveAll() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an exercise from search')),
      );
      return;
    }

    var logged = 0;
    setState(() => _saving = true);
    try {
      for (var i = 0; i < defaultTargetSets; i++) {
        final reps = int.tryParse(_repsCtrls[i].text.trim());
        final weight = double.tryParse(_weightCtrls[i].text.trim());
        if (reps == null || reps <= 0 || weight == null || weight <= 0) continue;

        await _workoutApi.addSet(
          widget.workoutId,
          exerciseId: _selected!.id,
          reps: reps,
          weightKg: weight,
          setNumber: i + 1,
        );
        logged++;
      }

      if (!mounted) return;
      if (logged == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter at least one set')),
        );
      } else {
        Navigator.pop(context, true);
      }
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add exercise',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (_selected == null) ...[
              GainsTextField(
                controller: _search,
                label: 'Search catalog',
                hint: 'e.g. bench press',
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
              ),
              if (_searching) const LinearProgressIndicator(minHeight: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final ex = _results[i];
                    return ListTile(
                      dense: true,
                      title: Text(ex.name),
                      onTap: () => _selectExercise(ex),
                    );
                  },
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected!.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _selected = null;
                      _prefill = null;
                      _results = [];
                      _search.clear();
                    }),
                    child: const Text('Change'),
                  ),
                ],
              ),
              if (_loadingPrefill)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (_prefill != null && _prefill!.hasValues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    formatLastBestSet(_prefill),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(height: 8),
              for (var i = 0; i < defaultTargetSets; i++) ...[
                Text(
                  'Set ${i + 1}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: GainsTextField(
                        controller: _repsCtrls[i],
                        label: 'Reps',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GainsTextField(
                        controller: _weightCtrls[i],
                        label: 'kg',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed: _saving ? null : _saveAll,
                child: _saving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Log sets'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
