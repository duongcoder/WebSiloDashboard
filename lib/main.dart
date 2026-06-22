import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:signalr_core/signalr_core.dart';

import 'config/app_config.dart';
import 'models/col_data.dart';
import 'models/controller.dart';
import 'models/indicator.dart';
import 'models/silo.dart';
import 'services/scale_service.dart';
import 'services/excel_export_service.dart';
import 'services/sql_service.dart';
import 'widgets/silo_module.dart';

void main() {
  runApp(const SiloDashboardApp());
}

class SiloDashboardApp extends StatelessWidget {
  const SiloDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Silo Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
          Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = -1;
  late HubConnection hubConnection;
  double? _currentWeight;

  List<Silo> _silos = [];
  List<Controller> _controllers = [];
  List<Indicator> _indicators = [];
  List<ColData> _colData = [];

  List<Map<String, String>> _pumpPlanRows = [];
  Timer? _pumpTimer;

  final List<Map<String, String>> _dumpPlanRows = [
    {
      'time': '08:00 - 08:20',
      'silo': 'Silo 1',
      'material': 'Thóc',
      'qty': '260',
      'status': 'Chờ',
    },
    {
      'time': '08:20 - 08:40',
      'silo': 'Silo 3',
      'material': 'Gạo',
      'qty': '180',
      'status': 'Đang bơm',
    },
    {
      'time': '08:40 - 09:00',
      'silo': 'Silo 5',
      'material': 'Đậu',
      'qty': '140',
      'status': 'Đã xong',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initSignalR();
    _loadSilos();
    _loadIndicators();
    _loadControllers();
    _loadColData();
    _loadScales();

    _pumpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchPumpPlan();
    });
  }

  @override
  void dispose() {
    _pumpTimer?.cancel();
    hubConnection.stop();
    super.dispose();
  }

  Future<void> _fetchPumpPlan() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/Schedulers/GetSchedulers'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> schedulers = data['schedulers'];

        setState(() {
          _pumpPlanRows = schedulers.map((item) {
            return {
              'time': (item['timeStart'] ?? '').toString(),
              'silo': 'Silo ${item['id_relay']}',
              'material': (item['des'] ?? '').toString(),
              'qty': (item['weight'] ?? '').toString(),
              'status': _mapStatus(item['status'] as int),
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching pump plan: $e');
    }
  }

  String _mapStatus(int status) {
    switch (status) {
      case 0:
        return 'Sẵn sàng';
      case 1:
        return 'Đang bơm';
      case 2:
        return 'Đã xong';
      default:
        return 'Chờ';
    }
  }

  Future<void> _initSignalR() async {
    hubConnection = HubConnectionBuilder()
        .withUrl('http://${AppConfig.serverIp}:${AppConfig.apiPort}/siloHub')
        .build();

    hubConnection.on('ReceiveScaleValue', (List<Object?>? args) {
      if (args == null || args.isEmpty) return;

      final raw = args[0];

      if (raw is Map<String, dynamic>) {
        setState(() {
          _currentWeight = (raw['value'] as num).toDouble();
        });
      } else if (raw is String) {
        final data = jsonDecode(raw);
        setState(() {
          _currentWeight = (data['value'] as num).toDouble();
        });
      } else if (raw is num) {
        setState(() {
          _currentWeight = raw.toDouble();
        });
      }
    });

    await hubConnection.start();
  }

  Future<void> _loadScales() async {
    try {
      final data = await ScaleService.getListScales();
      setState(() {
        _silos = data.map((e) => Silo.fromJson(e)).toList();
      });
    } catch (e) {
      debugPrint('Error loading scales: $e');
    }
  }

  Future<void> _loadSilos() async {
    try {
      final silos = await ApiService.fetchSilos();
      setState(() {
        _silos = silos;
      });
    } catch (e) {
      debugPrint('Error loading silos: $e');
    }
  }

  Future<void> _loadIndicators() async {
    try {
      final indicators = await ApiService.fetchIndicators();
      setState(() {
        _indicators = indicators;
      });
    } catch (e) {
      debugPrint('Error loading indicators: $e');
    }
  }

  Future<void> _loadControllers() async {
    try {
      final controllers = await ApiService.fetchControllers();
      setState(() {
        _controllers = controllers;
      });
    } catch (e) {
      debugPrint('Error loading controllers: $e');
    }
  }

  Future<void> _loadColData() async {
    try {
      final colDataList = await ApiService.fetchColData();
      setState(() {
        _colData = colDataList;
      });
    } catch (e) {
      debugPrint('Error loading ColData: $e');
    }
  }

  List<Map<String, String>> _getWarningRowsFromSilos({
    required List<Silo> silos,
    required String nowTimeLabel,
  }) {
    String statusByLevel(double level) {
      if (level > 0.2) return 'Đang hoạt động';
      return 'Dừng hoạt động';
    }

    String severityByLevel(double level) {
      if (level < 0.2) return 'Mức thấp';
      if (level <= 0.7) return 'Trung bình';
      return 'Mức cao';
    }

    String contentByLevel(double level) {
      final pct = (level * 100).toInt();
      if (level < 0.2) return 'Mức chứa thấp: $pct%';
      if (level <= 0.7) return 'Mức chứa trung bình: $pct%';
      return 'Mức chứa cao: $pct%';
    }

    return silos.map((silo) {
      return {
        'time': nowTimeLabel,
        'silo': silo.id,
        'content': contentByLevel(silo.level),
        'severity': severityByLevel(silo.level),
        'status': statusByLevel(silo.level),
      };
    }).toList();
  }

  void _select(int index, String label) {
    setState(() {
      _selectedIndex = index;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();

    if (s.contains('đang hoạt động') || s.contains('dang hoat dong')) {
      return Colors.green.shade200;
    }
    if (s.contains('dừng hoạt động') || s.contains('dung hoat dong')) {
      return Colors.red.shade200;
    }

    if (s.contains('sẵn') || s.contains('san') || s.contains('sẵn sàng')) {
      return Colors.green.shade200;
    }
    if (s.contains('chờ') || s.contains('cho')) return Colors.yellow.shade200;
    if (s.contains('lỗi') || s.contains('loi')) return Colors.red.shade200;
    if (s.contains('đang bơm') || s.contains('dang bom')) {
      return Colors.green.shade200;
    }
    if (s.contains('đã xong') || s.contains('da xong')) {
      return Colors.blue.shade200;
    }

    return Colors.grey.shade200;
  }

  Color _severityColor(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('mức thấp') || s.contains('muc thap')) return Colors.red.shade200;
    if (s.contains('trung bình') || s.contains('trung binh')) {
      return Colors.yellow.shade200;
    }
    if (s.contains('mức cao') || s.contains('muc cao')) return Colors.green.shade200;
    return Colors.grey.shade200;
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int index,
    required int selectedIndex,
    required VoidCallback onTap,
  }) {
    final selected = selectedIndex == index;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? Colors.blue.shade50 : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.blue.shade300 : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.blue.shade700 : Colors.blue.shade100,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : Colors.blue.shade800,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.blue.shade900 : Colors.black87,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.chevron_right, color: Colors.blue.shade700, size: 18),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _sidebarMenuConfig {
    return const [
      {'icon': Icons.dashboard_customize, 'label': 'Tổng quan'},
      {'icon': Icons.storage, 'label': 'Giám sát silo'},
      {'icon': Icons.autorenew, 'label': 'Kế hoạch bơm/xả'},
      {'icon': Icons.history, 'label': 'Lịch sử'},
      {'icon': Icons.warning_amber_rounded, 'label': 'Cảnh báo'},
      {'icon': Icons.description, 'label': 'Báo cáo'},
      {'icon': Icons.devices_other, 'label': 'Thiết bị'},
      {'icon': Icons.settings_applications, 'label': 'Cài đặt'},
      {'icon': Icons.group, 'label': 'Quản lý người dùng'},
    ];
  }

  List<Widget> _buildSidebarMenuItems({required bool closeDrawerAfterTap}) {
    final widgets = <Widget>[];

    for (var i = 0; i < _sidebarMenuConfig.length; i++) {
      final item = _sidebarMenuConfig[i];
      widgets.add(
        _buildSidebarItem(
          icon: item['icon'] as IconData,
          label: item['label'] as String,
          index: i,
          selectedIndex: _selectedIndex,
          onTap: () {
            _select(i, item['label'] as String);
            if (closeDrawerAfterTap) {
              Navigator.of(context).maybePop();
            }
          },
        ),
      );

      if (i < _sidebarMenuConfig.length - 1) {
        widgets.add(const SizedBox(height: 10));
      }
    }

    return widgets;
  }

  Widget _buildSidebar(double sidebarWidth) {
    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 78,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade500],
              ),
            ),
            child: const Center(
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              children: _buildSidebarMenuItems(closeDrawerAfterTap: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(double maxWidth) {
    final stats = <Map<String, dynamic>>[
      {'title': 'Tổng khối lượng', 'value': '1,245.32 tấn', 'color': Colors.blue},
      {'title': 'Silo hoạt động', 'value': '22/24', 'color': Colors.green},
      {'title': 'Silo mức thấp', 'value': '3 silo', 'color': Colors.orange},
      {'title': 'Cảnh báo', 'value': '5 cảnh báo', 'color': Colors.red},
      {'title': 'Lượng ăn hôm nay', 'value': '18.52 tấn', 'color': Colors.purple},
    ];

    int crossAxisCount;
    if (maxWidth >= 1500) {
      crossAxisCount = 5;
    } else if (maxWidth >= 1000) {
      crossAxisCount = 3;
    } else if (maxWidth >= 640) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    final childAspectRatio = maxWidth < 640 ? 3.2 : 3.6;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final item = stats[index];
        return _buildStatCard(
          item['title'] as String,
          item['value'] as String,
          item['color'] as Color,
        );
      },
    );
  }

  Widget _buildColDataChart() {
    final sampleData = [
      {'date': '06-10', 'weight': 1200.0},
      {'date': '06-11', 'weight': 1350.0},
      {'date': '06-12', 'weight': 980.0},
      {'date': '06-13', 'weight': 1500.0},
      {'date': '06-14', 'weight': 1100.0},
      {'date': '06-15', 'weight': 1600.0},
      {'date': '06-16', 'weight': 1400.0},
    ];

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= sampleData.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    sampleData[index]['date'] as String,
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          barGroups: sampleData.asMap().entries.map((entry) {
            final index = entry.key;
            final weight = entry.value['weight'] as double;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: weight,
                  color: Colors.blue,
                  width: 26,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }).toList(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                return BarTooltipItem(
                  '${rod.toY.toStringAsFixed(0)} kg',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModulesAndChartSection(double maxWidth) {
    int crossAxisCount;
    if (maxWidth >= 1500) {
      crossAxisCount = 4;
    } else if (maxWidth >= 1050) {
      crossAxisCount = 3;
    } else if (maxWidth >= 680) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    final moduleCardAspectRatio = switch (crossAxisCount) {
      1 => 1.06,
      2 => 1.0,
      3 => 0.93,
      _ => 0.88,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          // Giữ card Silo đủ cao để nội dung không bị dồn khi responsive desktop.
          childAspectRatio: moduleCardAspectRatio,
          children: _silos.asMap().entries.map((entry) {
            final idx = entry.key;
            final silo = entry.value;

            final indicatorsForSilo = _indicators.isNotEmpty
                ? <Indicator>[_indicators[idx % _indicators.length]]
                : <Indicator>[];

            final controllersForSilo = _controllers.isNotEmpty
                ? <Controller>[_controllers[idx % _controllers.length]]
                : <Controller>[];

            return SiloModule(
              id: silo.id,
              currentWeight: _currentWeight,
              level: silo.level,
              indicators: indicatorsForSilo,
              controllers: controllersForSilo,
              silos: _silos,
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          'Biểu đồ khối lượng Silo1',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        _buildColDataChart(),
      ],
    );
  }

  Widget _buildWarningTableCard({required List<Map<String, String>> rows}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text(
              'Bảng cảnh báo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: DataTable(
                headingRowColor: WidgetStateProperty.resolveWith(
                  (states) => Colors.orange.shade50,
                ),
                dataRowMinHeight: 44,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Thời gian')),
                  DataColumn(label: Text('Silo')),
                  DataColumn(label: Text('Nội dung')),
                  DataColumn(label: Text('Mức độ')),
                  DataColumn(label: Text('Trạng thái')),
                ],
                rows: List<DataRow>.generate(rows.length, (index) {
                  final row = rows[index];
                  final status = row['status'] ?? '';
                  final severity = row['severity'] ?? '';

                  return DataRow(
                    cells: [
                      DataCell(Text(row['time'] ?? '')),
                      DataCell(Text(row['silo'] ?? '')),
                      DataCell(Text(row['content'] ?? '')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _severityColor(severity),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(severity, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(status, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required List<Map<String, String>> rows,
    required String addSnackBarText,
    required String deleteSnackBarText,
    required String exportFilePrefix,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await exportPlanRowsToExcel(
                      filePrefix: exportFilePrefix,
                      rows: rows,
                    );

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.message)),
                    );
                  },
                  icon: const Icon(Icons.table_view),
                  label: const Text('Xuất excel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showDialog<Map<String, String>>(
                      context: context,
                      builder: (dialogContext) {
                        final timeController = TextEditingController();
                        final siloController = TextEditingController();
                        final materialController = TextEditingController();
                        final qtyController = TextEditingController();
                        final statusController = TextEditingController(text: 'Chờ');

                        return AlertDialog(
                          title: const Text('Thêm kế hoạch'),
                          content: SingleChildScrollView(
                            child: Column(
                              children: [
                                TextField(
                                  controller: timeController,
                                  decoration: const InputDecoration(labelText: 'Thời gian'),
                                ),
                                TextField(
                                  controller: siloController,
                                  decoration: const InputDecoration(labelText: 'Silo'),
                                ),
                                TextField(
                                  controller: materialController,
                                  decoration: const InputDecoration(labelText: 'Nguyên liệu'),
                                ),
                                TextField(
                                  controller: qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Số lượng'),
                                ),
                                TextField(
                                  controller: statusController,
                                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: const Text('Hủy'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop({
                                  'time': timeController.text.trim(),
                                  'silo': siloController.text.trim(),
                                  'material': materialController.text.trim(),
                                  'qty': qtyController.text.trim(),
                                  'status': statusController.text.trim(),
                                });
                              },
                              child: const Text('Thêm'),
                            ),
                          ],
                        );
                      },
                    );

                    if (result == null) return;

                    final time = result['time'] ?? '';
                    final silo = result['silo'] ?? '';
                    final material = result['material'] ?? '';
                    final qty = result['qty'] ?? '';
                    final status = result['status'] ?? '';

                    if (time.isEmpty ||
                        silo.isEmpty ||
                        material.isEmpty ||
                        qty.isEmpty ||
                        status.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')),
                      );
                      return;
                    }

                    setState(() {
                      rows.add({
                        'time': time,
                        'silo': silo,
                        'material': material,
                        'qty': qty,
                        'status': status,
                      });
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(addSnackBarText)),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm kế hoạch'),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: DataTable(
                headingRowColor: WidgetStateProperty.resolveWith(
                  (states) => Colors.blue.shade50,
                ),
                dataRowMinHeight: 44,
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Thời gian')),
                  DataColumn(label: Text('Silo')),
                  DataColumn(label: Text('Nguyên liệu')),
                  DataColumn(label: Text('Số lượng'), numeric: true),
                  DataColumn(label: Text('Trạng thái')),
                  DataColumn(label: Text('Xóa')),
                ],
                rows: List<DataRow>.generate(rows.length, (index) {
                  final row = rows[index];
                  final status = row['status'] ?? '';
                  return DataRow(
                    cells: [
                      DataCell(Text(row['time'] ?? '')),
                      DataCell(Text(row['silo'] ?? '')),
                      DataCell(Text(row['material'] ?? '')),
                      DataCell(Text(row['qty'] ?? '')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(status, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: 'Xóa kế hoạch',
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              rows.removeAt(index);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(deleteSnackBarText)),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPumpPlanCard() {
    return _buildPlanCard(
      title: 'Danh sách kế hoạch',
      rows: _pumpPlanRows,
      addSnackBarText: 'Đã thêm kế hoạch',
      deleteSnackBarText: 'Đã xóa kế hoạch',
      exportFilePrefix: 'ke_hoach_bom',
    );
  }

  Widget _buildDumpPlanCard() {
    return _buildPlanCard(
      title: 'Danh sách kế hoạch',
      rows: _dumpPlanRows,
      addSnackBarText: 'Đã thêm kế hoạch xả',
      deleteSnackBarText: 'Đã xóa kế hoạch xả',
      exportFilePrefix: 'ke_hoach_xa',
    );
  }

  Widget _buildPlanAndWarningSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 6, top: 8, bottom: 8),
          child: const Text(
            'Kế hoạch Bơm',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        _buildPumpPlanCard(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(left: 6, top: 8, bottom: 8),
          child: const Text(
            'Kế hoạch Xả',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        _buildDumpPlanCard(),
        _buildWarningTableCard(
          rows: _getWarningRowsFromSilos(
            silos: _silos,
            nowTimeLabel: 'Ngay hiện tại',
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDashboard(double maxWidth) {
    final horizontalPadding = maxWidth < 640 ? 10.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Silo Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            children: _buildSidebarMenuItems(closeDrawerAfterTap: true),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatsSection(maxWidth),
                const SizedBox(height: 16),
                _buildModulesAndChartSection(maxWidth),
                const SizedBox(height: 16),
                _buildPlanAndWarningSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDashboard(double sidebarWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    final rightPanelWidth = (screenWidth * 0.30).clamp(420.0, 560.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                border: Border.all(color: Colors.blue.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.shade700,
                    ),
                    child: const Icon(Icons.cloud, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Silo Dashboard',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Giám sát & Điều khiển hệ thống cân định lượng',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.notifications, color: Colors.black54, size: 32),
                      const SizedBox(width: 22),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade700,
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Admin',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Quản trị hệ thống',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSidebar(sidebarWidth),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildStatsSection(MediaQuery.of(context).size.width),
                          ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return _buildModulesAndChartSection(
                                          constraints.maxWidth,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: rightPanelWidth,
                                  child: SingleChildScrollView(
                                    child: _buildPlanAndWarningSection(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const sidebarWidth = 280.0;
    final screenWidth = MediaQuery.of(context).size.width;

    if (_controllers.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (screenWidth < 1100) {
      return _buildCompactDashboard(screenWidth);
    }

    return _buildDesktopDashboard(sidebarWidth);
  }
}
