import 'package:intl/intl.dart';

class SiloHistoryModel {
  final int id;
  final int idScale;
  final double weightPre;
  final double weightNow;
  final DateTime time;
  final int sync;
  final String des;
  final Map<String, dynamic> raw;

  SiloHistoryModel({
    required this.id,
    required this.idScale,
    required this.weightPre,
    required this.weightNow,
    required this.time,
    required this.sync,
    required this.des,
    required this.raw,
  });

  // Giữ tương thích cho các luồng cũ đang dùng tên field cũ.
  DateTime get recordTime => time;
  double get weight => weightNow;

  factory SiloHistoryModel.fromJson(
    Map<String, dynamic> json, {
    int defaultId = -1,
  }) {
    final id = _toInt(json['id'] ?? json['Id'], defaultValue: defaultId);
    final idScale = _toInt(
      json['id_scale'] ?? json['idScale'] ?? json['IdScale'] ?? json['id_relay'],
      defaultValue: defaultId,
    );
    final weightPre = _toDouble(
      json['weight_pre'] ?? json['weightPre'] ?? json['WeightPre'],
    );
    final weightNow = _toDouble(
      json['weight_now'] ??
          json['weightNow'] ??
          json['WeightNow'] ??
          json['weight'] ??
          json['Weight'] ??
          json['value'] ??
          json['Value'] ??
          json['weightKg'] ??
          json['WeightKg'] ??
          json['grossWeight'],
    );
    final time = _parseDateTime(
      json['time'] ??
          json['Time'] ??
          json['recordDate'] ??
          json['RecordDate'] ??
          json['record_time'] ??
          json['recordTime'] ??
          json['createdAt'] ??
          json['created_at'] ??
          json['timestamp'],
    );
    final sync = _toInt(json['sync'] ?? json['Sync'], defaultValue: -1);
    final des = (json['des'] ?? json['Des'] ?? '').toString();

    return SiloHistoryModel(
      id: id,
      idScale: idScale,
      weightPre: weightPre,
      weightNow: weightNow,
      time: time,
      sync: sync,
      des: des,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_scale': idScale,
      'weight_pre': weightPre,
      'weight_now': weightNow,
      'time': time.toIso8601String(),
      'sync': sync,
      'des': des,
    };
  }

  /// Trả về thời gian hiển thị dạng HH:mm:ss.
  String get displayTimeHms {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  /// Trả về thời gian hiển thị dạng HH:mm:ss - dd/MM/yyyy.
  String get formattedTime {
    return DateFormat('HH:mm:ss - dd/MM/yyyy').format(time.toLocal());
  }

  /// Trả về chênh lệch khối lượng dạng +X kg / -X kg / 0 kg.
  String get weightChange {
    final delta = weightNow - weightPre;
    if (delta > 0) {
      return '+${delta.toStringAsFixed(1)} kg';
    }
    if (delta < 0) {
      return '${delta.toStringAsFixed(1)} kg';
    }
    return '0 kg';
  }

  /// Tóm tắt biến động phục vụ cột mô tả báo cáo.
  ///
  /// Lưu ý: để tính "khoảng thời gian từ bản ghi trước đến hiện tại"
  /// cần ngữ cảnh bản ghi trước, nên getter này trả về mô tả sẵn dùng.
  String get durationSummary {
    try {
      if (des.trim().isNotEmpty) {
        return des;
      }

      return 'ID $idScale | $formattedTime | $weightChange';
    } catch (_) {
      return 'Không xác định';
    }
  }

  static List<SiloHistoryModel> parseListFromResponse(
    dynamic decoded, {
    int defaultId = -1,
  }) {
    final rows = _extractHistoryRows(decoded);

    return rows
        .map((row) => SiloHistoryModel.fromJson(row, defaultId: defaultId))
        .toList();
  }

  static List<Map<String, dynamic>> _extractHistoryRows(dynamic node) {
    final rows = <Map<String, dynamic>>[];

    void walk(dynamic value) {
      if (value is List) {
        for (final item in value) {
          walk(item);
        }
        return;
      }

      if (value is Map<String, dynamic>) {
        if (_looksLikeHistoryRow(value)) {
          rows.add(value);
        }

        for (final nested in value.values) {
          walk(nested);
        }
      }
    }

    walk(node);
    return rows;
  }

  static bool _looksLikeHistoryRow(Map<String, dynamic> row) {
    final hasTime = row.containsKey('time') ||
        row.containsKey('Time') ||
        row.containsKey('recordTime') ||
        row.containsKey('record_time') ||
        row.containsKey('recordDate') ||
        row.containsKey('RecordDate');

    final hasWeight = row.containsKey('weight_now') ||
        row.containsKey('weightNow') ||
        row.containsKey('WeightNow') ||
        row.containsKey('weight') ||
        row.containsKey('Weight') ||
        row.containsKey('value') ||
        row.containsKey('Value');

    final hasIdentity = row.containsKey('id') ||
        row.containsKey('Id') ||
        row.containsKey('id_scale') ||
        row.containsKey('idScale') ||
        row.containsKey('IdScale');

    return hasTime && hasWeight && hasIdentity;
  }

  static int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static double _toDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();

    if (value is int) {
      final isMillis = value.abs() > 9999999999;
      final millis = isMillis ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();

      final asInt = int.tryParse(value);
      if (asInt != null) {
        final isMillis = asInt.abs() > 9999999999;
        final millis = isMillis ? asInt : asInt * 1000;
        return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      }
    }

    return DateTime.now();
  }
}
