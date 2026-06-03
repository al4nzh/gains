import 'package:flutter_test/flutter_test.dart';
import 'package:gains/core/units/body_units.dart';
import 'package:gains/features/profile/models/profile.dart';

void main() {
  group('Profile.needsOnboarding', () {
    test('true when required fields missing', () {
      expect(
        const Profile(userId: '1', goal: 'strength', experience: 'beginner')
            .needsOnboarding,
        isTrue,
      );
      expect(
        const Profile(
          userId: '1',
          goal: 'strength',
          experience: 'beginner',
          activityLevel: 'moderate',
          heightCm: 180,
        ).needsOnboarding,
        isTrue,
      );
      expect(
        const Profile(
          userId: '1',
          goal: 'strength',
          experience: 'beginner',
          activityLevel: 'moderate',
          heightCm: 180,
          weightKg: 80,
        ).needsOnboarding,
        isFalse,
      );
    });
  });

  group('BodyUnits', () {
    test('parses imperial height and weight', () {
      final cm = BodyUnits.parseHeightToCm("5'10", BodyUnitSystem.imperial);
      expect(cm, closeTo(177.8, 0.5));
      final kg = BodyUnits.parseWeightToKg('180', BodyUnitSystem.imperial);
      expect(kg, closeTo(81.6, 0.5));
    });

    test('parses metric height and weight', () {
      expect(BodyUnits.parseHeightToCm('180', BodyUnitSystem.metric), 180);
      expect(BodyUnits.parseWeightToKg('80', BodyUnitSystem.metric), 80);
    });
  });
}
