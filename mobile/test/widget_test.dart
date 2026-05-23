import 'package:flutter_test/flutter_test.dart';
import 'package:gains/features/profile/models/profile.dart';

void main() {
  group('Profile.needsOnboarding', () {
    test('true when goal, experience, or weight missing', () {
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
          weightKg: 80,
        ).needsOnboarding,
        isFalse,
      );
      expect(
        const Profile(userId: '1', weightKg: 80).needsOnboarding,
        isTrue,
      );
    });
  });
}
