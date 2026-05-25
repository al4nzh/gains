import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/analytics/models/exercise_detail.dart';

String formatE1rmKg(double kg) => '${kg.toStringAsFixed(1)} kg';

String formatSetLoad(SetLoadSummary? set) {
  if (set == null || !set.hasValues) return '—';
  return '${set.reps} × ${set.weightKg!.toStringAsFixed(1)} kg';
}

String formatE1rmDelta(double kg, {double? pct}) {
  final sign = kg > 0 ? '+' : '';
  final base = '$sign${kg.toStringAsFixed(1)} kg';
  if (pct == null) return base;
  final pctSign = pct > 0 ? '+' : '';
  return '$base ($pctSign${pct.toStringAsFixed(1)}%)';
}

String formatTrendLabel(String trend) {
  switch (trend) {
    case 'up':
      return 'Trending up';
    case 'down':
      return 'Trending down';
    case 'flat':
      return 'Flat';
    case 'single_session':
      return 'First session';
    case 'no_data':
      return 'No data';
    default:
      return trend;
  }
}

IconData trendIcon(String trend) {
  switch (trend) {
    case 'up':
      return Icons.trending_up;
    case 'down':
      return Icons.trending_down;
    case 'flat':
      return Icons.trending_flat;
    default:
      return Icons.show_chart;
  }
}

Color trendColor(String trend) {
  switch (trend) {
    case 'up':
      return AppColors.success;
    case 'down':
      return AppColors.error;
    default:
      return AppColors.textMuted;
  }
}

Color e1rmChangeColor(double kg) {
  if (kg > 0) return AppColors.success;
  if (kg < 0) return AppColors.error;
  return AppColors.textSecondary;
}
