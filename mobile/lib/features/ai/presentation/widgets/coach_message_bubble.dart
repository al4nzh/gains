import 'package:flutter/material.dart';
import 'package:gains/core/preferences/body_units_preference.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/units/body_units.dart';
import 'package:gains/features/ai/models/coach_message.dart';
import 'package:provider/provider.dart';

class CoachMessageBubble extends StatelessWidget {
  const CoachMessageBubble({super.key, required this.message});

  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final units = context.watch<BodyUnitsPreference>().units;
    final content = isUser ? message.content : BodyUnits.formatAiWeightUnitsInText(message.content, units);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
            color: isUser ? AppColors.onPrimary : AppColors.textPrimary,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
