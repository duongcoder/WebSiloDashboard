import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/silo.dart';
import '../models/indicator.dart';
import '../models/controller.dart';
import '../models/col_data.dart';

class ApiService {
  // static const String baseUrl = "http://localhost:5294/api";
  // static const String baseUrl = "http://192.168.1.74:5294/api";
  static String get baseUrl => AppConfig.baseUrl;

  /// Lấy danh sách Silos (chỉ chứa id, weight, level, indicatorId, controllerId)
  static Future<List<Silo>> fetchSilos() async {
    final response = await http
      .get(Uri.parse("$baseUrl/silos"))
      .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Silo.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load silos");
    }
  }

  /// Lấy danh sách Indicators
  static Future<List<Indicator>> fetchIndicators() async {
    final response = await http
      .get(Uri.parse("$baseUrl/indicators"))
      .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Indicator.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load indicators");
    }
  }

  /// Lấy danh sách Controllers
  static Future<List<Controller>> fetchControllers() async {
    final response = await http
      .get(Uri.parse("$baseUrl/controllers"))
      .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Controller.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load controllers");
    }
  }

  /// Lấy dữ liệu ColData (từ bảng ColData trong SSMS)
  static Future<List<ColData>> fetchColData() async {
    final response = await http
        .get(Uri.parse("$baseUrl/coldata"))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ColData.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load ColData");
    }
  }
}
