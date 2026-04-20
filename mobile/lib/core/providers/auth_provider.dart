import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';

class AuthProvider extends ChangeNotifier {
  final _api = ApiService();

  AppUser? _user;
  bool _loading = false;
  String? _error;

  AppUser? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });
      final token = res.data['accessToken'] as String;
      await _api.saveToken(token);
      _user = AppUser.fromJson(res.data['user'] as Map<String, dynamic>);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _user = null;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final token = await _api.getToken();
    if (token == null) return false;

    try {
      final res = await _api.get(ApiConstants.me);
      _user = AppUser.fromJson(res.data as Map<String, dynamic>);
      notifyListeners();
      return true;
    } catch (_) {
      await _api.clearToken();
      return false;
    }
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Cannot connect to server. Is the backend running?';
      }
      final status = e.response?.statusCode;
      if (status == 401) return 'Invalid email or password';
      if (status == 403) return 'Access denied';
      final serverMsg = e.response?.data?['message'];
      if (serverMsg != null) return serverMsg.toString();
      return 'Cannot connect to server: ${e.message}';
    }
    return 'Error: ${e.runtimeType} — $e';
  }
}
