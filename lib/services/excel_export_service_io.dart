import 'dart:io';

import 'package:excel/excel.dart';

import '../services/statistics_report_helper.dart';
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

List<int>? _buildSiloStatusExcel({
  required List<SiloStatusExportItem> items,
}) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];

  final borderGrid = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('#D1D5DB'),
  );

  final titleStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
    fontColorHex: ExcelColor.white,
    fontSize: 16,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: borderGrid,
    rightBorder: borderGrid,
    topBorder: borderGrid,
    bottomBorder: borderGrid,
  );

  final subTitleStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
    fontColorHex: ExcelColor.fromHexString('#334155'),
    fontSize: 11,
    italic: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: borderGrid,
    rightBorder: borderGrid,
    topBorder: borderGrid,
    bottomBorder: borderGrid,
  );

  final headerStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
    fontColorHex: ExcelColor.white,
    fontSize: 12,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: borderGrid,
    rightBorder: borderGrid,
    topBorder: borderGrid,
    bottomBorder: borderGrid,
  );

  final now = DateTime.now();
  final day = _twoDigits(now.day);
  final month = _twoDigits(now.month);
  final year = now.year.toString();
  final hour = _twoDigits(now.hour);
  final minute = _twoDigits(now.minute);
  final timeStr = '$day/$month/$year $hour:$minute';

  // Row 0: Title Block (Merged A1:F1)
  final titleStart = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0);
  final titleEnd = CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0);
  sheet.merge(titleStart, titleEnd, customValue: TextCellValue('BÁO CÁO TRẠNG THÁI HOẠT ĐỘNG SILO - FEEDFARM'));
  sheet.setMergedCellStyle(titleStart, titleStyle);

  // Row 1: Sub-header Block (Merged A2:F2)
  final subStart = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1);
  final subEnd = CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1);
  sheet.merge(subStart, subEnd, customValue: TextCellValue('Thời gian xuất: $timeStr'));
  sheet.setMergedCellStyle(subStart, subTitleStyle);

  // Row 2: Headers
  final headers = [
    'STT',
    'Tên Silo',
    'Khối lượng',
    'Mức đầy (%)',
    'Trạng thái',
    'Cập nhật',
  ];

  for (var col = 0; col < headers.length; col++) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2));
    cell.value = TextCellValue(headers[col]);
    cell.cellStyle = headerStyle;
  }

  // Minimum column widths
  final colWidths = <double>[10.0, 16.0, 18.0, 18.0, 22.0, 26.0];

  // Data rows starting at Row 3
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final rowIndex = 3 + i;

    ExcelColor statusColor = ExcelColor.fromHexString('#64748B');
    switch (item.status) {
      case 'Bình thường':
        statusColor = ExcelColor.fromHexString('#16A34A');
        break;
      case 'Mức thấp':
        statusColor = ExcelColor.fromHexString('#D97706');
        break;
      case 'Cảnh báo':
        statusColor = ExcelColor.fromHexString('#DC2626');
        break;
      default:
        statusColor = ExcelColor.fromHexString('#64748B');
        break;
    }

    final cellData = [
      (text: '${item.stt}', align: HorizontalAlign.Center, color: ExcelColor.fromHexString('#0F172A'), bold: false),
      (text: item.siloName, align: HorizontalAlign.Center, color: ExcelColor.fromHexString('#0F172A'), bold: true),
      (text: item.weightText, align: HorizontalAlign.Right, color: ExcelColor.fromHexString('#0F172A'), bold: false),
      (text: item.levelText, align: HorizontalAlign.Right, color: ExcelColor.fromHexString('#0F172A'), bold: false),
      (text: item.status, align: HorizontalAlign.Center, color: statusColor, bold: true),
      (text: item.updatedAt, align: HorizontalAlign.Center, color: ExcelColor.fromHexString('#334155'), bold: false),
    ];

    for (var col = 0; col < cellData.length; col++) {
      final cData = cellData[col];
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = TextCellValue(cData.text);
      cell.cellStyle = CellStyle(
        fontColorHex: cData.color,
        fontSize: 11,
        bold: cData.bold,
        horizontalAlign: cData.align,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borderGrid,
        rightBorder: borderGrid,
        topBorder: borderGrid,
        bottomBorder: borderGrid,
      );

      final calculatedWidth = (cData.text.length + 4).toDouble();
      if (calculatedWidth > colWidths[col]) {
        colWidths[col] = calculatedWidth;
      }
    }
  }

  for (var col = 0; col < colWidths.length; col++) {
    sheet.setColumnWidth(col, colWidths[col]);
  }

  return excel.encode();
}

