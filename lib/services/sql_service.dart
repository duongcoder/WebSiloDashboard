import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/silo.dart';

class ApiService {
  static const String baseUrl = "http://localhost:5294/api";

  static Future<List<Silo>> fetchSilos() async {
    final response = await http.get(Uri.parse("$baseUrl/silos"));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Silo.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load silos");
    }
  }
}
