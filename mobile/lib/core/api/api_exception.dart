class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.activeWorkoutId,
  });

  final String message;
  final int? statusCode;
  final String? code;

  /// Set when `POST /workouts` returns 409 (one active session per user).
  final String? activeWorkoutId;

  bool get isActiveWorkoutConflict =>
      statusCode == 409 && activeWorkoutId != null && activeWorkoutId!.isNotEmpty;

  @override
  String toString() => message;

  static ApiException? fromResponse(dynamic data, int? statusCode) {
    if (data is Map && data['error'] != null) {
      final activeId = data['active_workout_id'];
      return ApiException(
        data['error'].toString(),
        statusCode: statusCode,
        code: data['code']?.toString(),
        activeWorkoutId: activeId?.toString(),
      );
    }
    return null;
  }
}
