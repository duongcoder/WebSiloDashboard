import 'package:flutter/foundation.dart';

class AppConfig {
  // Hàm này giúp tự động lấy IP hiện tại của thanh địa chỉ trình duyệt
  static String get serverIp {
    if (kIsWeb) {
      // Lấy địa chỉ host (ví dụ: 192.168.1.74 hoặc maysuchilo)
      return Uri.base.host; 
    }
    return "localhost"; // Dự phòng nếu chạy trên giả lập app mobile
  }

  static const String apiPort = "5294";
  
  // Tự động lắp ghép: http:// + IP trình duyệt + :5294/api
  static String get baseUrl => "http://$serverIp:$apiPort/api";
}