import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/statistics_report_helper.dart';

class SiloReportTable extends StatelessWidget {
  final List<int> siloIds;
  final int? selectedSiloId;
  final List<CompressedStatisticsReportItem> rows;
  final ScrollController scrollController;
  final ValueChanged<int?>? onSiloChanged;
  final Future<void> Function() onExportPressed;

  const SiloReportTable({
    super.key,
    required this.siloIds,
    required this.selectedSiloId,
    required this.rows,
    required this.scrollController,
    required this.onSiloChanged,
    required this.onExportPressed,
  });

  double _tableRowMinHeight(bool isMobile) => isMobile ? 46 : 44;

  double _tableColumnSpacing(bool isMobile) => isMobile ? 14 : 22;

  double _tableHorizontalMargin(bool isMobile) => isMobile ? 10 : 16;

  Color _changeColor(String change) {
    if (change.startsWith('+')) return Colors.green;
    if (change.startsWith('-')) return Colors.red;
    return Colors.black87;
  }

  Widget _buildInfoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue.shade900,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportTitleText = selectedSiloId == null
        ? 'Báo cáo thống kê tổng'
      : 'Báo cáo thống kê silo $selectedSiloId';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          // Header: tiêu đề, bộ lọc silo và hành động xuất excel.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isMobile ? constraints.maxWidth : 380,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              reportTitleText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: selectedSiloId,
                                isDense: true,
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Tổng các Silo'),
                                  ),
                                  ...siloIds.map(
                                    (id) => DropdownMenuItem<int?>(
                                      value: id,
                                      child: Text('Silo $id'),
                                    ),
                                  ),
                                ],
                                onChanged: onSiloChanged,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await onExportPressed();
                      },
                      icon: const Icon(Icons.table_view),
                      label: const Text('Xuất excel'),
                    ),
                    const SizedBox(width: 8),
                    _buildInfoBadge('Hiển thị: ${rows.length}'),
                  ],
                ),
              ),
              // Bảng dữ liệu báo cáo thống kê, giữ nguyên cấu trúc cũ.
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
                  controller: scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.resolveWith(
                          (states) => Colors.blue.shade50,
                        ),
                        dataRowMinHeight: _tableRowMinHeight(isMobile),
                        columnSpacing: _tableColumnSpacing(isMobile),
                        horizontalMargin: _tableHorizontalMargin(isMobile),
                        columns: [
                          const DataColumn(label: Text('STT')),
                          if (!isMobile) const DataColumn(label: Text('ID Cân')),
                          const DataColumn(label: Text('Số cân')),
                          const DataColumn(label: Text('Khối lượng trước')),
                          const DataColumn(label: Text('Khối lượng sau')),
                          const DataColumn(label: Text('Thời gian')),
                          const DataColumn(label: Text('Chi tiết')),
                        ],
                        rows: rows.isNotEmpty
                            ? List<DataRow>.generate(rows.length, (index) {
                                final item = rows[index];

                                final cells = <DataCell>[
                                  DataCell(
                                    SizedBox(
                                      width: 56,
                                      child: Text('${index + 1}'),
                                    ),
                                  ),
                                  if (!isMobile)
                                    DataCell(
                                      SizedBox(
                                        width: 90,
                                        child: Text('${item.milestone.idScale}'),
                                      ),
                                    ),
                                  DataCell(
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        item.weightChangeText,
                                        style: TextStyle(
                                          color: _changeColor(item.weightChangeText),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        '${item.weightBefore.toStringAsFixed(0)} kg',
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        '${item.weightAfter.toStringAsFixed(0)} kg',
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: isMobile ? 220 : 240,
                                      child: Text(
                                        item.timeRangeText,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: isMobile ? 220 : 420,
                                      child: Text(
                                        item.detailText,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ];

                                return DataRow(cells: cells);
                              })
                            : [
                                DataRow(
                                  cells: [
                                    const DataCell(SizedBox(width: 56, child: Text('-'))),
                                    if (!isMobile)
                                      const DataCell(SizedBox(width: 90, child: Text('-'))),
                                    const DataCell(SizedBox(width: 90, child: Text('0 kg'))),
                                    const DataCell(SizedBox(width: 120, child: Text('-'))),
                                    const DataCell(SizedBox(width: 120, child: Text('-'))),
                                    DataCell(
                                      SizedBox(
                                        width: isMobile ? 220 : 240,
                                        child: const Text('Chưa có dữ liệu'),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: isMobile ? 220 : 420,
                                        child: const Text('-'),
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
            ],
          );
        },
      ),
    );
  }
}