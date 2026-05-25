class CoachConversation {
  const CoachConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CoachConversation.fromJson(Map<String, dynamic> json) {
    return CoachConversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Coach chat',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
