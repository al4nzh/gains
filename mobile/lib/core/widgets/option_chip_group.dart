import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';

class OptionChipGroup extends StatelessWidget {
  const OptionChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(String, String)> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          FilterChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
            selectedColor: AppColors.primaryMuted.withValues(alpha: 0.5),
            checkmarkColor: AppColors.onPrimary,
            side: BorderSide(
              color: selected == value ? AppColors.primary : AppColors.border,
            ),
          ),
      ],
    );
  }
}