Future<ExcelExportResult> exportSiloStatusToExcel({
  required List<SiloStatusExportItem> items,
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

    final encoded = _buildSiloStatusExcel(items: items);
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

    final defaultFileName = 'TrangThaiSilo_${timeLabel}_$dateLabel.xlsx';
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

List<int>? _buildStatisticsReportExcel({
  required List<CompressedStatisticsReportItem> rows,
  int? selectedSiloId,
}) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];

  final borderGrid = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('#D1D5DB'),
  );

  final titleStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
    fontColorHex: ExcelColor.white,
    fontSize: 16,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: borderGrid,
    rightBorder: borderGrid,
    topBorder: borderGrid,
    bottomBorder: borderGrid,
  );

  final subTitleStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
    fontColorHex: ExcelColor.fromHexString('#334155'),
    fontSize: 11,
    italic: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: borderGrid,
    rightBorder: borderGrid,
    topBorder: borderGrid,
    bottomBorder: borderGrid,
  );

  final headerStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
    fontColorHex: ExcelColor.white,
    fontSize: 12,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: borderGrid,
    rightBorder: borderGrid,
    topBorder: borderGrid,
    bottomBorder: borderGrid,
  );

  final now = DateTime.now();
  final day = _twoDigits(now.day);
  final month = _twoDigits(now.month);
  final year = now.year.toString();
  final hour = _twoDigits(now.hour);
  final minute = _twoDigits(now.minute);
  final timeStr = '$day/$month/$year $hour:$minute';

  final titleText = selectedSiloId == null
      ? 'BÁO CÁO THỐNG KÊ TỔNG - FEEDFARM SILO SYSTEM'
      : 'BÁO CÁO THỐNG KÊ SILO $selectedSiloId - FEEDFARM SILO SYSTEM';

  // Row 0: Title Block (Merged A1:G1)
  final titleStart = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0);
  final titleEnd = CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0);
  sheet.merge(titleStart, titleEnd, customValue: TextCellValue(titleText));
  sheet.setMergedCellStyle(titleStart, titleStyle);

  // Row 1: Sub-header Block (Merged A2:G2)
  final subStart = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1);
  final subEnd = CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1);
  sheet.merge(subStart, subEnd, customValue: TextCellValue('Thời gian xuất báo cáo: $timeStr'));
  sheet.setMergedCellStyle(subStart, subTitleStyle);

  // Row 2: Headers
  final headers = [
    'STT',
    'ID Cân / Silo',
    'Số cân (+/- kg)',
    'Khối lượng trước',
    'Khối lượng sau',
    'Thời gian',
    'Chi tiết',
  ];

  for (var col = 0; col < headers.length; col++) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2));
    cell.value = TextCellValue(headers[col]);
    cell.cellStyle = headerStyle;
  }

  // Column width defaults (minimums)
  final colWidths = <double>[10.0, 16.0, 20.0, 22.0, 22.0, 32.0, 45.0];

  // Data rows starting at Row 3
  for (var i = 0; i < rows.length; i++) {
    final item = rows[i];
    final rowIndex = 3 + i;

    final changeText = item.weightChangeText;
    ExcelColor changeColor = ExcelColor.fromHexString('#0F172A');
    if (changeText.startsWith('+')) {
      changeColor = ExcelColor.fromHexString('#16A34A');
    } else if (changeText.startsWith('-')) {
      changeColor = ExcelColor.fromHexString('#DC2626');
    }

    final cellData = [
      (text: '${i + 1}', align: HorizontalAlign.Center, color: ExcelColor.fromHexString('#0F172A'), bold: false),
      (text: 'Silo ${item.milestone.idScale}', align: HorizontalAlign.Center, color: ExcelColor.fromHexString('#0F172A'), bold: false),
      (text: changeText, align: HorizontalAlign.Right, color: changeColor, bold: true),
      (text: '${item.weightBefore.toStringAsFixed(0)} kg', align: HorizontalAlign.Right, color: ExcelColor.fromHexString('#0F172A'), bold: false),
      (text: '${item.weightAfter.toStringAsFixed(0)} kg', align: HorizontalAlign.Right, color: ExcelColor.fromHexString('#0F172A'), bold: false),
      (text: item.timeRangeText, align: HorizontalAlign.Center, color: ExcelColor.fromHexString('#334155'), bold: false),
      (text: item.detailText, align: HorizontalAlign.Left, color: ExcelColor.fromHexString('#334155'), bold: false),
    ];

    for (var col = 0; col < cellData.length; col++) {
      final cData = cellData[col];
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = TextCellValue(cData.text);
      cell.cellStyle = CellStyle(
        fontColorHex: cData.color,
        fontSize: 11,
        bold: cData.bold,
        horizontalAlign: cData.align,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borderGrid,
        rightBorder: borderGrid,
        topBorder: borderGrid,
        bottomBorder: borderGrid,
      );

      final calculatedWidth = (cData.text.length + 4).toDouble();
      if (calculatedWidth > colWidths[col]) {
        colWidths[col] = calculatedWidth;
      }
    }
  }

  for (var col = 0; col < colWidths.length; col++) {
    sheet.setColumnWidth(col, colWidths[col]);
  }

  return excel.encode();
}

