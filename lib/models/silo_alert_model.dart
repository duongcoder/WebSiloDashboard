class SiloAlertModel {
  final int stt;
  final String siloId;
  final String alertType; // Mức thấp, Rất thấp, Lỗi kết nối
  final String severity; // Nguy hiểm, Cảnh báo, Thông tin
  final DateTime timestamp;
  final String status; // Chưa xử lý, Đã xác nhận
  final String message;
  final bool isAcknowledged;

  const SiloAlertModel({
    required this.stt,
    required this.siloId,
    required this.alertType,
    required this.severity,
    required this.timestamp,
    required this.status,
    required this.message,
    this.isAcknowledged = false,
  });

  SiloAlertModel copyWith({
    int? stt,
    String? siloId,
    String? alertType,
    String? severity,
    DateTime? timestamp,
    String? status,
    String? message,
    bool? isAcknowledged,
  }) {
    return SiloAlertModel(
      stt: stt ?? this.stt,
      siloId: siloId ?? this.siloId,
      alertType: alertType ?? this.alertType,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      message: message ?? this.message,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
    );
  }
}
