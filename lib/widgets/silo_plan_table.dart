import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/silo.dart';

class SiloPlanTable extends StatefulWidget {
  final List<Silo> silos;
  final ScrollController scrollController;
  final Future<void> Function() onExportExcel;
  final bool isCompactOverview;

  const SiloPlanTable({
    super.key,
    required this.silos,
    required this.scrollController,
    required this.onExportExcel,
    this.isCompactOverview = false,
  });

  @override
  State<SiloPlanTable> createState() => _SiloPlanTableState();
}

class _SiloRowData {
  final int siloId;
  final String displayName;
  final double weight;
  final double level;
  final String status;
  final bool hasData;

  const _SiloRowData({
    required this.siloId,
    required this.displayName,
    required this.weight,
    required this.level,
    required this.status,
    required this.hasData,
  });
}

class _SiloPlanTableState extends State<SiloPlanTable> {
  String _selectedStatus = 'Tất cả';

  double _tableColumnSpacing(bool isMobile) => isMobile ? 16 : 24;

  double _tableHorizontalMargin(bool isMobile) => isMobile ? 12 : 16;

  int _extractSiloId(String rawId, int fallback) {
    final direct = int.tryParse(rawId.trim());
    if (direct != null && direct > 0) return direct;
    final extracted = RegExp(r'\d+').firstMatch(rawId)?.group(0);
    final parsed = int.tryParse(extracted ?? '');
    if (parsed != null && parsed > 0) return parsed;
    return fallback;
  }

  Silo? _findSiloForId(int siloId) {
    for (var i = 0; i < widget.silos.length; i++) {
      final s = widget.silos[i];
      if (_extractSiloId(s.id, i + 1) == siloId) {
        return s;
      }
    }
    return null;
  }

  String _getSiloStatus(Silo silo) {
    final percent = silo.level * 100;
    if (percent > 50) return 'Bình thường';
    if (percent >= 20) return 'Mức thấp';
    return 'Cảnh báo';
  }

