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
