import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';

class PhysiqueConfidenceChip extends StatelessWidget {
  const PhysiqueConfidenceChip({super.key, required this.confidence});

  final String confidence;

  @override
  Widget build(BuildContext context) {
    final label = confidence.isEmpty ? 'unknown' : confidence;
    Color fg;
    Color bg;
    switch (label.toLowerCase()) {
      case 'high':
        fg = AppColors.success;
        bg = AppColors.success.withValues(alpha: 0.15);
        break;
      case 'medium':
        fg = const Color(0xFFFBBF24);
        bg = const Color(0xFFFBBF24).withValues(alpha: 0.15);
        break;
      default:
        fg = AppColors.textSecondary;
        bg = AppColors.surface;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class PhysiqueDisclaimerBanner extends StatelessWidget {
  const PhysiqueDisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Estimates are for general fitness tracking only — not medical advice. Photos are analyzed and not stored.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
