class CatalogExercise {
  const CatalogExercise({
    required this.id,
    required this.name,
    this.muscleGroup,
    this.equipment,
  });

  final String id;
  final String name;
  final String? muscleGroup;
  final String? equipment;

  factory CatalogExercise.fromJson(Map<String, dynamic> json) {
    return CatalogExercise(
      id: json['id'] as String,
      name: json['name'] as String,
      muscleGroup: json['muscle_group'] as String?,
      equipment: json['equipment'] as String?,
    );
  }
}
