class PhysiqueScan {
  const PhysiqueScan({
    required this.id,
    required this.userId,
    required this.estimatedBodyFatPct,
    required this.confidence,
    required this.summary,
    required this.reasoning,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final int estimatedBodyFatPct;
  final String confidence;
  final String summary;
  final String reasoning;
  final DateTime createdAt;

  factory PhysiqueScan.fromJson(Map<String, dynamic> json) {
    return PhysiqueScan(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      estimatedBodyFatPct: json['estimated_body_fat_pct'] as int,
      confidence: json['confidence'] as String,
      summary: json['summary'] as String? ?? '',
      reasoning: json['reasoning'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now().toUtc(),
    );
  }
}
