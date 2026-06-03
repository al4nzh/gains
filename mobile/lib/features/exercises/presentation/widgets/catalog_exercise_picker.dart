import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/core/widgets/option_chip_group.dart';
import 'package:gains/features/exercises/data/exercise_api.dart';
import 'package:gains/features/exercises/models/catalog_exercise.dart';
import 'package:gains/features/exercises/models/catalog_muscle_groups.dart';

/// Search catalog exercises by muscle group and/or name.
class CatalogExercisePicker extends StatefulWidget {
  const CatalogExercisePicker({
    super.key,
    required this.exerciseApi,
    this.onSelected,
    this.selected,
    this.maxListHeight = 200,
  });

  final ExerciseApi exerciseApi;
  final ValueChanged<CatalogExercise>? onSelected;
  final CatalogExercise? selected;
  final double maxListHeight;

  @override
  State<CatalogExercisePicker> createState() => _CatalogExercisePickerState();
}

class _CatalogExercisePickerState extends State<CatalogExercisePicker> {
  final _search = TextEditingController();

  Timer? _debounce;
  String? _muscleGroup;
  List<CatalogExercise> _groupExercises = [];
  List<CatalogExercise> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadByMuscleGroup(String group) async {
    setState(() {
      _muscleGroup = group;
      _loading = true;
      _groupExercises = [];
      _results = [];
    });
    try {
      final items = await widget.exerciseApi.list(muscleGroup: group, limit: 100);
      if (!mounted) return;
      setState(() {
        _groupExercises = items;
        _results = _applyLocalFilter(items, _search.text);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.message);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onMuscleGroupSelected(String group) {
    _search.clear();
    _loadByMuscleGroup(group);
  }

  void _clearMuscleGroup() {
    setState(() {
      _muscleGroup = null;
      _groupExercises = [];
      _results = [];
    });
    _refreshGlobalSearch(_search.text);
  }

  List<CatalogExercise> _applyLocalFilter(List<CatalogExercise> items, String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return items;
    return items.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();

    if (_muscleGroup != null) {
      if (trimmed.length < 2) {
        setState(() => _results = _groupExercises);
        return;
      }
      _debounce = Timer(const Duration(milliseconds: 350), () async {
        setState(() => _loading = true);
        try {
          final items = await widget.exerciseApi.search(
            trimmed,
            muscleGroup: _muscleGroup,
          );
          if (!mounted) return;
          setState(() {
            _results = items;
            _loading = false;
          });
        } on ApiException catch (e) {
          if (!mounted) return;
          setState(() => _loading = false);
          _showError(e.message);
        } catch (_) {
          if (mounted) setState(() => _loading = false);
        }
      });
      return;
    }

    if (trimmed.length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () => _refreshGlobalSearch(trimmed));
  }

  Future<void> _refreshGlobalSearch(String query) async {
    setState(() => _loading = true);
    try {
      final items = await widget.exerciseApi.search(query);
      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.message);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hint = _muscleGroup == null
        ? 'Pick a muscle group above, or type 2+ letters to search'
        : 'Optional: narrow list by name';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Muscle group', style: Theme.of(context).textTheme.labelLarge),
            ),
            if (_muscleGroup != null)
              TextButton(
                onPressed: _clearMuscleGroup,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        OptionChipGroup(
          options: CatalogMuscleGroups.options,
          selected: _muscleGroup,
          onSelected: _onMuscleGroupSelected,
        ),
        const SizedBox(height: 16),
        GainsTextField(
          controller: _search,
          label: 'Search',
          hint: hint,
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (widget.selected != null) ...[
          const SizedBox(height: 8),
          Text(
            'Selected: ${widget.selected!.name}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
          ),
        ],
        if (_results.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _muscleGroup == null
                  ? 'Select a group or search by exercise name.'
                  : 'No exercises in this group.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
        if (_results.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxListHeight),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final ex = _results[i];
                final selected = widget.selected?.id == ex.id;
                return ListTile(
                  dense: true,
                  selected: selected,
                  title: Text(ex.name),
                  subtitle: Text(
                    [ex.muscleGroup, ex.equipment].whereType<String>().join(' · '),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  onTap: () => widget.onSelected?.call(ex),
                );
              },
            ),
          ),
      ],
    );
  }
}
