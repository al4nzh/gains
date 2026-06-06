/// Body for PUT /profile (partial update — only non-null fields are sent).
class ProfileUpdate {
  const ProfileUpdate({
    this.goal,
    this.experience,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.gender,
    this.trainingDaysPerWeek,
    this.injuryNotes,
  });

  final String? goal;
  final String? experience;
  final double? heightCm;
  final double? weightKg;
  final String? activityLevel;
  final String? gender;
  final int? trainingDaysPerWeek;
  final String? injuryNotes;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (goal != null) map['goal'] = goal;
    if (experience != null) map['experience'] = experience;
    if (heightCm != null) map['height_cm'] = heightCm;
    if (weightKg != null) map['weight_kg'] = weightKg;
    if (activityLevel != null) map['activity_level'] = activityLevel;
    if (gender != null) map['gender'] = gender;
    if (trainingDaysPerWeek != null) {
      map['training_days_per_week'] = trainingDaysPerWeek;
    }
    if (injuryNotes != null) map['injury_notes'] = injuryNotes;
    return map;
  }
}
