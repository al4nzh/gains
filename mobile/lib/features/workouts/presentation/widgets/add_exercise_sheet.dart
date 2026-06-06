import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/analytics/data/analytics_api.dart';
import 'package:gains/features/analytics/models/exercise_detail.dart';
import 'package:gains/features/exercises/data/exercise_api.dart';
import 'package:gains/features/exercises/models/catalog_exercise.dart';
import 'package:gains/features/exercises/presentation/widgets/catalog_exercise_picker.dart';
import 'package:gains/core/preferences/body_units_preference.dart';
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
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(
            height: height * 0.88,
            child: AddExerciseSheet(workoutId: workoutId),
          ),
        );
      },
    );
  }

  @override
  State<AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<AddExerciseSheet> {
  CatalogExercise? _selected;
  SetLoadSummary? _prefill;
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

  void _addToWorkout() {
    final ex = _selected;
    if (ex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an exercise from the list')),
      );
      return;
    }
    Navigator.pop(context, (exercise: ex, prefill: _prefill));
  }

  @override
  Widget build(BuildContext context) {
    final listHeight = MediaQuery.sizeOf(context).height * 0.34;
    final units = context.watch<BodyUnitsPreference>().units;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add exercise',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  if (_selected == null) ...[
                    CatalogExercisePicker(
                      exerciseApi: _exerciseApi,
                      maxListHeight: listHeight,
                      onSelected: _selectExercise,
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
                          formatLastBestSet(_prefill, units),
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
          ),
        ],
      ),
    );
  }
}
