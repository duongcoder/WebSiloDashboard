import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_config.dart';

class ScaleService {
  // static const String baseUrl = "http://localhost:5294/api/Scales";
  // static const String baseUrl = "http://192.168.1.74:5294/api/Scales";
  static String get baseUrl => "${AppConfig.baseUrl}/Scales";

  static Future<List<dynamic>> getListScales() async {
    final url = Uri.parse("$baseUrl/GetListScales");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load scales: ${response.statusCode}");
    }
  }
}
