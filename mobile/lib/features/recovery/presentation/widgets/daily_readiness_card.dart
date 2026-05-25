import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/features/recovery/data/recovery_api.dart';
import 'package:gains/features/recovery/models/recovery_checkin.dart';
import 'package:provider/provider.dart';

class DailyReadinessCard extends StatefulWidget {
  const DailyReadinessCard({
    super.key,
    required this.checkinDate,
    this.defaultCalories,
    this.defaultProtein,
    this.initialExpanded = false,
    required this.onSubmitted,
    required this.onDismissed,
  });

  final String checkinDate;
  final int? defaultCalories;
  final int? defaultProtein;
  final bool initialExpanded;
  final VoidCallback onSubmitted;
  final VoidCallback onDismissed;

  @override
  State<DailyReadinessCard> createState() => _DailyReadinessCardState();
}

class _DailyReadinessCardState extends State<DailyReadinessCard> {
  double _sleepHours = 7;
  int _energy = 3;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _notes;
  bool _expanded = false;
  bool _saving = false;

  static const _energyLabels = ['1', '2', '3', '4', '5'];

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
    _calories = TextEditingController(text: '${widget.defaultCalories ?? 2200}');
    _protein = TextEditingController(text: '${widget.defaultProtein ?? 150}');
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cals = int.tryParse(_calories.text.trim());
    final protein = int.tryParse(_protein.text.trim());
    if (cals == null || cals < 0 || protein == null || protein < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid calories and protein')),
      );
      return;
    }

    final api = RecoveryApi(context.read<ApiClient>());
    setState(() => _saving = true);
    try {
      await api.submitCheckin(
        RecoveryCheckinInput(
          checkinDate: widget.checkinDate,
          sleepHours: _sleepHours,
          energyReadiness: _energy,
          caloriesKcal: cals,
          proteinG: protein,
          notes: _notes.text.trim(),
        ),
      );
      if (!mounted) return;
      widget.onSubmitted();
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
    return Card(
      color: AppColors.primaryMuted.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Readiness',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last night\'s sleep, today\'s energy, yesterday\'s nutrition.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Not now',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onDismissed,
                ),
              ],
            ),
            if (!_expanded) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onDismissed,
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _expanded = true),
                      child: const Text('Log now'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'Sleep last night',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _sleepHours.clamp(0, 24),
                      min: 0,
                      max: 24,
                      divisions: 48,
                      label: '${_sleepHours.toStringAsFixed(1)} h',
                      onChanged: (v) => setState(() => _sleepHours = (v * 2).round() / 2),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${_sleepHours.toStringAsFixed(1)}h',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Energy today',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 5 ? 6 : 0),
                        child: ChoiceChip(
                          label: Center(child: Text(_energyLabels[i - 1])),
                          selected: _energy == i,
                          onSelected: (_) => setState(() => _energy = i),
                          selectedColor: AppColors.primaryMuted.withValues(alpha: 0.5),
                          side: BorderSide(
                            color: _energy == i ? AppColors.primary : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Low', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  Text('High', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Yesterday\'s nutrition',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GainsTextField(
                      controller: _calories,
                      label: 'Calories',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GainsTextField(
                      controller: _protein,
                      label: 'Protein (g)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GainsTextField(
                controller: _notes,
                label: 'Notes (optional)',
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save check-in'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
