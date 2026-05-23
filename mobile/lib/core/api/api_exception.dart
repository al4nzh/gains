class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;

  static ApiException? fromResponse(dynamic data, int? statusCode) {
    if (data is Map && data['error'] != null) {
      return ApiException(data['error'].toString(), statusCode: statusCode);
    }
    return null;
  }
}
