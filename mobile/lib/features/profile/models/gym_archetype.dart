class GymArchetype {
  const GymArchetype({
    required this.unlocked,
    required this.workoutsCompleted,
    required this.workoutsRequired,
    this.primaryArchetype,
    this.primaryLabel,
    this.primaryTagline,
    this.secondaryTrait,
    this.secondaryLabel,
  });

  final bool unlocked;
  final int workoutsCompleted;
  final int workoutsRequired;
  final String? primaryArchetype;
  final String? primaryLabel;
  final String? primaryTagline;
  final String? secondaryTrait;
  final String? secondaryLabel;

  factory GymArchetype.fromJson(Map<String, dynamic> json) {
    return GymArchetype(
      unlocked: json['unlocked'] as bool? ?? false,
      workoutsCompleted: json['workouts_completed'] as int? ?? 0,
      workoutsRequired: json['workouts_required'] as int? ?? 3,
      primaryArchetype: json['primary_archetype'] as String?,
      primaryLabel: json['primary_label'] as String?,
      primaryTagline: json['primary_tagline'] as String?,
      secondaryTrait: json['secondary_trait'] as String?,
      secondaryLabel: json['secondary_label'] as String?,
    );
  }
}
