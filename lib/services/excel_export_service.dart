import '../services/statistics_report_helper.dart';

import 'excel_export_service_stub.dart'
    if (dart.library.io) 'excel_export_service_io.dart'
    if (dart.library.html) 'excel_export_service_web.dart' as impl;

class ExcelExportResult {
  final bool success;
  final String message;
  final String? filePath;

  const ExcelExportResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}

class SiloStatusExportItem {
  final int stt;
  final String siloName;
  final String weightText;
  final String levelText;
  final String status;
  final String updatedAt;

  const SiloStatusExportItem({
    required this.stt,
    required this.siloName,
    required this.weightText,
    required this.levelText,
    required this.status,
    required this.updatedAt,
  });
}

class SiloAlertExportItem {
  final int stt;
  final String siloName;
  final String alertType;
  final String severity;
  final String timestamp;
  final String status;

  const SiloAlertExportItem({
    required this.stt,
    required this.siloName,
    required this.alertType,
    required this.severity,
    required this.timestamp,
    required this.status,
  });
}

Future<ExcelExportResult> exportSiloStatusToExcel({
  required List<SiloStatusExportItem> items,
  String? downloadFileName,
}) {
  return impl.exportSiloStatusToExcel(
    items: items,
    downloadFileName: downloadFileName,
  );
}

Future<ExcelExportResult> exportAlertsToExcel({
  required List<SiloAlertExportItem> items,
  String? downloadFileName,
}) {
  return impl.exportAlertsToExcel(
    items: items,
    downloadFileName: downloadFileName,
  );
}

Future<ExcelExportResult> exportStatisticsReportToExcel({
  required String filePrefix,
  required List<CompressedStatisticsReportItem> rows,
  int? selectedSiloId,
  String? downloadFileName,
}) {
  return impl.exportStatisticsReportToExcel(
    filePrefix: filePrefix,
    rows: rows,
    selectedSiloId: selectedSiloId,
    downloadFileName: downloadFileName,
  );
}

Future<ExcelExportResult> exportPlanRowsToExcel({
  required String filePrefix,
  required List<Map<String, String>> rows,
  String? downloadFileName,
}) {
  return impl.exportPlanRowsToExcel(
    filePrefix: filePrefix,
    rows: rows,
    downloadFileName: downloadFileName,
  );
}
