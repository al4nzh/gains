import 'package:gains/features/profile/models/gym_archetype.dart';

class Profile {
  const Profile({
    required this.userId,
    this.goal,
    this.experience,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.gender,
    this.trainingDaysPerWeek,
    this.injuryNotes,
    this.updatedAt,
    this.gymArchetype,
  });

  final String userId;
  final String? goal;
  final String? experience;
  final double? heightCm;
  final double? weightKg;
  final String? activityLevel;
  final String? gender;
  /// 2–4 = exact days; 5 = five or more days per week.
  final int? trainingDaysPerWeek;
  final String? injuryNotes;
  final DateTime? updatedAt;
  final GymArchetype? gymArchetype;

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
      trainingDaysPerWeek: json['training_days_per_week'] as int?,
      injuryNotes: json['injury_notes'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      gymArchetype: json['gym_archetype'] is Map<String, dynamic>
          ? GymArchetype.fromJson(json['gym_archetype'] as Map<String, dynamic>)
          : null,
    );
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
