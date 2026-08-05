import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/statistics_report_helper.dart';

class SiloReportTable extends StatefulWidget {
  final List<int> siloIds;
  final int? selectedSiloId;
  final List<CompressedStatisticsReportItem> rows;
  final ScrollController scrollController;
  final ValueChanged<int?>? onSiloChanged;
  final Future<void> Function(List<CompressedStatisticsReportItem> filteredRows)? onExportPressed;
  final bool isCompactOverview;

  const SiloReportTable({
    super.key,
    required this.siloIds,
    required this.selectedSiloId,
    required this.rows,
    required this.scrollController,
    required this.onSiloChanged,
    required this.onExportPressed,
    this.isCompactOverview = false,
  });

  @override
  State<SiloReportTable> createState() => _SiloReportTableState();
}

class _SiloReportTableState extends State<SiloReportTable> {
  int _recentLimit = 5;
  String _selectedTimeRange = '1 ngày';

  double _tableColumnSpacing(bool isMobile) => isMobile ? 16 : 24;

  double _tableHorizontalMargin(bool isMobile) => isMobile ? 12 : 16;

  Color _changeColor(String change) {
    if (change.startsWith('+')) return const Color(0xFF10B981);
    if (change.startsWith('-')) return const Color(0xFFEF4444);
    return const Color(0xFF0F172A);
  }

  List<CompressedStatisticsReportItem> _filterRowsByTimeRange(
    List<CompressedStatisticsReportItem> sourceRows,
    String timeRange,
  ) {
    if (sourceRows.isEmpty) return sourceRows;

    Duration duration;
    switch (timeRange) {
      case '1 ngày':
        duration = const Duration(days: 1);
        break;
      case '3 ngày':
        duration = const Duration(days: 3);
        break;
      case '1 tuần':
        duration = const Duration(days: 7);
        break;
      case '1 tháng':
        duration = const Duration(days: 30);
        break;
      default:
        return sourceRows;
    }

    DateTime latestTime = sourceRows.first.milestone.time;
    for (final row in sourceRows) {
      if (row.milestone.time.isAfter(latestTime)) {
        latestTime = row.milestone.time;
      }
    }

    final cutoff = latestTime.subtract(duration);
    final filtered = sourceRows
        .where((row) =>
            row.milestone.time.isAfter(cutoff) ||
            row.milestone.time.isAtSameMomentAs(cutoff))
        .toList();
    return filtered.isNotEmpty ? filtered : sourceRows;
  }

  String _formatDurationText(CompressedStatisticsReportItem item) {
    final fromTime = item.previousMilestone?.time ?? item.milestone.time;
    final toTime = item.milestone.time;
    final minutes = toTime.difference(fromTime).abs().inMinutes;

    if (minutes < 1) {
      return '< 1 phút';
    }
    return 'Trong $minutes phút';
  }