Future<ExcelExportResult> exportStatisticsReportToExcel({
  required String filePrefix,
  required List<CompressedStatisticsReportItem> rows,
  int? selectedSiloId,
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

    final encoded = _buildStatisticsReportExcel(rows: rows, selectedSiloId: selectedSiloId);
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

    final defaultFileName = 'ThongKe_${timeLabel}_$dateLabel.xlsx';
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

Future<ExcelExportResult> exportAlertsToExcel({
  required List<SiloAlertExportItem> items,
  String? downloadFileName,
}) async {
  try {
    final now = DateTime.now();
    final day = _twoDigits(now.day);
    final month = _twoDigits(now.month);
    final year = now.year.toString();
    final hour = _twoDigits(now.hour);
    final minute = _twoDigits(now.minute);
    final second = _twoDigits(now.second);

    final encoded = _buildAlertsExcel(items: items);
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

    final defaultFileName = 'CanhBao_$day-$month-${year}_$hour-$minute-$second.xlsx';
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

List<int>? _buildAlertsExcel({
  required List<SiloAlertExportItem> items,
}) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];

  final borderGrid = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('#D1D5DB'),
  );

  final titleStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
    fontColorHex: ExcelColor.white,
    fontSize: 16,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: borderGrid,
    rightBorder: borderGrid,
    topBorder: borderGrid,
    bottomBorder: borderGrid,
  );

  final subTitleStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
    fontColorHex: ExcelColor.fromHexString('#334155'),
    fontSize: 11,
    italic: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: borderGrid,
    rightBorder: borderGrid,
    topBorder: borderGrid,
    bottomBorder: borderGrid,
  );

  final headerStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
    fontColorHex: ExcelColor.white,
    fontSize: 12,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: borderGrid,
    rightBorder: borderGrid,
    topBorder: borderGrid,
    bottomBorder: borderGrid,
  );

  final now = DateTime.now();
  final timeStr =
      '${_twoDigits(now.day)}/${_twoDigits(now.month)}/${now.year} ${_twoDigits(now.hour)}:${_twoDigits(now.minute)}';

  // Row 0: Title Block (Merged A1:F1)
  final titleStart = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0);
  final titleEnd = CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0);
  sheet.merge(
    titleStart,
    titleEnd,
    customValue: TextCellValue('DANH SÁCH CẢNH BÁO HỆ THỐNG SILO - FEEDFARM'),
  );
  sheet.setMergedCellStyle(titleStart, titleStyle);

  // Row 1: Sub-header Block (Merged A2:F2)
  final subStart = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1);
  final subEnd = CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1);
  sheet.merge(
    subStart,
    subEnd,
    customValue: TextCellValue(
      'Thời gian xuất: $timeStr | Tổng số cảnh báo: ${items.length}',
    ),
  );
  sheet.setMergedCellStyle(subStart, subTitleStyle);

  // Row 2: Headers
  final headers = [
    'STT',
    'Silo / Thiết bị',
    'Loại cảnh báo',
    'Mức độ',
    'Thời gian ghi nhận',
    'Trạng thái xử lý',
  ];

  for (var col = 0; col < headers.length; col++) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2),
    );
    cell.value = TextCellValue(headers[col]);
    cell.cellStyle = headerStyle;
  }

  final colWidths = <double>[10.0, 18.0, 22.0, 18.0, 26.0, 20.0];

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final rowIndex = 3 + i;

    ExcelColor severityColor = ExcelColor.fromHexString('#2563EB');
    if (item.severity == 'Nguy hiểm') {
      severityColor = ExcelColor.fromHexString('#DC2626');
    } else if (item.severity == 'Cảnh báo') {
      severityColor = ExcelColor.fromHexString('#D97706');
    }

    final dataCells = [
      (
        0,
        TextCellValue('${item.stt}'),
        HorizontalAlign.Center,
        ExcelColor.fromHexString('#0F172A'),
        false
      ),
      (
        1,
        TextCellValue(item.siloName),
        HorizontalAlign.Left,
        ExcelColor.fromHexString('#0F172A'),
        true
      ),
      (
        2,
        TextCellValue(item.alertType),
        HorizontalAlign.Left,
        ExcelColor.fromHexString('#334155'),
        false
      ),
      (
        3,
        TextCellValue(item.severity),
        HorizontalAlign.Center,
        severityColor,
        true
      ),
      (
        4,
        TextCellValue(item.timestamp),
        HorizontalAlign.Center,
        ExcelColor.fromHexString('#475569'),
        false
      ),
      (
        5,
        TextCellValue(item.status),
        HorizontalAlign.Center,
        item.status == 'Đã xác nhận'
            ? ExcelColor.fromHexString('#16A34A')
            : ExcelColor.fromHexString('#D97706'),
        true
      ),
    ];

    for (final (col, val, align, color, bold) in dataCells) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
      );
      cell.value = val;
      cell.cellStyle = CellStyle(
        fontColorHex: color,
        bold: bold,
        horizontalAlign: align,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borderGrid,
        rightBorder: borderGrid,
        topBorder: borderGrid,
        bottomBorder: borderGrid,
      );

      final valLength = val.value.toString().length;
      if (valLength + 4 > colWidths[col]) {
        colWidths[col] = (valLength + 4).toDouble();
      }
    }
  }

  for (var col = 0; col < colWidths.length; col++) {
    sheet.setColumnWidth(col, colWidths[col]);
  }

  return excel.encode();
}
