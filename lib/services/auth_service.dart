import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- Cấu hình Base URL Linh Hoạt ---
String get baseUrl {
  if (!kReleaseMode) {
    return 'http://localhost:5294';
  }

  try {
    // Trích xuất IP động từ trình duyệt máy khách
    final Uri currentUri = Uri.base;
    final String host = currentUri.host;
    final String scheme = currentUri.scheme;
    
    // BẮT BUỘC: Ép request đi đúng vào Port 5294 của Backend .NET trên IIS
    return '$scheme://$host:5294';
  } catch (e) {
    return 'http://192.168.1.74:5294'; // Khôi phục dự phòng nếu lỗi
  }
}

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  static const String _prefsKey = 'auth_token';
  static const String _prefsUserIdKey = 'user_id';
  static const String _prefsUserNameKey = 'user_name';
  static const String _prefsUserRoleKey = 'user_role';
  static const String _prefsAvatarUrlKey = 'user_avatar_url';
  String get _loginUrl => '$baseUrl/api/Auth/Login';

  final http.Client _client;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.trim().isNotEmpty;
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    final dio = Dio();

    try {
      final res = await dio.post(
        _loginUrl,
        options: Options(
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
          },
          validateStatus: (status) => status != null && status >= 200 && status < 500,
        ),
        data: {
          'username': username,
          'password': password,
        },
      );

      if (res.statusCode == 400 || res.statusCode == 401) {
        throw Exception('Incorrect username or password!');
      }

      if (res.statusCode != 200) {
        throw Exception('Login failed (${res.statusCode ?? 'unknown'})');
      }

      final rawData = res.data;
      final body = rawData is Map<String, dynamic>
          ? rawData
          : rawData is Map
              ? Map<String, dynamic>.from(rawData)
              : <String, dynamic>{};

      if (body.isEmpty) {
        throw Exception('Login response is invalid.');
      }

      final success = body['success'] == true;
      if (!success) {
        throw Exception((body['message'] ?? 'Login failed').toString());
      }

      final token = body['token'] ?? body['auth_token'];
      if (token is! String || token.trim().isEmpty) {
        throw Exception('Token is missing from login response.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, token);

      final claims = _decodeJwtClaims(token);
      final userId = _pickStringClaim(claims, const [
        'userId',
        'sub',
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier',
      ]);
      final role = _pickStringClaim(claims, const [
        'role',
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
      ]);
      final name = _pickStringClaim(claims, const [
        'name',
        'unique_name',
        'username',
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name',
      ]);
      final avatarUrl = _pickStringClaim(claims, const ['avatarUrl']);

      await prefs.setString(_prefsUserIdKey, userId ?? '');
      await prefs.setString(_prefsUserRoleKey, role ?? 'User');
      await prefs.setString(_prefsUserNameKey, name ?? username);
      await prefs.setString(_prefsAvatarUrlKey, avatarUrl ?? '');
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) {
        throw Exception('Incorrect username or password!');
      }

      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw Exception(responseData['message'].toString());
      }

      throw Exception('Unable to connect to server. Please try again.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Login failed. Please try again.');
    }
  }

  // Logout endpoint dùng đường dẫn tương đối bắt đầu bằng /api/
  // để tương thích IIS Reverse Proxy (ARR).
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final token = await getToken();

      // Defensive check: bỏ qua request nếu token rỗng/null để tránh backend 500.
      if (token == null || token.trim().isEmpty) {
        return;
      }

      final dio = Dio();

      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
      };
      headers['Authorization'] = 'Bearer $token';

      await dio.post(
        '$baseUrl/api/Auth/Logout',
        options: Options(
          headers: headers,
        ),
      );
    } on DioException catch (e) {
      debugPrint('Lỗi kết nối API Logout (Dio): $e');
    } catch (e) {
      debugPrint('Lỗi kết nối API Logout: $e');
    } finally {
      await prefs.remove(_prefsKey);
      await prefs.remove(_prefsUserIdKey);
      await prefs.remove(_prefsUserNameKey);
      await prefs.remove(_prefsUserRoleKey);
      await prefs.remove(_prefsAvatarUrlKey);
    }
  }

  Map<String, dynamic> _decodeJwtClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return const <String, dynamic>{};

      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payload);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return const <String, dynamic>{};
  }

  String? _pickStringClaim(Map<String, dynamic> claims, List<String> keys) {
    for (final key in keys) {
      final value = claims[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }


  void dispose() {
    _client.close();
  }
}