class User {
  const User({
    required this.id,
    required this.email,
    required this.authProvider,
    this.emailVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String authProvider;
  final DateTime? emailVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmailVerified => emailVerifiedAt != null;
  bool get usesEmailAuth => authProvider == 'email';

  factory User.fromJson(Map<String, dynamic> json) {
    final verifiedRaw = json['email_verified_at'];
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      authProvider: json['auth_provider'] as String? ?? 'email',
      emailVerifiedAt: verifiedRaw == null ? null : DateTime.parse(verifiedRaw as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
