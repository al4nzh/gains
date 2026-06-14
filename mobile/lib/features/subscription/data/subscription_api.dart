import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';

class SubscriptionApi {
  SubscriptionApi(this._client);

  final ApiClient _client;

  /// Ask the server to verify this user's entitlement with RevenueCat and update is_premium.
  Future<bool> sync() async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>('/subscription/sync');
      return response.data?['is_premium'] as bool? ?? false;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
