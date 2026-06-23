import 'dart:io';

import 'package:excel/excel.dart';

import 'excel_export_service.dart';

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

String _tableLabel(String filePrefix) {
  final normalized = filePrefix.toLowerCase();
  if (normalized.contains('bom')) return 'Bom';
  if (normalized.contains('xa')) return 'Xa';
  return filePrefix;
}

Future<ExcelExportResult> exportPlanRowsToExcel({
  required String filePrefix,
  required List<Map<String, String>> rows,
  String? downloadFileName,
}) async {
  try {
    final now = DateTime.now();
    final day = _twoDigits(now.day);
    final month = _twoDigits(now.month);
    final year = _twoDigits(now.year % 100);
    final dateLabel = '$day-$month-$year';
    final timeLabel =
        '${_twoDigits(now.hour)}-${_twoDigits(now.minute)}-${_twoDigits(now.second)}';
    final tableLabel = _tableLabel(filePrefix);

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    sheet.appendRow([
      TextCellValue('Thời gian'),
      TextCellValue('Silo'),
      TextCellValue('Nguyên liệu'),
      TextCellValue('Số lượng'),
      TextCellValue('Trạng thái'),
    ]);

    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row['time'] ?? ''),
        TextCellValue(row['silo'] ?? ''),
        TextCellValue(row['material'] ?? ''),
        TextCellValue(row['qty'] ?? ''),
        TextCellValue(row['status'] ?? ''),
      ]);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      return const ExcelExportResult(
        success: false,
        message: 'Không thể tạo dữ liệu Excel.',
      );
    }

    final exportsDirPath =
      '${Directory.current.path}${Platform.pathSeparator}exports${Platform.pathSeparator}$day${Platform.pathSeparator}$month${Platform.pathSeparator}$year';
    final exportsDir = Directory(exportsDirPath);
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final defaultFileName = '${timeLabel}_${dateLabel}_$tableLabel.xlsx';
    final fileName =
      (downloadFileName != null && downloadFileName.trim().isNotEmpty)
      ? downloadFileName.trim()
      : defaultFileName;
    final filePath = '${exportsDir.path}${Platform.pathSeparator}$fileName';

    final file = File(filePath);
    await file.writeAsBytes(encoded, flush: true);

    return ExcelExportResult(
      success: true,
      message: 'Đã xuất Excel: $filePath',
      filePath: filePath,
    );
  } catch (e) {
    return ExcelExportResult(
      success: false,
      message: 'Xuất Excel thất bại: $e',
    );
  }
}
