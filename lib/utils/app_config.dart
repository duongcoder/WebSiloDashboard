import 'package:flutter/foundation.dart';

class AppConfig {
  /// IP hoặc hostname của backend. Trên Web lấy từ URL trình duyệt.
  static String get serverIp {
    if (kIsWeb) {
      return Uri.base.host;
    }
    return 'localhost';
  }

  /// Port của Kestrel/IIS backend API.
  static const String apiPort = '5294';

  /// Scheme (http/https) lấy từ URL trình duyệt hiện tại để hỗ trợ cả HTTP lẫn HTTPS.
  static String get scheme {
    if (kIsWeb) return Uri.base.scheme;
    return 'http';
  }

  /// Base URL của backend REST API.
  static String get baseUrl => '$scheme://$serverIp:$apiPort/api';

  /// URL kết nối SignalR Hub – dùng cùng scheme và host với REST API.
  static String get signalRHubUrl => '$scheme://$serverIp:$apiPort/siloHub';
}
