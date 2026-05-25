class RecoveryCheckin {
  const RecoveryCheckin({
    required this.id,
    required this.checkinDate,
    required this.sleepHours,
    required this.energyReadiness,
    required this.caloriesKcal,
    required this.proteinG,
    this.notes,
  });

  final String id;
  final String checkinDate;
  final double sleepHours;
  final int energyReadiness;
  final int caloriesKcal;
  final int proteinG;
  final String? notes;

  factory RecoveryCheckin.fromJson(Map<String, dynamic> json) {
    return RecoveryCheckin(
      id: json['id'] as String,
      checkinDate: json['checkin_date'] as String,
      sleepHours: (json['sleep_hours'] as num).toDouble(),
      energyReadiness: json['energy_readiness'] as int,
      caloriesKcal: json['calories_kcal'] as int,
      proteinG: json['protein_g'] as int,
      notes: json['notes'] as String?,
    );
  }
}

class RecoveryCheckinStatus {
  const RecoveryCheckinStatus({
    required this.checkinDate,
    required this.hasCheckinToday,
    required this.shouldPrompt,
    this.checkin,
  });

  final String checkinDate;
  final bool hasCheckinToday;
  final bool shouldPrompt;
  final RecoveryCheckin? checkin;

  factory RecoveryCheckinStatus.fromJson(Map<String, dynamic> json) {
    return RecoveryCheckinStatus(
      checkinDate: json['checkin_date'] as String,
      hasCheckinToday: json['has_checkin_today'] as bool? ?? false,
      shouldPrompt: json['should_prompt'] as bool? ?? false,
      checkin: json['checkin'] != null
          ? RecoveryCheckin.fromJson(json['checkin'] as Map<String, dynamic>)
          : null,
    );
  }
}

class RecoveryCheckinInput {
  const RecoveryCheckinInput({
    required this.checkinDate,
    required this.sleepHours,
    required this.energyReadiness,
    required this.caloriesKcal,
    required this.proteinG,
    this.notes,
  });

  final String checkinDate;
  final double sleepHours;
  final int energyReadiness;
  final int caloriesKcal;
  final int proteinG;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'checkin_date': checkinDate,
        'sleep_hours': sleepHours,
        'energy_readiness': energyReadiness,
        'calories_kcal': caloriesKcal,
        'protein_g': proteinG,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };
}
