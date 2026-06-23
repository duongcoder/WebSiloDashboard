import 'dart:html' as html;
import 'dart:typed_data';

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

Future<ExcelExportResult> _downloadByAnchor({
  required Uint8List bytes,
  required String fileName,
}) async {
  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return ExcelExportResult(
    success: true,
    message:
        'Đã tạo file Excel để tải về: $fileName. Nếu trình duyệt bật hỏi nơi lưu, bạn có thể tự chọn thư mục.',
  );
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
    final fileName =
      (downloadFileName != null && downloadFileName.trim().isNotEmpty)
      ? downloadFileName.trim()
      : '${timeLabel}_${dateLabel}_$tableLabel.xlsx';

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

    final bytes = Uint8List.fromList(encoded);
    return _downloadByAnchor(bytes: bytes, fileName: fileName);
  } catch (e) {
    return ExcelExportResult(
      success: false,
      message: 'Xuất Excel thất bại: $e',
    );
  }
}
