import '../services/statistics_report_helper.dart';
import 'excel_export_service.dart';

Future<ExcelExportResult> exportSiloStatusToExcel({
  required List<SiloStatusExportItem> items,
  String? downloadFileName,
}) async {
  return const ExcelExportResult(
    success: false,
    message: 'Nền tảng hiện tại chưa hỗ trợ lưu file Excel vào thư mục dự án.',
  );
}

Future<ExcelExportResult> exportAlertsToExcel({
  required List<SiloAlertExportItem> items,
  String? downloadFileName,
}) async {
  return const ExcelExportResult(
    success: false,
    message: 'Nền tảng hiện tại chưa hỗ trợ lưu file Excel vào thư mục dự án.',
  );
}

Future<ExcelExportResult> exportStatisticsReportToExcel({
  required String filePrefix,
  required List<CompressedStatisticsReportItem> rows,
  int? selectedSiloId,
  String? downloadFileName,
}) async {
  return const ExcelExportResult(
    success: false,
    message: 'Nền tảng hiện tại chưa hỗ trợ lưu file Excel vào thư mục dự án.',
  );
}

Future<ExcelExportResult> exportPlanRowsToExcel({
  required String filePrefix,
  required List<Map<String, String>> rows,
  String? downloadFileName,
}) async {
  return const ExcelExportResult(
    success: false,
    message: 'Nền tảng hiện tại chưa hỗ trợ lưu file Excel vào thư mục dự án.',
  );
}
