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

  static const genders = [
    ('female', 'Female'),
    ('male', 'Male'),
    ('prefer_not_to_say', 'Prefer not to say'),
  ];

  static const activityLevels = [
    ('sedentary', 'Sedentary'),
    ('light', 'Light'),
    ('moderate', 'Moderate'),
    ('active', 'Active'),
    ('very_active', 'Very active'),
  ];

  /// Stored as 2–5 on the profile (`5` = five or more days per week).
  static const daysPerWeek = [
    ('2', '2 days'),
    ('3', '3 days'),
    ('4', '4 days'),
    ('5', '5+ days'),
  ];
}
