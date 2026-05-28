import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/exercises/presentation/widgets/exercise_gif_thumbnail.dart';

class WorkoutExerciseHeader extends StatelessWidget {
  const WorkoutExerciseHeader({
    super.key,
    required this.exerciseName,
    this.gifUrl,
    this.subtitleLines = const [],
    this.gifSize = kWorkoutExerciseGifSize,
  });

  final String exerciseName;
  final String? gifUrl;
  final List<Widget> subtitleLines;
  final double gifSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExerciseGifThumbnail(gifUrl: gifUrl, size: gifSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exerciseName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                ...subtitleLines,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds muted subtitle text lines for rep range / last best set.
Widget workoutExerciseSubtitle(BuildContext context, String text, {Color? color}) {
  return Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color ?? AppColors.textMuted,
        ),
  );
}
