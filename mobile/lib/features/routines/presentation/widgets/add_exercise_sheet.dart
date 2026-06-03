import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/features/exercises/data/exercise_api.dart';
import 'package:gains/features/exercises/models/catalog_exercise.dart';
import 'package:gains/features/exercises/presentation/widgets/catalog_exercise_picker.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:provider/provider.dart';

class AddExerciseSheet extends StatefulWidget {
  const AddExerciseSheet({super.key, required this.routineId});

  final String routineId;

  static Future<bool?> show(BuildContext context, String routineId) {
    return showModalBottomSheet<bool>(
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
            child: AddExerciseSheet(routineId: routineId),
          ),
        );
      },
    );
  }

  @override
  State<AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<AddExerciseSheet> {
  final _sets = TextEditingController(text: '3');
  final _repMin = TextEditingController(text: '8');
  final _repMax = TextEditingController(text: '12');
  final _rest = TextEditingController(text: '120');

  CatalogExercise? _selected;
  bool _saving = false;

  late final ExerciseApi _exerciseApi;
  late final RoutineApi _routineApi;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = context.read<ApiClient>();
    _exerciseApi = ExerciseApi(client);
    _routineApi = RoutineApi(client);
  }

  @override
  void dispose() {
    _sets.dispose();
    _repMin.dispose();
    _repMax.dispose();
    _rest.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an exercise from the list')),
      );
      return;
    }

    final sets = int.tryParse(_sets.text.trim());
    final repMin = int.tryParse(_repMin.text.trim());
    final repMax = int.tryParse(_repMax.text.trim());
    final rest = int.tryParse(_rest.text.trim());

    setState(() => _saving = true);
    try {
      await _routineApi.addExercise(
        widget.routineId,
        exerciseId: _selected!.id,
        targetSets: sets,
        targetRepMin: repMin,
        targetRepMax: repMax,
        restSeconds: rest,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
    final listHeight = MediaQuery.sizeOf(context).height * 0.34;

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
                      onSelected: (ex) => setState(() => _selected = ex),
                    ),
                  ] else ...[
                    _SelectedExerciseHeader(
                      exercise: _selected!,
                      onChange: () => setState(() => _selected = null),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Prescription',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    _PrescriptionFields(
                      sets: _sets,
                      repMin: _repMin,
                      repMax: _repMax,
                      rest: _rest,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add to routine'),
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

class _SelectedExerciseHeader extends StatelessWidget {
  const _SelectedExerciseHeader({required this.exercise, required this.onChange});

  final CatalogExercise exercise;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final meta = [exercise.muscleGroup, exercise.equipment].whereType<String>().join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(onPressed: onChange, child: const Text('Change')),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionFields extends StatelessWidget {
  const _PrescriptionFields({
    required this.sets,
    required this.repMin,
    required this.repMax,
    required this.rest,
  });

  final TextEditingController sets;
  final TextEditingController repMin;
  final TextEditingController repMax;
  final TextEditingController rest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: GainsTextField(
                controller: sets,
                label: 'Sets',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GainsTextField(
                controller: rest,
                label: 'Rest (sec)',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GainsTextField(
                controller: repMin,
                label: 'Rep min',
                keyboardType: TextInputType.number,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 28, 12, 0),
              child: Text(
                '–',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted),
              ),
            ),
            Expanded(
              child: GainsTextField(
                controller: repMax,
                label: 'Rep max',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
