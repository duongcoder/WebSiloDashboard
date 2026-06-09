import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SqlService {
  // Flutter Web chạy trong trình duyệt (sandbox) nên không thể kết nối SQL Server trực tiếp.
  // Thay vào đó dùng local gateway C# chạy ở localhost.
  static const String _baseUrl = 'http://localhost:5005';

  static Future<List<Map<String, dynamic>>> fetchSilos() async {
    final uri = Uri.parse('$_baseUrl/silos');

    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) {
      throw Exception('GET /silos failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) return <Map<String, dynamic>>[];

    return decoded
        .map((e) => e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(e as Map))
        .toList();
  }
}


