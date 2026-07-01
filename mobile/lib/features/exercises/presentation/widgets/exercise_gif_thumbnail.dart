import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/exercises/exercise_gif_url.dart';
import 'package:provider/provider.dart';
import 'package:gains/core/api/api_client.dart';

/// ExerciseDB demo GIF for workout exercise rows.
const double kWorkoutExerciseGifSize = 80;

/// Small ExerciseDB demo GIF for workout exercise rows.
class ExerciseGifThumbnail extends StatelessWidget {
  const ExerciseGifThumbnail({
    super.key,
    this.gifUrl,
    this.size = 72,
    this.width,
    this.height,
  });

  final String? gifUrl;
  final double size;
  final double? width;
  final double? height;

  double get _width => width ?? size;
  double get _height => height ?? size;

  @override
  Widget build(BuildContext context) {
    final raw = gifUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return SizedBox(
        width: _width,
        height: _height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.fitness_center, color: AppColors.textMuted, size: size * 0.4),
        ),
      );
    }

    final apiBase = context.read<ApiClient>().baseUrl;
    final url = resolveExerciseGifUrl(apiBase, raw);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: _width,
        height: _height,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const ColoredBox(
              color: AppColors.surface,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: AppColors.surface,
            child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
