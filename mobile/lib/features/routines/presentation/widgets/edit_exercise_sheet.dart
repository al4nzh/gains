import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/features/routines/data/routine_api.dart';
import 'package:gains/features/routines/models/routine_exercise.dart';
import 'package:provider/provider.dart';

class EditExerciseSheet extends StatefulWidget {
  const EditExerciseSheet({
    super.key,
    required this.routineId,
    required this.exercise,
  });

  final String routineId;
  final RoutineExercise exercise;

  static Future<bool?> show(
    BuildContext context, {
    required String routineId,
    required RoutineExercise exercise,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: EditExerciseSheet(routineId: routineId, exercise: exercise),
      ),
    );
  }

  @override
  State<EditExerciseSheet> createState() => _EditExerciseSheetState();
}

class _EditExerciseSheetState extends State<EditExerciseSheet> {
  late final TextEditingController _sets;
  late final TextEditingController _repMin;
  late final TextEditingController _repMax;
  late final TextEditingController _rest;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    _sets = TextEditingController(text: e.targetSets?.toString() ?? '');
    _repMin = TextEditingController(text: e.targetRepMin?.toString() ?? '');
    _repMax = TextEditingController(text: e.targetRepMax?.toString() ?? '');
    _rest = TextEditingController(text: e.restSeconds?.toString() ?? '');
    _notes = TextEditingController(text: e.notes ?? '');
  }

  @override
  void dispose() {
    _sets.dispose();
    _repMin.dispose();
    _repMax.dispose();
    _rest.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final api = RoutineApi(context.read<ApiClient>());
    setState(() => _saving = true);
    try {
      await api.updateExercise(
        widget.routineId,
        widget.exercise.id,
        targetSets: int.tryParse(_sets.text.trim()),
        targetRepMin: int.tryParse(_repMin.text.trim()),
        targetRepMax: int.tryParse(_repMax.text.trim()),
        restSeconds: int.tryParse(_rest.text.trim()),
        notes: _notes.text.trim(),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.exercise.exerciseName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: GainsTextField(controller: _sets, label: 'Sets', keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: GainsTextField(controller: _repMin, label: 'Rep min', keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: GainsTextField(controller: _repMax, label: 'Rep max', keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 8),
            GainsTextField(controller: _rest, label: 'Rest (sec)', keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            GainsTextField(
              controller: _notes,
              label: 'Notes',
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
