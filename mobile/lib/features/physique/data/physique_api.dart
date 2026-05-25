import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/config/api_config.dart';
import 'package:gains/features/physique/models/physique_scan.dart';

class PhysiqueApi {
  PhysiqueApi(this._client);

  final ApiClient _client;

  static String imageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return '$base$p';
  }

  Future<List<PhysiqueScan>> listScans({int limit = 50}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/physique-scans',
        queryParameters: {'limit': limit},
      );
      final list = response.data!['scans'] as List<dynamic>? ?? [];
      return list.map((e) => PhysiqueScan.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PhysiqueScan> getScan(String id) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/physique-scans/$id');
      return PhysiqueScan.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PhysiqueScan> createScan(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      throw ApiException('At least one image is required');
    }
    try {
      final files = <MultipartFile>[];
      for (var i = 0; i < imagePaths.length && i < 3; i++) {
        final path = imagePaths[i];
        files.add(await MultipartFile.fromFile(path, filename: 'image_$i.jpg'));
      }

      final formData = FormData();
      for (final file in files) {
        formData.files.add(MapEntry('images', file));
      }

      final response = await _client.dio.post<Map<String, dynamic>>(
        '/physique-scans',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 90),
          contentType: 'multipart/form-data',
        ),
      );
      return PhysiqueScan.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
