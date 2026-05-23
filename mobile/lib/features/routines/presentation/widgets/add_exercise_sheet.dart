import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/features/exercises/data/exercise_api.dart';
import 'package:gains/features/exercises/models/catalog_exercise.dart';
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
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: AddExerciseSheet(routineId: routineId),
      ),
    );
  }

  @override
  State<AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<AddExerciseSheet> {
  final _search = TextEditingController();
  final _sets = TextEditingController(text: '3');
  final _repMin = TextEditingController(text: '8');
  final _repMax = TextEditingController(text: '12');
  final _rest = TextEditingController(text: '120');

  Timer? _debounce;
  List<CatalogExercise> _results = [];
  CatalogExercise? _selected;
  bool _searching = false;
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
    _debounce?.cancel();
    _search.dispose();
    _sets.dispose();
    _repMin.dispose();
    _repMax.dispose();
    _rest.dispose();
    super.dispose();
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
        if (!mounted) return;
        setState(() => _searching = false);
      }
    });
  }

  Future<void> _save() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an exercise from search')),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add exercise',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            GainsTextField(
              controller: _search,
              label: 'Search catalog',
              hint: 'e.g. bench press',
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
            ),
            if (_searching) const LinearProgressIndicator(minHeight: 2),
            if (_selected != null) ...[
              const SizedBox(height: 8),
              Text(
                'Selected: ${_selected!.name}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
              ),
            ],
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
                    subtitle: Text(
                      [ex.muscleGroup, ex.equipment].whereType<String>().join(' · '),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    onTap: () => setState(() => _selected = ex),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GainsTextField(
                    controller: _sets,
                    label: 'Sets',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GainsTextField(
                    controller: _repMin,
                    label: 'Rep min',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GainsTextField(
                    controller: _repMax,
                    label: 'Rep max',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GainsTextField(
              controller: _rest,
              label: 'Rest (seconds)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
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
        ),
      ),
    );
  }
}
