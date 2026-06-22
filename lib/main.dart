import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:signalr_core/signalr_core.dart';

import 'config/app_config.dart';
import 'models/col_data.dart';
import 'models/controller.dart';
import 'models/indicator.dart';
import 'models/silo.dart';
import 'models/silo_history_model.dart';
import 'services/scale_service.dart';
import 'services/excel_export_service.dart';
import 'services/silo_api_service.dart';
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
  static const Map<String, Duration> _timeframeDurations = {
    '1ph': Duration(minutes: 1),
    '5ph': Duration(minutes: 5),
    '30ph': Duration(minutes: 30),
    '1h': Duration(hours: 1),
    '4h': Duration(hours: 4),
    '12h': Duration(hours: 12),
    '24h': Duration(hours: 24),
  };

  int _selectedIndex = -1;
  late HubConnection hubConnection;
  double? _currentWeight;
  String _selectedTimeframe = '1h';
  bool _isInitialLoading = true;
  final TransformationController _chartTransformController =
      TransformationController();
  late final SiloApiService _siloApiService;
  StreamSubscription<List<SiloHistoryModel>>? _historySubscription;

  List<Silo> _silos = [];
  List<Controller> _controllers = [];
  List<Indicator> _indicators = [];
  List<ColData> _colData = [];
  List<SiloHistoryModel> _siloHistory = [];

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
    _siloApiService = SiloApiService(
      pollingInterval: const Duration(seconds: 5),
    );
    _initSignalR();
    _loadInitialData().whenComplete(() {
      _startSiloHistoryStream();
    });

    _pumpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchPumpPlan();
    });
  }

  @override
  void dispose() {
    _pumpTimer?.cancel();
    _historySubscription?.cancel();
    _siloApiService.dispose();
    _chartTransformController.dispose();
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
        final schedulersRaw = data is Map<String, dynamic>
            ? data['schedulers']
            : null;
        final List<dynamic> schedulers =
            schedulersRaw is List ? schedulersRaw : <dynamic>[];

        if (!mounted) return;
        setState(() {
          _pumpPlanRows = schedulers.map((item) {
            final map = item is Map<String, dynamic>
                ? item
                : <String, dynamic>{};

            return {
              'time': (map['timeStart'] ?? '').toString(),
              'silo': 'Silo ${(map['id_relay'] ?? '').toString()}',
              'material': (map['des'] ?? '').toString(),
              'qty': (map['weight'] ?? '').toString(),
              'status': _mapStatus(_parseStatus(map['status'])),
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

  int _parseStatus(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? -1;
    return -1;
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSilos(),
      _loadIndicators(),
      _loadControllers(),
      _loadColData(),
      _fetchPumpPlan(),
    ]);

    // Scale API là nguồn ngoài, chỉ dùng bổ sung nếu backend local chưa có dữ liệu silo.
    if (_silos.isEmpty) {
      await _loadScales();
    }

    if (!mounted) return;
    setState(() {
      _isInitialLoading = false;
    });
  }

  Future<void> _startSiloHistoryStream() async {
    if (!mounted) return;

    final historyId = _resolveHistoryId();

    await _historySubscription?.cancel();
    _historySubscription = _siloApiService
        .watchHistory(sync: -1, id: historyId)
        .listen((rows) {
      if (!mounted) return;
      setState(() {
        _siloHistory = rows;
      });
    }, onError: (error) {
      debugPrint('Error polling silo history: $error');
    });

    await _refreshSiloHistory();
  }

  Future<void> _refreshSiloHistory() async {
    try {
      final rows = await _siloApiService.fetchHistory(
        sync: -1,
        id: _resolveHistoryId(),
      );

      if (!mounted) return;
      setState(() {
        _siloHistory = rows;
      });
    } catch (e) {
      debugPrint('Error refreshing silo history: $e');
    }
  }

  int _resolveHistoryId() {
    if (_silos.isEmpty) return -1;

    final siloId = _silos.first.id;
    final direct = int.tryParse(siloId);
    if (direct != null) return direct;

    final extracted = RegExp(r'\d+').firstMatch(siloId)?.group(0);
    return int.tryParse(extracted ?? '') ?? -1;
  }

  Future<void> _initSignalR() async {
    try {
      hubConnection = HubConnectionBuilder()
          .withUrl('http://${AppConfig.serverIp}:${AppConfig.apiPort}/siloHub')
          .build();

      hubConnection.on('ReceiveScaleValue', (List<Object?>? args) {
        if (args == null || args.isEmpty || !mounted) return;

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
    } catch (e) {
      debugPrint('Error initializing SignalR: $e');
    }
  }

  Future<void> _loadScales() async {
    try {
      final data = await ScaleService.getListScales();
      final mapped = <Silo>[];

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;

        try {
          mapped.add(Silo.fromJson(item));
        } catch (_) {
          // Bỏ qua record không khớp schema để tránh crash toàn màn hình.
        }
      }

      if (mapped.isEmpty) return;

      if (!mounted) return;
      setState(() {
        // Chỉ dùng dữ liệu scale khi local silos rỗng để tránh ghi đè nguồn chính.
        if (_silos.isEmpty) {
          _silos = mapped;
        }
      });
    } catch (e) {
      debugPrint('Error loading scales: $e');
    }
  }

  Future<void> _loadSilos() async {
    try {
      final silos = await ApiService.fetchSilos();
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
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

  Widget _buildStatCard(
    String title,
    String value,
    Color color, {
    bool compact = false,
  }) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: compact ? 12 : 13,
              ),
            ),
            SizedBox(height: compact ? 3 : 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 16 : 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection({
    required double screenWidth,
    required double contentWidth,
  }) {
    final stats = <Map<String, dynamic>>[
      {'title': 'Tổng khối lượng', 'value': '1,245.32 tấn', 'color': Colors.blue},
      {'title': 'Silo hoạt động', 'value': '22/24', 'color': Colors.green},
      {'title': 'Silo mức thấp', 'value': '3 silo', 'color': Colors.orange},
      {'title': 'Cảnh báo', 'value': '5 cảnh báo', 'color': Colors.red},
      {'title': 'Lượng ăn hôm nay', 'value': '18.52 tấn', 'color': Colors.purple},
    ];

    // Mobile thật: ẩn hoàn toàn Stats.
    if (screenWidth < 600) {
      return const SizedBox.shrink();
    }

    final isTablet = screenWidth < 1100;
    final horizontalPadding = isTablet ? 6.0 : 10.0;
    final gap = 8.0;
    final rawCardWidth = isTablet
        ? 152.0
        : ((contentWidth - (horizontalPadding * 2) - (gap * (stats.length - 1))) /
                stats.length)
            .clamp(158.0, 210.0);
    final cardWidth = rawCardWidth.toDouble();

    final row = Row(
      children: List<Widget>.generate(stats.length, (index) {
        final item = stats[index];
        return Padding(
          padding: EdgeInsets.only(right: index == stats.length - 1 ? 0 : gap),
          child: SizedBox(
            width: cardWidth,
            child: _buildStatCard(
              item['title'] as String,
              item['value'] as String,
              item['color'] as Color,
              compact: isTablet,
            ),
          ),
        );
      }),
    );

    return SizedBox(
      height: isTablet ? 94 : 100,
      child: ScrollConfiguration(
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
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: row,
            ),
          ),
        ),
      ),
    );
  }

  List<_SiloVolumePoint> _buildSiloVolumePoints() {
    if (_siloHistory.isEmpty) return const <_SiloVolumePoint>[];

    final timeframeDuration = _timeframeDurations[_selectedTimeframe] ??
        const Duration(hours: 1);

    final rows = _siloApiService.filterByTimeframe(
      source: _siloHistory,
      timeframe: timeframeDuration,
    );

    final points = rows
        .map((row) => _SiloVolumePoint(
              time: row.recordTime,
              weight: row.weight,
            ))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    return points;
  }

  void _handleTimeframeSelected(String timeframe) {
    setState(() {
      _selectedTimeframe = timeframe;
      _chartTransformController.value = Matrix4.identity();
    });

    _refreshSiloHistory();
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
        SiloVolumeChart(
          title: _silos.isNotEmpty
              ? 'Biểu đồ khối lượng ${_silos.first.id}'
              : 'Biểu đồ khối lượng Silo',
          points: _buildSiloVolumePoints(),
          selectedTimeframe: _selectedTimeframe,
          timeframeOptions: _timeframeDurations.keys.toList(growable: false),
          onTimeframeSelected: _handleTimeframeSelected,
          transformationController: _chartTransformController,
        ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final showStats = screenWidth >= 600;
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
                if (showStats)
                  _buildStatsSection(
                    screenWidth: screenWidth,
                    contentWidth: maxWidth,
                  ),
                if (showStats) const SizedBox(height: 16),
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
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return _buildStatsSection(
                                  screenWidth: screenWidth,
                                  contentWidth: constraints.maxWidth,
                                );
                              },
                            ),
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

    if (_isInitialLoading) {
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

class _SiloVolumePoint {
  final DateTime time;
  final double weight;

  const _SiloVolumePoint({
    required this.time,
    required this.weight,
  });
}

class SiloVolumeChart extends StatelessWidget {
  final String title;
  final List<_SiloVolumePoint> points;
  final String selectedTimeframe;
  final List<String> timeframeOptions;
  final ValueChanged<String> onTimeframeSelected;
  final TransformationController transformationController;

  const SiloVolumeChart({
    super.key,
    required this.title,
    required this.points,
    required this.selectedTimeframe,
    required this.timeframeOptions,
    required this.onTimeframeSelected,
    required this.transformationController,
  });

  String _formatTime(DateTime dateTime, String timeframe) {
    if (timeframe == '1ph' || timeframe == '5ph' || timeframe == '30ph') {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final second = dateTime.second.toString().padLeft(2, '0');
      return '$hour:$minute:$second';
    }

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final chartPoints = points
        .map(
          (point) => FlSpot(
            point.time.millisecondsSinceEpoch.toDouble(),
            point.weight,
          ),
        )
        .toList();

    final hasData = chartPoints.isNotEmpty;
    final minXRaw = hasData ? chartPoints.first.x : 0.0;
    final maxXRaw = hasData ? chartPoints.last.x : 1.0;
    final minX = minXRaw;
    final maxX = (maxXRaw - minXRaw).abs() < 1
      ? minXRaw + const Duration(minutes: 1).inMilliseconds
      : maxXRaw;
    final minYRaw = hasData
        ? chartPoints.map((spot) => spot.y).reduce((a, b) => a < b ? a : b)
        : 0.0;
    final maxYRaw = hasData
        ? chartPoints.map((spot) => spot.y).reduce((a, b) => a > b ? a : b)
        : 100.0;
    final yPadding = (maxYRaw - minYRaw).abs() < 1 ? 5.0 : (maxYRaw - minYRaw) * 0.2;
    final minY = (minYRaw - yPadding).clamp(0.0, double.infinity);
    final maxY = maxYRaw + yPadding;
    final xInterval = hasData
      ? (((maxX - minX) / 4).clamp(1.0, double.infinity) as double)
      : 1.0;
    final yInterval = (((maxY - minY) / 5).clamp(1.0, double.infinity) as double);

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: timeframeOptions.map((option) {
                  final selected = option == selectedTimeframe;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option),
                      selected: selected,
                      onSelected: (_) => onTimeframeSelected(option),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasData
                    ? InteractiveViewer(
                        transformationController: transformationController,
                        minScale: 1.0,
                        maxScale: 6.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: LineChart(
                          LineChartData(
                            clipData: FlClipData.all(),
                            minX: minX,
                            maxX: maxX,
                            minY: minY,
                            maxY: maxY,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              horizontalInterval: yInterval,
                              verticalInterval: xInterval,
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Khối lượng Silo',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 58,
                                  getTitlesWidget: (value, meta) => SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      '${value.toStringAsFixed(0)} kg',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Thời gian',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: xInterval,
                                  reservedSize: 36,
                                  getTitlesWidget: (value, meta) {
                                    final dateTime = DateTime.fromMillisecondsSinceEpoch(
                                      value.toInt(),
                                    );

                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        _formatTime(dateTime, selectedTimeframe),
                                        style: const TextStyle(fontSize: 10),
                                      ),
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
                            borderData: FlBorderData(show: true),
                            lineTouchData: LineTouchData(
                              enabled: true,
                              handleBuiltInTouches: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final spotTime =
                                        DateTime.fromMillisecondsSinceEpoch(
                                      spot.x.toInt(),
                                    );

                                    return LineTooltipItem(
                                      '${spot.y.toStringAsFixed(2)} kg\n${_formatTime(spotTime, selectedTimeframe)}',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: chartPoints,
                                isCurved: true,
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade500, Colors.cyan.shade400],
                                ),
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.blue.withValues(alpha: 0.24),
                                      Colors.blue.withValues(alpha: 0.04),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Chưa có dữ liệu trong khung thời gian đã chọn',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
