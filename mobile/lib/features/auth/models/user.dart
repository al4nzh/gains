class User {
  const User({
    required this.id,
    required this.email,
    required this.authProvider,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String authProvider;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      authProvider: json['auth_provider'] as String? ?? 'email',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
