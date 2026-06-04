class Profile {
  const Profile({
    required this.userId,
    this.goal,
    this.experience,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.gender,
    this.injuryNotes,
    this.updatedAt,
  });

  final String userId;
  final String? goal;
  final String? experience;
  final double? heightCm;
  final double? weightKg;
  final String? activityLevel;
  final String? gender;
  final String? injuryNotes;
  final DateTime? updatedAt;

  /// Show profile setup until required fields for home/coach are present.
  bool get needsOnboarding {
    final g = goal?.trim();
    final e = experience?.trim();
    final a = activityLevel?.trim();
    final gen = gender?.trim();
    if (g == null || g.isEmpty || e == null || e.isEmpty) return true;
    if (gen == null || gen.isEmpty) return true;
    if (a == null || a.isEmpty) return true;
    if (heightCm == null || heightCm! <= 0) return true;
    if (weightKg == null || weightKg! <= 0) return true;
    return false;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userId: json['user_id'] as String,
      goal: json['goal'] as String?,
      experience: json['experience'] as String?,
      heightCm: _readDouble(json['height_cm']),
      weightKg: _readDouble(json['weight_kg']),
      activityLevel: json['activity_level'] as String?,
      gender: json['gender'] as String?,
      injuryNotes: json['injury_notes'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
