import 'excel_export_service.dart';

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
