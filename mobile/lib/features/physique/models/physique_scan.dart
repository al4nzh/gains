class PhysiqueScan {
  const PhysiqueScan({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.estimatedBodyFatPct,
    required this.confidence,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String imageUrl;
  final int estimatedBodyFatPct;
  final String confidence;
  final DateTime createdAt;

  factory PhysiqueScan.fromJson(Map<String, dynamic> json) {
    return PhysiqueScan(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      imageUrl: json['image_url'] as String,
      estimatedBodyFatPct: json['estimated_body_fat_pct'] as int,
      confidence: json['confidence'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now().toUtc(),
    );
  }
}
