import 'package:flutter/material.dart';
import 'package:gains/core/share/share_image.dart';
import 'package:gains/core/theme/app_theme.dart';
import 'package:gains/features/home/presentation/widgets/gains_identity_share_card.dart';
import 'package:gains/features/profile/models/gym_archetype.dart';
import 'package:screenshot/screenshot.dart';

Future<void> shareGainsIdentity(
  BuildContext context, {
  required GymArchetype archetype,
  int? strengthElo,
  String? strengthEloRank,
}) async {
  if (!archetype.unlocked) return;

  final primary = archetype.primaryLabel?.trim();
  if (primary == null || primary.isEmpty) return;

  final capture = ScreenshotController();
  try {
    final bytes = await capture.captureFromWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: Theme(
            data: AppTheme.dark,
            child: Material(
              type: MaterialType.transparency,
              child: GainsIdentityShareCard(
                primaryLabel: primary,
                secondaryLabel: archetype.secondaryLabel,
                description: archetype.primaryTagline,
                strengthElo: strengthElo,
                strengthEloRank: strengthEloRank,
              ),
            ),
          ),
        ),
      ),
      delay: const Duration(milliseconds: 100),
      pixelRatio: 3,
    );
    await sharePngBytes(
      bytes,
      fileName: 'gains-identity.png',
      text: 'My Gains Identity — $primary',
      sharePositionOrigin: shareOriginFromContext(context),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not share identity card')),
    );
  }
}
