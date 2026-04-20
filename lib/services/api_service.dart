import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const _baseUrlKey = 'server_base_url';
  static const _defaultBaseUrl = 'http://101.37.80.57:5522';

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 180),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
    ));
  }

  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _baseUrlKey, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  Future<bool> healthCheck() async {
    try {
      final base = await _getBaseUrl();
      final res = await _dio.get('$base/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<ExtractionResult> extractFromText(String text) async {
    final base = await _getBaseUrl();
    final res = await _dio.post(
      '$base/extract',
      data: jsonEncode({'text': text}),
    );
    return ExtractionResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ExtractionResult> extractFromImage(File imageFile) async {
    final base = await _getBaseUrl();
    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

    final res = await _dio.post(
      '$base/extract',
      data: jsonEncode({'image_base64': b64, 'image_mime': mime}),
    );
    return ExtractionResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ExtractionResult> extractFromFile(File file, String fileType) async {
    final base = await _getBaseUrl();
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);

    final res = await _dio.post(
      '$base/extract',
      data: jsonEncode({'file_base64': b64, 'file_type': fileType}),
    );
    return ExtractionResult.fromJson(res.data as Map<String, dynamic>);
  }
}
