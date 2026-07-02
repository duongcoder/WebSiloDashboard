import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SiloPlanTable extends StatelessWidget {
  final String title;
  final List<int> pumpSiloIds;
  final int? selectedPumpPlanSiloId;
  final List<Map<String, String>> filteredRows;
  final List<Map<String, String>> visibleRows;
  final ScrollController scrollController;
  final ValueChanged<int?> onPlanSiloChanged;
  final Future<void> Function() onExportExcel;
  final Future<void> Function() onAddPlanClick;
  final void Function(Map<String, String> row) onDeletePlan;
  final Color Function(String status) statusColorBuilder;

  const SiloPlanTable({
    super.key,
    required this.title,
    required this.pumpSiloIds,
    required this.selectedPumpPlanSiloId,
    required this.filteredRows,
    required this.visibleRows,
    required this.scrollController,
    required this.onPlanSiloChanged,
    required this.onExportExcel,
    required this.onAddPlanClick,
    required this.onDeletePlan,
    required this.statusColorBuilder,
  });

  double _tableRowMinHeight(bool isMobile) => isMobile ? 46 : 44;

  double _tableColumnSpacing(bool isMobile) => isMobile ? 14 : 22;

  double _tableHorizontalMargin(bool isMobile) => isMobile ? 10 : 16;

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

  Widget _buildStatusBadge(String status, {required bool isMobile}) {
    return Container(
      width: isMobile ? 100 : 110,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: statusColorBuilder(status),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planTitleText = selectedPumpPlanSiloId == null
        ? '$title tổng'
        : '$title silo $selectedPumpPlanSiloId';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          // Header card gồm tiêu đề, bộ lọc, thao tác xuất/thêm.
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
                      width: isMobile ? constraints.maxWidth : 360,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              planTitleText,
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
                                value: selectedPumpPlanSiloId,
                                isDense: true,
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Tổng các Silo'),
                                  ),
                                  ...pumpSiloIds.map(
                                    (id) => DropdownMenuItem<int?>(
                                      value: id,
                                      child: Text('Silo $id'),
                                    ),
                                  ),
                                ],
                                onChanged: onPlanSiloChanged,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await onExportExcel();
                      },
                      icon: const Icon(Icons.table_view),
                      label: const Text('Xuất excel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await onAddPlanClick();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm kế hoạch'),
                    ),
                    _buildInfoBadge('Hiển thị: ${visibleRows.length}'),
                  ],
                ),
              ),
              // Bảng danh sách kế hoạch đồng bộ desktop/mobile.
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
                          const DataColumn(label: Text('Tên silo')),
                          const DataColumn(label: Text('Thời gian')),
                          if (!isMobile) const DataColumn(label: Text('Nguyên liệu')),
                          const DataColumn(label: Text('Số lượng'), numeric: true),
                          const DataColumn(label: Text('Trạng thái')),
                          const DataColumn(label: Text('Xóa')),
                        ],
                        rows: List<DataRow>.generate(visibleRows.length, (index) {
                          final row = visibleRows[index];
                          final status = row['status'] ?? '';

                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 56,
                                  child: Text('${index + 1}'),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    row['silo'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: isMobile ? 220 : 240,
                                  child: Text(
                                    row['time'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (!isMobile)
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      row['material'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              DataCell(
                                SizedBox(
                                  width: 90,
                                  child: Text(row['qty'] ?? ''),
                                ),
                              ),
                              DataCell(
                                _buildStatusBadge(status, isMobile: isMobile),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 56,
                                  child: IconButton(
                                    tooltip: 'Xóa kế hoạch',
                                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                                    onPressed: () => onDeletePlan(row),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
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