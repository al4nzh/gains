/// Allowed profile enum values per docs/API.md.
abstract final class ProfileOptions {
  static const goals = [
    ('muscle_gain', 'Muscle gain'),
    ('strength', 'Strength'),
    ('fat_loss', 'Fat loss'),
    ('general_fitness', 'General fitness'),
  ];

  static const experience = [
    ('beginner', 'Beginner'),
    ('intermediate', 'Intermediate'),
    ('advanced', 'Advanced'),
  ];

  static const activityLevels = [
    ('sedentary', 'Sedentary'),
    ('light', 'Light'),
    ('moderate', 'Moderate'),
    ('active', 'Active'),
    ('very_active', 'Very active'),
  ];
}