  Color _getLevelTextColor(double level) {
    final percent = level * 100;
    if (percent > 50) return const Color(0xFF10B981);
    if (percent >= 20) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    switch (status) {
      case 'Bình thường':
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
        break;
      case 'Mức thấp':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        break;
      case 'Cảnh báo':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        break;
      case 'Không có dữ liệu':
      case 'Trống':
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatSiloDisplayName(String rawId) {
    final idText = rawId.trim();
    if (idText.toLowerCase().startsWith('silo')) {
      return idText;
    }
    return idText.isEmpty ? 'Silo' : 'Silo $idText';
  }

  @override
  Widget build(BuildContext context) {
    final nowString = DateFormat('HH:mm:ss dd/MM/yyyy').format(DateTime.now());

    final allRows = List.generate(8, (index) {
      final siloId = index + 1;
      final silo = _findSiloForId(siloId);
      if (silo != null) {
        return _SiloRowData(
          siloId: siloId,
          displayName: _formatSiloDisplayName(silo.id),
          weight: silo.weight,
          level: silo.level,
          status: _getSiloStatus(silo),
          hasData: true,
        );
      } else {
        return _SiloRowData(
          siloId: siloId,
          displayName: 'Silo $siloId',
          weight: 0.0,
          level: 0.0,
          status: 'Không có dữ liệu',
          hasData: false,
        );
      }
    });

    final visibleRows = _selectedStatus == 'Tất cả'
        ? allRows
        : allRows.where((row) => row.status == _selectedStatus).toList();

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

          final double totalContentWidth = widget.isCompactOverview
              ? (40.0 + 90.0 + 110.0 + 120.0)
              : (40.0 + 90.0 + 120.0 + 110.0 + 120.0 + 160.0);
          final int numGaps = widget.isCompactOverview ? 3 : 5;
          final double baseSpacing = _tableColumnSpacing(isMobile);
          final double minTableWidth = totalContentWidth + (numGaps * baseSpacing) + (2 * horizontalMargin);

          double dynamicSpacing = baseSpacing;
          if (availableTableWidth > minTableWidth) {
            dynamicSpacing = (availableTableWidth - totalContentWidth - (2 * horizontalMargin)) / numGaps;
          }

          final actionControls = [
            PopupMenuButton<String>(
              onSelected: (String value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: Colors.white,
              elevation: 3,
              itemBuilder: (context) => [
                for (final statusOption in ['Tất cả', 'Bình thường', 'Mức thấp', 'Cảnh báo', 'Không có dữ liệu'])
                  PopupMenuItem<String>(
                    value: statusOption,
                    child: Text(
                      statusOption,
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
                      _selectedStatus == 'Tất cả' ? 'Trạng thái: Tất cả' : _selectedStatus,
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
            ElevatedButton.icon(
              onPressed: () async {
                await widget.onExportExcel();
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
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: widget.isCompactOverview
                    ? Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Trạng thái hoạt động Silo',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          actionControls[0],
                        ],
                      )
                    : (constraints.maxWidth >= 550
                        ? SizedBox(
                            height: 42,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Center(
                                  child: Text(
                                    'Trạng thái hoạt động Silo',
                                    style: TextStyle(
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
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(
                                child: Text(
                                  'Trạng thái hoạt động Silo',
                                  style: TextStyle(
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
                              maxHeight: widget.isCompactOverview ? 350.0 : double.infinity,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
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
                                columnSpacing: dynamicSpacing,
                                horizontalMargin: horizontalMargin,
                                columns: widget.isCompactOverview
                                    ? const [
                                        DataColumn(label: Text('STT')),
                                        DataColumn(label: Text('Tên Silo')),
                                        DataColumn(label: Text('Mức đầy (%)')),
                                        DataColumn(label: Text('Trạng thái')),
                                      ]
                                    : const [
                                        DataColumn(label: Text('STT')),
                                        DataColumn(label: Text('Tên Silo')),
                                        DataColumn(label: Text('Khối lượng')),
                                        DataColumn(label: Text('Mức đầy (%)')),
                                        DataColumn(label: Text('Trạng thái')),
                                        DataColumn(label: Text('Cập nhật')),
                                      ],
                                rows: visibleRows.isNotEmpty
                                    ? List<DataRow>.generate(visibleRows.length, (index) {
                                        final item = visibleRows[index];
                                        final fillPercent = (item.level * 100).clamp(0.0, 100.0);

                                        final cells = widget.isCompactOverview
                                            ? [
                                                DataCell(
                                                  SizedBox(
                                                    width: 40,
                                                    child: Text('${item.siloId}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14)),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 90,
                                                    child: Text(
                                                      item.displayName,
                                                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 110,
                                                    child: Text(
                                                      item.hasData ? '${fillPercent.toStringAsFixed(1)}%' : '-',
                                                      style: TextStyle(
                                                        color: item.hasData
                                                            ? _getLevelTextColor(item.level)
                                                            : const Color(0xFF94A3B8),
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 120,
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: _buildStatusBadge(item.status),
                                                    ),
                                                  ),
                                                ),
                                              ]
                                            : [
                                                DataCell(
                                                  SizedBox(
                                                    width: 40,
                                                    child: Text('${item.siloId}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14)),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 90,
                                                    child: Text(
                                                      item.displayName,
                                                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 120,
                                                    child: Text(
                                                      item.hasData ? '${item.weight.toStringAsFixed(1)} kg' : '-',
                                                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 110,
                                                    child: Text(
                                                      item.hasData ? '${fillPercent.toStringAsFixed(1)}%' : '-',
                                                      style: TextStyle(
                                                        color: item.hasData
                                                            ? _getLevelTextColor(item.level)
                                                            : const Color(0xFF94A3B8),
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 120,
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: _buildStatusBadge(item.status),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 160,
                                                    child: Text(
                                                      item.hasData ? nowString : '-',
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
                                          cells: widget.isCompactOverview
                                              ? const [
                                                  DataCell(SizedBox(width: 40, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                  DataCell(SizedBox(width: 90, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                  DataCell(SizedBox(width: 110, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                  DataCell(SizedBox(width: 120, child: Text('Chưa có dữ liệu', style: TextStyle(color: Color(0xFF334155), fontSize: 13)))),
                                                ]
                                              : const [
                                                  DataCell(SizedBox(width: 40, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                  DataCell(SizedBox(width: 90, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                  DataCell(SizedBox(width: 120, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                  DataCell(SizedBox(width: 110, child: Text('-', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)))),
                                                  DataCell(SizedBox(width: 120, child: Text('Chưa có dữ liệu', style: TextStyle(color: Color(0xFF334155), fontSize: 13)))),
                                                  DataCell(SizedBox(width: 160, child: Text('-', style: TextStyle(color: Color(0xFF334155), fontSize: 13)))),
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
              ),
            ],
          );
        },
      ),
    );
  }
}