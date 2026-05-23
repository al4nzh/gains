import 'package:dio/dio.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/config/api_config.dart';
import 'package:gains/features/auth/data/token_storage.dart';
import 'package:gains/features/auth/models/token_pair.dart';

class ApiClient {
  ApiClient(this._tokenStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  final TokenStorage _tokenStorage;
  late final Dio _dio;
  Future<bool>? _refreshFuture;

  Dio get dio => _dio;

  Future<String?> readAccessToken() => _tokenStorage.readAccessToken();

  Future<void> persistTokens(TokenPair tokens) => _tokenStorage.saveTokens(tokens);

  Future<void> clearTokens() => _tokenStorage.clear();

  Future<bool> refreshAccessToken() async {
    _refreshFuture ??= _performRefresh();
    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<bool> _performRefresh() async {
    final refresh = await _tokenStorage.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(extra: {_kSkipAuth: true, _kSkipRefresh: true}),
      );
      final data = response.data;
      if (data == null || data['tokens'] == null) return false;
      final tokens = TokenPair.fromJson(data['tokens'] as Map<String, dynamic>);
      await _tokenStorage.saveTokens(tokens);
      return true;
    } on DioException {
      await _tokenStorage.clear();
      return false;
    }
  }

  static Never throwFromDio(DioException e) {
    final api = ApiException.fromResponse(e.response?.data, e.response?.statusCode);
    if (api != null) throw api;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      throw ApiException('Could not reach the server. Is the API running?', statusCode: null);
    }
    throw ApiException('Something went wrong. Try again.', statusCode: e.response?.statusCode);
  }
}

const _kSkipAuth = 'skipAuth';
const _kSkipRefresh = 'skipRefresh';

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._client);

  final ApiClient _client;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[_kSkipAuth] == true) {
      handler.next(options);
      return;
    }
    final token = await _client.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra[_kSkipRefresh] == true) {
      handler.next(err);
      return;
    }

    final refreshed = await _client.refreshAccessToken();
    if (!refreshed) {
      handler.next(err);
      return;
    }

    try {
      final token = await _client.readAccessToken();
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $token';
      final response = await _client.dio.fetch(opts);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
