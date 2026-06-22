class SiloHistoryModel {
  final int id;
  final DateTime recordTime;
  final double weight;
  final int sync;
  final Map<String, dynamic> raw;

  SiloHistoryModel({
    required this.id,
    required this.recordTime,
    required this.weight,
    required this.sync,
    required this.raw,
  });

  factory SiloHistoryModel.fromJson(
    Map<String, dynamic> json, {
    int defaultId = -1,
  }) {
    final id = _toInt(
      json['id'] ?? json['Id'] ?? json['scaleId'] ?? json['id_relay'],
      defaultValue: defaultId,
    );

    final recordTime = _parseDateTime(
      json['recordDate'] ??
          json['RecordDate'] ??
          json['record_time'] ??
          json['recordTime'] ??
          json['time'] ??
          json['Time'] ??
          json['createdAt'] ??
          json['created_at'] ??
          json['timestamp'],
    );

    final weight = _toDouble(
      json['weight'] ??
          json['Weight'] ??
          json['value'] ??
          json['Value'] ??
          json['weightKg'] ??
          json['WeightKg'] ??
          json['grossWeight'],
    );

    final sync = _toInt(json['sync'] ?? json['Sync'], defaultValue: -1);

    return SiloHistoryModel(
      id: id,
      recordTime: recordTime,
      weight: weight,
      sync: sync,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recordTime': recordTime.toIso8601String(),
      'weight': weight,
      'sync': sync,
    };
  }

  static List<SiloHistoryModel> parseListFromResponse(
    dynamic decoded, {
    int defaultId = -1,
  }) {
    final rows = <dynamic>[];

    if (decoded is List) {
      rows.addAll(decoded);
    } else if (decoded is Map<String, dynamic>) {
      final nestedList = _extractList(decoded);
      if (nestedList != null) {
        rows.addAll(nestedList);
      } else {
        rows.add(decoded);
      }
    }

    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => SiloHistoryModel.fromJson(row, defaultId: defaultId))
        .toList();
  }

  static List<dynamic>? _extractList(Map<String, dynamic> map) {
    const candidates = [
      'data',
      'items',
      'result',
      'results',
      'history',
      'histories',
      'records',
    ];

    for (final key in candidates) {
      final value = map[key];
      if (value is List) return value;
    }

    return null;
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
