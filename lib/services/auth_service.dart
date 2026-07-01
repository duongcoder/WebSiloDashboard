import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- Cấu hình Base URL Linh Hoạt ---
String get baseUrl {
  if (!kReleaseMode) {
    // Khi đang Code/Dev: Gọi thẳng vào Backend .NET đang chạy dưới máy Local
    return 'http://localhost:5294'; 
  }
  
  try {
    // Khi deploy máy khách (Release): Tự động bốc Domain/IP hiện tại của trình duyệt
    final origin = Uri.base.origin;
    
    // MẸO TỐI ƯU: Nếu bạn tách riêng Frontend và Backend chạy ở 2 Port khác nhau trên máy khách 
    // (Ví dụ Backend cố định chạy port 8089), hãy bỏ comment dòng phía dưới:
    // return origin.replaceAll(RegExp(r':\d+$'), '') + ':8089';
    
    return origin;
  } catch (_) {
    return 'http://localhost:5294';
  }
}

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  static const String _prefsKey = 'auth_token';
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
    final uri = Uri.parse(_loginUrl);

    try {
      final res = await _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (res.statusCode != 200) return false;

      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) return false;

      final success = body['success'] == true;
      if (!success) return false;

      // Đón đầu thông minh: Lấy 'token' hoặc 'auth_token', key nào có dữ liệu thì bốc luôn
      final token = body['token'] ?? body['auth_token'];
      if (token is! String || token.trim().isEmpty) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, token);
      return true;
    } catch (e) {
      debugPrint('Lỗi kết nối API Login: $e');
      return false;
    }
  }

  // Logout endpoint dùng đường dẫn tương đối bắt đầu bằng /api/
  // (baseUrl chỉ dùng để gom domain; không hardcode port/IP)
  Future<bool> logout() async {
    final uri = Uri.parse('$baseUrl/api/Auth/Logout');

    try {
      final token = await getToken();

      // Nếu có token thì gửi lên để server có thể blacklist/thu hồi nếu cần.
      // Nếu hệ thống chỉ "pure JWT" thì server vẫn trả về Success.
      final res = await _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'token': token,
        }),
      );

      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsKey);
        return true;
      }
    } catch (e) {
      debugPrint('Lỗi kết nối API Logout: $e');
    }

    // Fallback: vẫn xóa token local để user thoát được.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    return false;
  }


  void dispose() {
    _client.close();
  }
}