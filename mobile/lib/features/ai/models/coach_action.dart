class CoachAction {
  const CoachAction({
    required this.id,
    required this.actionType,
    this.targetType,
    this.targetId,
    this.payload,
    this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String actionType;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic>? payload;
  final String? reason;
  final String status;
  final DateTime createdAt;

  factory CoachAction.fromJson(Map<String, dynamic> json) {
    return CoachAction(
      id: json['id'] as String,
      actionType: json['action_type'] as String,
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as String?,
      payload: _parsePayload(json['payload']),
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static Map<String, dynamic>? _parsePayload(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }
}
