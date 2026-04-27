import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'auth_service.dart';

class ApiService {
  static const _baseUrlKey = 'server_base_url';
  static const _defaultBaseUrl = 'http://101.37.80.57:5522';

  final AuthService auth;
  late final Dio _dio;

  ApiService({required this.auth}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 180),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
  }

  Options get _authOptions {
    final sid = auth.sessionId;
    if (sid == null) return Options();
    return Options(headers: {'Authorization': 'Bearer $sid'});
  }

  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  String get _todayDate => DateTime.now().toIso8601String().substring(0, 10);

  // ── Health ─────────────────────────────────────────────────────────────────

  Future<bool> healthCheck() async {
    try {
      final base = await _getBaseUrl();
      final res = await _dio.get('$base/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Extraction ─────────────────────────────────────────────────────────────

  Future<ExtractionResult> extractFromText(String text) async {
    final base = await _getBaseUrl();
    final res = await _dio.post('$base/extract',
        data: jsonEncode({'text': text, 'current_date': _todayDate}),
        options: _authOptions);
    return _parseResult(res.data);
  }

  Future<ExtractionResult> extractFromImage(File imageFile) async {
    final base = await _getBaseUrl();
    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final res = await _dio.post('$base/extract',
        data: jsonEncode({'image_base64': b64, 'image_mime': mime, 'current_date': _todayDate}),
        options: _authOptions);
    return _parseResult(res.data);
  }

  Future<ExtractionResult> extractFromFile(File file, String fileType) async {
    final base = await _getBaseUrl();
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    final res = await _dio.post('$base/extract',
        data: jsonEncode({'file_base64': b64, 'file_type': fileType, 'current_date': _todayDate}),
        options: _authOptions);
    return _parseResult(res.data);
  }

  ExtractionResult _parseResult(dynamic data) {
    final map = data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;
    debugPrint('[API] events: ${(map["events"] as List?)?.length ?? 0},'
        ' todos: ${(map["todos"] as List?)?.length ?? 0}');
    return ExtractionResult.fromJson(map);
  }

  // ── Cloud sync: read all items ─────────────────────────────────────────────

  Future<ExtractionResult> getItems() async {
    final base = await _getBaseUrl();
    final res = await _dio.get('$base/items', options: _authOptions);
    return _parseResult(res.data);
  }

  // ── Events CRUD ────────────────────────────────────────────────────────────

  Future<ScheduleEvent> createEvent(ScheduleEvent event) async {
    final base = await _getBaseUrl();
    final res = await _dio.post('$base/items/events',
        data: jsonEncode(_eventBody(event)), options: _authOptions);
    return ScheduleEvent.fromJson(_asMap(res.data));
  }

  Future<ScheduleEvent> updateEventApi(ScheduleEvent event) async {
    final base = await _getBaseUrl();
    final res = await _dio.put('$base/items/events/${event.id}',
        data: jsonEncode(_eventBody(event)), options: _authOptions);
    return ScheduleEvent.fromJson(_asMap(res.data));
  }

  Future<void> deleteEventApi(int id) async {
    final base = await _getBaseUrl();
    await _dio.delete('$base/items/events/$id', options: _authOptions);
  }

  Future<void> pinEventApi(int id, bool isPinned) async {
    final base = await _getBaseUrl();
    await _dio.patch('$base/items/events/$id/pin',
        data: jsonEncode({'is_pinned': isPinned}), options: _authOptions);
  }

  // ── Todos CRUD ─────────────────────────────────────────────────────────────

  Future<Todo> createTodo(Todo todo) async {
    final base = await _getBaseUrl();
    final res = await _dio.post('$base/items/todos',
        data: jsonEncode(_todoBody(todo)), options: _authOptions);
    return Todo.fromJson(_asMap(res.data));
  }

  Future<Todo> updateTodoApi(Todo todo) async {
    final base = await _getBaseUrl();
    final res = await _dio.put('$base/items/todos/${todo.id}',
        data: jsonEncode(_todoBody(todo)), options: _authOptions);
    return Todo.fromJson(_asMap(res.data));
  }

  Future<void> deleteTodoApi(int id) async {
    final base = await _getBaseUrl();
    await _dio.delete('$base/items/todos/$id', options: _authOptions);
  }

  Future<void> toggleTodoDoneApi(int id, bool isDone) async {
    final base = await _getBaseUrl();
    await _dio.patch('$base/items/todos/$id/done',
        data: jsonEncode({'is_done': isDone}), options: _authOptions);
  }

  Future<void> pinTodoApi(int id, bool isPinned) async {
    final base = await _getBaseUrl();
    await _dio.patch('$base/items/todos/$id/pin',
        data: jsonEncode({'is_pinned': isPinned}), options: _authOptions);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _eventBody(ScheduleEvent e) => {
        'title': e.title,
        'date': e.date,
        'time': e.time,
        'location': e.location,
        'notes': e.notes,
        'is_pinned': e.isPinned,
      };

  Map<String, dynamic> _todoBody(Todo t) => {
        'title': t.title,
        'deadline': t.deadline,
        'priority': t.priority.name,
        'notes': t.notes,
        'is_done': t.isDone,
        'is_pinned': t.isPinned,
      };

  Map<String, dynamic> _asMap(dynamic d) =>
      d is String ? jsonDecode(d) as Map<String, dynamic> : d as Map<String, dynamic>;
}
