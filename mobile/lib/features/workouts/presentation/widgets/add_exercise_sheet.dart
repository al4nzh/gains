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
import 'package:gains/features/workouts/presentation/workout_plan.dart';
import 'package:provider/provider.dart';

class AddExerciseSheet extends StatefulWidget {
  const AddExerciseSheet({super.key, required this.workoutId});

  final String workoutId;

  static Future<({CatalogExercise exercise, SetLoadSummary? prefill})?> show(
    BuildContext context,
    String workoutId,
  ) {
    return showModalBottomSheet<({CatalogExercise exercise, SetLoadSummary? prefill})>(
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

  Timer? _debounce;
  List<CatalogExercise> _results = [];
  CatalogExercise? _selected;
  SetLoadSummary? _prefill;
  bool _searching = false;
  bool _loadingPrefill = false;

  late final ExerciseApi _exerciseApi;
  late final AnalyticsApi _analyticsApi;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = context.read<ApiClient>();
    _exerciseApi = ExerciseApi(client);
    _analyticsApi = AnalyticsApi(client);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
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
      setState(() => _loadingPrefill = false);
    } catch (_) {
      if (!mounted) return;
      _prefill = null;
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

  void _addToWorkout() {
    final ex = _selected;
    if (ex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an exercise from search')),
      );
      return;
    }
    Navigator.pop(context, (exercise: ex, prefill: _prefill));
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
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _addToWorkout,
                child: const Text('Add to workout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
