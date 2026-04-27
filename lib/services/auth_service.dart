import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const _keySession = 'auth_session_id';
  static const _keyUsername = 'auth_username';
  static const _keySavedUsername = 'auth_saved_username';

  String? _sessionId;
  String? _username;

  String? get sessionId => _sessionId;
  String? get username => _username;
  bool get isLoggedIn => _sessionId != null;

  /// Call once at app startup to restore a saved session.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString(_keySession);
    _username = prefs.getString(_keyUsername);
    notifyListeners();
  }

  /// 读取上次记住的用户名，用于登录页预填
  Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySavedUsername);
  }

  Future<String?> login(
    String baseUrl,
    String username,
    String password, {
    bool remember = true,
  }) async {
    try {
      final dio = _buildDio();
      final res = await dio.post(
        '$baseUrl/auth/login',
        data: {'username': username, 'password': password},
      );
      final sessionId = res.data['session_id'] as String;
      await _persist(sessionId, username, remember: remember);
      notifyListeners();
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return '用户名或密码错误';
      return _dioError(e);
    } catch (e) {
      return '登录失败：$e';
    }
  }

  Future<String?> register(String baseUrl, String username, String password,
      {bool remember = true}) async {
    try {
      final dio = _buildDio();
      await dio.post(
        '$baseUrl/auth/register',
        data: {'username': username, 'password': password},
      );
      return await login(baseUrl, username, password, remember: remember);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return '用户名已存在';
      return _dioError(e);
    } catch (e) {
      return '注册失败：$e';
    }
  }

  static String _dioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查服务器地址';
      case DioExceptionType.connectionError:
        return '无法连接到服务器，请先在设置页配置正确的地址';
      default:
        final status = e.response?.statusCode;
        final detail = e.response?.data?['detail'];
        if (status != null) return '服务器错误 $status${detail != null ? "：$detail" : ""}';
        return '网络异常：${e.error ?? e.type.name}';
    }
  }

  Future<void> logout(String baseUrl) async {
    if (_sessionId == null) return;
    try {
      final dio = _buildDio();
      await dio.post(
        '$baseUrl/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $_sessionId'}),
      );
    } catch (_) {}
    await _clear();
    notifyListeners();
  }

  Future<void> _persist(String sessionId, String username,
      {bool remember = true}) async {
    _sessionId = sessionId;
    _username = username;
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      await prefs.setString(_keySession, sessionId);
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keySavedUsername, username); // pre-fill next time
    }
    // If not remember: session lives in memory only, cleared on app restart
  }

  Future<void> _clear() async {
    _sessionId = null;
    _username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySession);
    await prefs.remove(_keyUsername);
    // Keep _keySavedUsername so the username field stays pre-filled
  }

  Dio _buildDio() => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ));
}
