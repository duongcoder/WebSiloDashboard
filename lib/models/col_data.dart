class ColData {
  final int id;
  final String siloId;
  final String recordDate;
  final double weightKg;

  ColData({
    required this.id,
    required this.siloId,
    required this.recordDate,
    required this.weightKg,
  });

  factory ColData.fromJson(Map<String, dynamic> json) {
    return ColData(
      id: json['id'] ?? 0,
      siloId: json['siloId'] ?? '',
      recordDate: json['recordDate'] ?? '',
      weightKg: (json['weightKg'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siloId': siloId,
      'recordDate': recordDate,
      'weightKg': weightKg,
    };
  }
}