  @override
  Widget build(BuildContext context) {
    final reportTitleText = widget.isCompactOverview
        ? 'Hoạt động gần đây'
        : (widget.selectedSiloId == null
            ? 'Báo cáo thống kê tổng'
            : 'Báo cáo thống kê silo ${widget.selectedSiloId}');

    final filteredFullRows = _filterRowsByTimeRange(widget.rows, _selectedTimeRange);

    final visibleRows = widget.isCompactOverview
        ? widget.rows.take(_recentLimit).toList()
        : filteredFullRows;

    return Container(
      margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final availableTableWidth = (constraints.maxWidth - 24).clamp(0.0, double.infinity);

          final horizontalMargin = _tableHorizontalMargin(isMobile);

          // Dynamic spacing calculation for Compact Overview (4 columns -> 3 gaps)
          const double compactContentWidth = 40.0 + 70.0 + 95.0 + 120.0;
          const double baseCompactSpacing = 16.0;
          final double minCompactWidth = compactContentWidth + (3 * baseCompactSpacing) + (2 * horizontalMargin);
          double dynamicCompactSpacing = baseCompactSpacing;
          if (availableTableWidth > minCompactWidth) {
            dynamicCompactSpacing = (availableTableWidth - compactContentWidth - (2 * horizontalMargin)) / 3;
          }

          // Dynamic spacing calculation for Full Table (7 columns -> 6 gaps)
          final double timeWidth = isMobile ? 220.0 : 240.0;
          final double detailWidth = isMobile ? 220.0 : 420.0;
          final double fullContentWidth = 56.0 + 90.0 + 95.0 + 130.0 + 130.0 + timeWidth + detailWidth;
          final double baseFullSpacing = _tableColumnSpacing(isMobile);
          final double minFullWidth = fullContentWidth + (6 * baseFullSpacing) + (2 * horizontalMargin);
          double dynamicFullSpacing = baseFullSpacing;
          if (availableTableWidth > minFullWidth) {
            dynamicFullSpacing = (availableTableWidth - fullContentWidth - (2 * horizontalMargin)) / 6;
          }

          final actionControls = [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: widget.selectedSiloId,
                  isDense: true,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tổng các Silo'),
                    ),
                    ...widget.siloIds.map(
                      (id) => DropdownMenuItem<int?>(
                        value: id,
                        child: Text('Silo $id'),
                      ),
                    ),
                  ],
                  onChanged: widget.onSiloChanged,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (widget.onExportPressed != null) {
                  await widget.onExportPressed!(filteredFullRows);
                }
              },
              icon: const Icon(Icons.table_view, size: 18),
              label: const Text('Xuất excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (String value) {
                setState(() {
                  _selectedTimeRange = value;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: Colors.white,
              elevation: 3,
              itemBuilder: (context) => [
                for (final range in ['1 ngày', '3 ngày', '1 tuần', '1 tháng'])
                  PopupMenuItem<String>(
                    value: range,
                    child: Text(
                      range,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedTimeRange,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: Color(0xFF475569),
                    ),
                  ],
                ),
              ),
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: widget.isCompactOverview
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              reportTitleText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          PopupMenuButton<int>(
                            onSelected: (int value) {
                              setState(() {
                                _recentLimit = value;
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            color: Colors.white,
                            elevation: 3,
                            itemBuilder: (context) => [
                              const PopupMenuItem<int>(
                                value: 5,
                                child: Text('5 gần nhất', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              ),
                              const PopupMenuItem<int>(
                                value: 10,
                                child: Text('10 gần nhất', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              ),
                              const PopupMenuItem<int>(
                                value: 15,
                                child: Text('15 gần nhất', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_recentLimit gần nhất',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 14,
                                    color: Color(0xFF475569),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : (constraints.maxWidth >= 750
                        ? SizedBox(
                            height: 42,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Center(
                                  child: Text(
                                    reportTitleText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      actionControls[0],
                                      const SizedBox(width: 8),
                                      actionControls[1],
                                      const SizedBox(width: 8),
                                      actionControls[2],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Text(
                                  reportTitleText,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: actionControls,
                              ),
                            ],
                          )),
              ),
              ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.unknown,
                  },
                ),
                child: Scrollbar(
                  controller: widget.scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: widget.scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: availableTableWidth,
                            ),
                            child: widget.isCompactOverview
                                ? DataTable(
                                    showCheckboxColumn: false,
                                    headingRowColor: WidgetStateProperty.resolveWith(
                                      (states) => const Color(0xFFF8FAFC),
                                    ),
                                    headingRowHeight: 46,
                                    dataRowMinHeight: 50,
                                    dataRowMaxHeight: 50,
                                    headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                      fontSize: 15,
                                    ),
                                    dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                                      (states) {
                                        if (states.contains(WidgetState.hovered)) {
                                          return const Color(0xFFF8FAFC);
                                        }
                                        return Colors.transparent;
                                      },
                                    ),
                                    dividerThickness: 1,
                                    border: const TableBorder(
                                      horizontalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                    ),
                                    columnSpacing: dynamicCompactSpacing,
                                    horizontalMargin: horizontalMargin,
                                    columns: const [
                                      DataColumn(label: Text('STT')),
                                      DataColumn(label: Text('Silo')),
                                      DataColumn(label: Text('+/- Số cân')),
                                      DataColumn(label: Text('Thời gian')),
                                    ],
                                    rows: visibleRows.isNotEmpty
                                        ? List<DataRow>.generate(visibleRows.length, (index) {
                                            final item = visibleRows[index];

                                            return DataRow(
                                              onSelectChanged: (_) {},
                                              cells: [
                                                DataCell(
                                                  SizedBox(
                                                    width: 40,
                                                    child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14)),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 70,
                                                    child: Text('Silo ${item.milestone.idScale}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14)),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 95,
                                                    child: Text(
                                                      item.weightChangeText,
                                                      style: TextStyle(
                                                        color: _changeColor(item.weightChangeText),
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 120,
                                                    child: Text(
                                                      _formatDurationText(item),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w500),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          })
                                        : [
                                            DataRow(
                                              onSelectChanged: (_) {},
                                              cells: const [
                                                DataCell(Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14))),
                                                DataCell(Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14))),
                                                DataCell(Text('0 kg', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14))),
                                                DataCell(Text('Chưa có dữ liệu', style: TextStyle(color: Color(0xFF334155), fontSize: 13))),
                                              ],
                                            ),
                                          ],
                                  )
                                : DataTable(
                                    showCheckboxColumn: false,
                                    headingRowColor: WidgetStateProperty.resolveWith(
                                      (states) => const Color(0xFFF8FAFC),
                                    ),
                                    headingRowHeight: 46,
                                    dataRowMinHeight: 50,
                                    dataRowMaxHeight: 50,
                                    headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                      fontSize: 15,
                                    ),
                                    dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                                      (states) {
                                        if (states.contains(WidgetState.hovered)) {
                                          return const Color(0xFFF8FAFC);
                                        }
                                        return Colors.transparent;
                                      },
                                    ),
                                    dividerThickness: 1,
                                    border: const TableBorder(
                                      horizontalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                    ),
                                    columnSpacing: dynamicFullSpacing,
                                    horizontalMargin: horizontalMargin,
                                    columns: const [
                                      DataColumn(label: Text('STT')),
                                      DataColumn(label: Text('ID Cân')),
                                      DataColumn(label: Text('Số cân')),
                                      DataColumn(label: Text('Khối lượng trước')),
                                      DataColumn(label: Text('Khối lượng sau')),
                                      DataColumn(label: Text('Thời gian')),
                                      DataColumn(label: Text('Chi tiết')),
                                    ],
                                    rows: filteredFullRows.isNotEmpty
                                        ? List<DataRow>.generate(filteredFullRows.length, (index) {
                                            final item = filteredFullRows[index];

                                            final cells = <DataCell>[
                                              DataCell(
                                                SizedBox(
                                                  width: 56,
                                                  child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14)),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 90,
                                                  child: Text('${item.milestone.idScale}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14)),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 95,
                                                  child: Text(
                                                    item.weightChangeText,
                                                    style: TextStyle(
                                                      color: _changeColor(item.weightChangeText),
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 130,
                                                  child: Text(
                                                    '${item.weightBefore.toStringAsFixed(0)} kg',
                                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 130,
                                                  child: Text(
                                                    '${item.weightAfter.toStringAsFixed(0)} kg',
                                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: timeWidth,
                                                  child: Text(
                                                    item.timeRangeText,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: detailWidth,
                                                  child: Text(
                                                    item.detailText,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                                                  ),
                                                ),
                                              ),
                                            ];

                                            return DataRow(onSelectChanged: (_) {}, cells: cells);
                                          })
                                        : [
                                            DataRow(
                                              onSelectChanged: (_) {},
                                              cells: [
                                                const DataCell(SizedBox(width: 56, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                const DataCell(SizedBox(width: 90, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                const DataCell(SizedBox(width: 95, child: Text('0 kg', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                const DataCell(SizedBox(width: 130, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                const DataCell(SizedBox(width: 130, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                DataCell(
                                                  SizedBox(
                                                    width: timeWidth,
                                                    child: const Text('Chưa có dữ liệu', style: TextStyle(color: Color(0xFF334155), fontSize: 13)),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: detailWidth,
                                                    child: const Text('-', style: TextStyle(color: Color(0xFF334155), fontSize: 13)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}