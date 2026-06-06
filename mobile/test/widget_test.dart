import 'package:flutter_test/flutter_test.dart';
import 'package:gains/core/units/body_units.dart';
import 'package:gains/features/profile/models/profile.dart';
import 'package:gains/features/profile/models/routine_template_ids.dart';
import 'package:gains/features/profile/models/starter_plan_recommendation.dart';

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
          gender: 'female',
          activityLevel: 'moderate',
          heightCm: 180,
          weightKg: 80,
        ).needsOnboarding,
        isFalse,
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
        isTrue,
      );
    });
  });

  group('recommendStarterPlan', () {
    test('3-day muscle gain suggests PPL', () {
      const profile = Profile(
        userId: '1',
        goal: 'muscle_gain',
        experience: 'intermediate',
        trainingDaysPerWeek: 3,
      );
      final plan = recommendStarterPlan(profile);
      expect(plan.templateIds, [
        RoutineTemplateIds.pushDay,
        RoutineTemplateIds.pullDay,
        RoutineTemplateIds.legs,
      ]);
      expect(plan.firstTemplateId, RoutineTemplateIds.pushDay);
    });

    test('4-day strength suggests upper/lower', () {
      const profile = Profile(
        userId: '1',
        goal: 'strength',
        experience: 'advanced',
        trainingDaysPerWeek: 4,
      );
      final plan = recommendStarterPlan(profile);
      expect(plan.templateIds, hasLength(4));
      expect(plan.firstTemplateId, RoutineTemplateIds.upperBodyA);
    });

    test('home hints pick home template', () {
      const profile = Profile(
        userId: '1',
        goal: 'muscle_gain',
        experience: 'beginner',
        trainingDaysPerWeek: 3,
        injuryNotes: 'Training at home with dumbbells only',
      );
      final plan = recommendStarterPlan(profile);
      expect(plan.templateIds, [RoutineTemplateIds.homeMinimal]);
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
