import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_core/signalr_core.dart';

import 'config/app_config.dart';
import 'models/controller.dart';
import 'models/indicator.dart';
import 'models/silo.dart';
import 'models/silo_history_model.dart';
import 'services/scale_service.dart';
import 'services/excel_export_service.dart';
import 'services/silo_api_service.dart';
import 'services/statistics_report_helper.dart';
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
  static const int _settingsTabIndex = 7;
  static const double _defaultSiloMaxWeight = 100.0;
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
  String _selectedTimeframe = '24h';
  bool _isInitialLoading = true;
  final TransformationController _chartTransformController =
      TransformationController();
  final ScrollController _statsScrollController = ScrollController();
  final ScrollController _pumpPlanTableScrollController = ScrollController();
  final ScrollController _statisticsTableScrollController = ScrollController();
  late final SiloApiService _siloApiService;
  StreamSubscription<List<SiloHistoryModel>>? _historySubscription;

  List<Silo> _silos = [];
  List<Controller> _controllers = [];
  List<Indicator> _indicators = [];
  List<SiloHistoryModel> _siloHistory = [];
  int _lastProcessedId = -1;
  double _noiseThresholdKg = 5.0;
  final Map<int, double> _siloMaxConfig = <int, double>{};
  int? _selectedSettingsSiloId;
  String? _settingsMaxWeightError;
  final TextEditingController _settingsMaxWeightController =
      TextEditingController(text: '100');

  List<Map<String, String>> _pumpPlanRows = [];
  Timer? _pumpTimer;
  Timer? _autoReportExportTimer;
  DateTime? _lastReportExportAt;
  bool _isFetchingPumpPlan = false;

  @override
  void initState() {
    super.initState();
    _siloApiService = SiloApiService(
      pollingInterval: const Duration(seconds: 5),
    );
    _initSignalR();
    _initializeDashboard();

    _pumpTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchPumpPlan();
    });

    _autoReportExportTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _maybeAutoExportReport();
    });
  }

  @override
  void dispose() {
    _pumpTimer?.cancel();
    _autoReportExportTimer?.cancel();
    _historySubscription?.cancel();
    _siloApiService.dispose();
    _chartTransformController.dispose();
    _statsScrollController.dispose();
    _pumpPlanTableScrollController.dispose();
    _statisticsTableScrollController.dispose();
    _settingsMaxWeightController.dispose();
    hubConnection.stop();
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    await _loadInitialData();
    if (!mounted) return;
    await _startSiloHistoryStream();
    await _prefillSettingsForm();
  }

  Future<void> _fetchPumpPlan() async {
    if (_isFetchingPumpPlan) return;
    _isFetchingPumpPlan = true;

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/Schedulers/GetSchedulers'),
          )
          .timeout(const Duration(seconds: 12));

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
              'time': _formatPumpPlanTime(map['timeStart']),
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
    } finally {
      _isFetchingPumpPlan = false;
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

  Future<void> saveSiloConfig(int siloId, double maxWeight) async {
    if (siloId <= 0 || maxWeight < 0) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('silo_config_max_$siloId', maxWeight);

    if (!mounted) return;
    setState(() {
      _siloMaxConfig[siloId] = maxWeight;
    });
  }

  Future<double> loadSiloConfig(int siloId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('silo_config_max_$siloId') ?? _defaultSiloMaxWeight;
  }

  int _extractSiloId(String siloIdText, {int? fallback}) {
    final direct = int.tryParse(siloIdText.trim());
    if (direct != null && direct > 0) return direct;

    final extracted = RegExp(r'\d+').firstMatch(siloIdText)?.group(0);
    final parsed = int.tryParse(extracted ?? '');
    if (parsed != null && parsed > 0) return parsed;

    return fallback ?? 1;
  }

  Future<void> _loadAllSiloConfigs(List<Silo> silos) async {
    final Map<int, double> loaded = <int, double>{};
    final List<int> availableIds = <int>[];

    for (var i = 0; i < silos.length; i++) {
      final silo = silos[i];
      final siloId = _extractSiloId(silo.id, fallback: i + 1);
      if (!availableIds.contains(siloId)) {
        availableIds.add(siloId);
      }
      loaded[siloId] = await loadSiloConfig(siloId);
    }

    if (!mounted) return;
    setState(() {
      _siloMaxConfig
        ..clear()
        ..addAll(loaded);

      if (availableIds.isEmpty) {
        _selectedSettingsSiloId = null;
        _settingsMaxWeightController.text = '';
        _settingsMaxWeightError = null;
        return;
      }

      final selected = _selectedSettingsSiloId != null &&
              availableIds.contains(_selectedSettingsSiloId)
          ? _selectedSettingsSiloId!
          : availableIds.first;

      _selectedSettingsSiloId = selected;
      final maxWeight = loaded[selected] ?? _defaultSiloMaxWeight;
      _settingsMaxWeightController.text = maxWeight.toStringAsFixed(1);
      _settingsMaxWeightError = _validateMaxWeight(_settingsMaxWeightController.text);
    });
  }

  double _getSiloMaxWeight(int siloId) {
    return _siloMaxConfig[siloId] ?? _defaultSiloMaxWeight;
  }

  List<int> _getSettingsSiloIds() {
    final ids = <int>[];
    for (var i = 0; i < _silos.length; i++) {
      final id = _extractSiloId(_silos[i].id, fallback: i + 1);
      if (!ids.contains(id)) {
        ids.add(id);
      }
    }
    return ids;
  }

  String? _validateMaxWeight(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return 'Vui lòng nhập Cân Max';

    final parsed = double.tryParse(normalized);
    if (parsed == null) return 'Giá trị Cân Max không hợp lệ';
    if (parsed < 0) return 'Cân Max phải >= 0 kg';
    return null;
  }

  Future<void> _prefillSettingsForm() async {
    final ids = _getSettingsSiloIds();
    if (ids.isEmpty) {
      if (!mounted) return;
      setState(() {
        _selectedSettingsSiloId = null;
        _settingsMaxWeightController.text = '';
        _settingsMaxWeightError = null;
      });
      return;
    }

    final siloId = (_selectedSettingsSiloId != null && ids.contains(_selectedSettingsSiloId))
        ? _selectedSettingsSiloId!
        : ids.first;
    final maxWeight = await loadSiloConfig(siloId);
    if (!mounted) return;
    setState(() {
      _selectedSettingsSiloId = siloId;
      _settingsMaxWeightController.text = maxWeight.toStringAsFixed(1);
      _settingsMaxWeightError = _validateMaxWeight(_settingsMaxWeightController.text);
    });
  }

  String _formatPumpPlanTime(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '';

    try {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return raw;
      return DateFormat('HH:mm:ss - dd/MM/yyyy').format(parsed.toLocal());
    } catch (_) {
      return raw;
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSilos(),
      _loadIndicators(),
      _loadControllers(),
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

    await _historySubscription?.cancel();
    _historySubscription = _siloApiService
        .watchHistory(sync: -1, id: -1)
        .listen((rows) {
      if (!mounted) return;
      _applySiloHistoryUpdate(rows);
    }, onError: (error) {
      debugPrint('Error polling silo history: $error');
    });

    await _refreshSiloHistory();
  }

  Future<void> _refreshSiloHistory() async {
    try {
      final queryId = _lastProcessedId >= 0 ? _lastProcessedId : -1;
      final rows = await _siloApiService.fetchHistory(
        sync: -1,
        id: queryId,
      );

      if (!mounted) return;
      _applySiloHistoryUpdate(rows);
    } catch (e) {
      debugPrint('Error refreshing silo history: $e');
    }
  }

  void _applySiloHistoryUpdate(List<SiloHistoryModel> rows) {
    if (rows.isEmpty || !mounted) return;

    final sortedRows = [...rows]..sort((a, b) => a.id.compareTo(b.id));
    final latest = sortedRows.last;

    // Luôn seed lần đầu để biểu đồ có line hiển thị.
    if (_siloHistory.isEmpty || _lastProcessedId < 0) {
      setState(() {
        _siloHistory = sortedRows;
        _lastProcessedId = latest.id;
      });
      return;
    }

    final unchangedWeight = latest.weightNow == latest.weightPre;
    final duplicatedId = latest.id == _lastProcessedId;
    final notNewerThanLast = latest.id < _lastProcessedId;

    if (unchangedWeight || duplicatedId || notNewerThanLast) {
      return;
    }

    final newRows = sortedRows.where((row) => row.id > _lastProcessedId).toList();
    if (newRows.isEmpty) return;

    final merged = <SiloHistoryModel>[..._siloHistory, ...newRows]
      ..sort((a, b) => a.id.compareTo(b.id));

    // Chặn trùng ID khi endpoint trả dữ liệu chồng lặp theo lower-bound.
    final deduped = <SiloHistoryModel>[];
    var previousId = -1;
    for (final row in merged) {
      if (row.id == previousId) continue;
      deduped.add(row);
      previousId = row.id;
    }

    setState(() {
      _siloHistory = deduped;
      _lastProcessedId = latest.id;
    });
  }

  Future<void> _initSignalR() async {
    try {
      hubConnection = HubConnectionBuilder()
          .withUrl(AppConfig.signalRHubUrl)
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

      if (_silos.isNotEmpty) {
        await _loadAllSiloConfigs(_silos);
      }
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

      await _loadAllSiloConfigs(silos);
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

  List<SiloHistoryModel> filterSiloHistory(List<SiloHistoryModel> rawData) {
    if (rawData.isEmpty) return const <SiloHistoryModel>[];

    final sorted = [...rawData]..sort((a, b) => a.id.compareTo(b.id));

    // 1) Loại bỏ điểm đứng yên theo yêu cầu (weight_now == weight_pre).
    final movingOnly = sorted
        .where((item) => item.weightNow != item.weightPre)
        .toList();

    if (movingOnly.length <= 2) return movingOnly;

    int direction(double from, double to) {
      final delta = to - from;
      if (delta.abs() <= _noiseThresholdKg) return 0;
      if (delta > 0) return 1;
      if (delta < 0) return -1;
      return 0;
    }

    final optimized = <SiloHistoryModel>[movingOnly.first];
    var previous = movingOnly.first;
    var currentDirection = 0;

    for (var i = 1; i < movingOnly.length; i++) {
      final current = movingOnly[i];
      final nextDirection = direction(previous.weightNow, current.weightNow);

      if (nextDirection == 0) {
        // Bỏ qua dao động nhiễu nhỏ trong ngưỡng do người dùng chọn.
        previous = current;
        continue;
      }

      if (currentDirection == 0) {
        currentDirection = nextDirection;
      } else if (nextDirection != currentDirection) {
        // 2) Khi đổi hướng, giữ lại điểm kết thúc của xu hướng trước đó.
        if (optimized.last.id != previous.id) {
          optimized.add(previous);
        }
        currentDirection = nextDirection;
      }

      previous = current;
    }

    // Luôn giữ điểm kết thúc xu hướng cuối cùng.
    if (optimized.last.id != movingOnly.last.id) {
      optimized.add(movingOnly.last);
    }

    return optimized;
  }

  List<Map<String, String>> _buildReportExportRows() {
    final compressed = generateCompressedStatisticsReport(_siloHistory);
    final visibleRows = compressed.reversed.take(10).toList();

    final exportRows = <Map<String, String>>[];

    for (final item in visibleRows) {
      exportRows.add({
        'time': item.timeRangeText,
        'silo': item.milestone.idScale.toString(),
        'material': item.detailText,
        'qty': item.weightChangeText,
        'status': 'Thong ke',
      });
    }

    return exportRows;
  }

  String _buildReportFileName() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    return 'ThongKe_${day}_${month}_$year.xlsx';
  }

  Future<void> _exportStatisticsReport({required bool isAuto}) async {
    final rows = _buildReportExportRows();

    if (rows.isEmpty) return;

    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = (now.year % 100).toString().padLeft(2, '0');
    final filePrefix = 'ThongKe_$day-$month-$year';
    final downloadFileName = _buildReportFileName();

    final result = await exportPlanRowsToExcel(
      filePrefix: filePrefix,
      rows: rows,
      downloadFileName: downloadFileName,
    );

    if (result.success) {
      _lastReportExportAt = DateTime.now();
    }

    if (!mounted) return;
    if (!isAuto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _maybeAutoExportReport() async {
    final now = DateTime.now();
    final last = _lastReportExportAt;

    if (last == null || now.difference(last) >= const Duration(hours: 24)) {
      await _exportStatisticsReport(isAuto: true);
    }
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
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, {required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _statusColor(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
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
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
          controller: _statsScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _statsScrollController,
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

  List<SiloVolumePoint> _buildSiloVolumePoints() {
    if (_siloHistory.isEmpty) return const <SiloVolumePoint>[];

    final timeframeDuration = _timeframeDurations[_selectedTimeframe] ??
        const Duration(hours: 1);

    final rows = _siloApiService.filterByTimeframe(
      source: _siloHistory,
      timeframe: timeframeDuration,
    );

    // Nếu filter theo timeframe rỗng thì lấy tạm 20 điểm gần nhất để tránh chart trống.
    final sourceRows = rows.isNotEmpty
      ? rows
      : (_siloHistory.length > 20
        ? _siloHistory.sublist(_siloHistory.length - 20)
        : _siloHistory);

    final points = sourceRows
        .where((row) {
          final timestamp = row.time.millisecondsSinceEpoch;
          final weight = row.weightNow;

          // Chỉ giữ điểm có thời gian/khối lượng hợp lệ và khác 0.
          if (timestamp <= 0) return false;
          if (weight <= 0) return false;
          if (weight.isNaN || weight.isInfinite) return false;

          return true;
        })
        .map((row) => SiloVolumePoint(
              time: row.time,
              weight: row.weightNow.toDouble(),
            ))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    // Fallback lần cuối: nếu toàn bộ điểm bị loại thì thử lấy lại từ 20 điểm mới nhất không qua filter timeframe.
    if (points.isEmpty) {
      final latestRows = _siloHistory.length > 20
          ? _siloHistory.sublist(_siloHistory.length - 20)
          : _siloHistory;

      return latestRows
          .map((row) => SiloVolumePoint(
                time: row.time,
                weight: row.weightNow.toDouble(),
              ))
          .where((point) {
            final timestamp = point.time.millisecondsSinceEpoch;
            final weight = point.weight;
            if (timestamp <= 0) return false;
            if (weight <= 0) return false;
            if (weight.isNaN || weight.isInfinite) return false;
            return true;
          })
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
    }

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

    final chartPoints = _buildSiloVolumePoints();

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
            final siloId = _extractSiloId(silo.id, fallback: idx + 1);

            final indicatorsForSilo = _indicators.isNotEmpty
                ? <Indicator>[_indicators[idx % _indicators.length]]
                : <Indicator>[];

            final controllersForSilo = _controllers.isNotEmpty
                ? <Controller>[_controllers[idx % _controllers.length]]
                : <Controller>[];

            return SiloModule(
              id: silo.id,
              currentWeight: _currentWeight,
              maxWeight: _getSiloMaxWeight(siloId),
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
          points: chartPoints,
          rawCount: _siloHistory.length,
          selectedTimeframe: _selectedTimeframe,
          timeframeOptions: _timeframeDurations.keys.toList(growable: false),
          onTimeframeSelected: _handleTimeframeSelected,
          transformationController: _chartTransformController,
        ),
      ],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final result = await exportPlanRowsToExcel(
                                filePrefix: exportFilePrefix,
                                rows: rows,
                              );

                              if (!mounted) return;

                              messenger.showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                            },
                            icon: const Icon(Icons.table_view),
                            label: const Text('Xuất excel'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
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
                              if (!mounted) return;

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
                                messenger.showSnackBar(
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

                              messenger.showSnackBar(
                                SnackBar(content: Text(addSnackBarText)),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm kế hoạch'),
                          ),
                          _buildInfoBadge('Hiển thị: ${rows.length}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngưỡng nhiễu: ${_noiseThresholdKg.toStringAsFixed(0)} kg',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          Slider(
                            value: _noiseThresholdKg,
                            min: 1,
                            max: 100,
                            divisions: 99,
                            label: '${_noiseThresholdKg.toStringAsFixed(0)} kg',
                            onChanged: (value) {
                              setState(() {
                                _noiseThresholdKg = value;
                              });
                            },
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Text(
                            'Ngưỡng nhiễu: ${_noiseThresholdKg.toStringAsFixed(0)} kg',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Slider(
                              value: _noiseThresholdKg,
                              min: 1,
                              max: 100,
                              divisions: 99,
                              label: '${_noiseThresholdKg.toStringAsFixed(0)} kg',
                              onChanged: (value) {
                                setState(() {
                                  _noiseThresholdKg = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
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
                  controller: _pumpPlanTableScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _pumpPlanTableScrollController,
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
                          const DataColumn(label: Text('Thời gian')),
                          if (!isMobile) const DataColumn(label: Text('Silo')),
                          if (!isMobile) const DataColumn(label: Text('Nguyên liệu')),
                          const DataColumn(label: Text('Số lượng'), numeric: true),
                          const DataColumn(label: Text('Trạng thái')),
                          const DataColumn(label: Text('Xóa')),
                        ],
                        rows: List<DataRow>.generate(rows.length, (index) {
                          final row = rows[index];
                          final status = row['status'] ?? '';

                          return DataRow(
                            cells: [
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
                                    width: 90,
                                    child: Text(
                                      row['silo'] ?? '',
                                      maxLines: 1,
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
                              DataCell(_buildStatusBadge(status, isMobile: isMobile)),
                              DataCell(
                                SizedBox(
                                  width: 56,
                                  child: IconButton(
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

  Widget _buildPumpPlanCard() {
    return _buildPlanCard(
      title: 'Danh sách kế hoạch',
      rows: _pumpPlanRows,
      addSnackBarText: 'Đã thêm kế hoạch',
      deleteSnackBarText: 'Đã xóa kế hoạch',
      exportFilePrefix: 'ke_hoach_bom',
    );
  }

  Widget _buildStatisticsReportCard() {
    final rows = generateCompressedStatisticsReport(_siloHistory)
        .reversed
        .take(20)
        .toList();

    Color changeColor(String change) {
      if (change.startsWith('+')) return Colors.green;
      if (change.startsWith('-')) return Colors.red;
      return Colors.black87;
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Báo cáo thống kê',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _exportStatisticsReport(isAuto: false);
                      },
                      icon: const Icon(Icons.table_view),
                      label: const Text('Xuất excel'),
                    ),
                    const SizedBox(width: 8),
                    _buildInfoBadge('Hiển thị: ${rows.length}'),
                  ],
                ),
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
                  controller: _statisticsTableScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _statisticsTableScrollController,
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
                                          color: changeColor(item.weightChangeText),
                                          fontWeight: FontWeight.w700,
                                        ),
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
        _buildStatisticsReportCard(),
      ],
    );
  }

  Widget _buildSettingsConfigurationCard() {
    final displaySiloCount = _silos.length;
    final siloIds = _getSettingsSiloIds();
    final selectedSiloId = _selectedSettingsSiloId;
    final selectedValue =
        (selectedSiloId != null && siloIds.contains(selectedSiloId))
        ? selectedSiloId
        : null;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cài đặt Cân Max',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                _buildInfoBadge('Silo hiện có: $displaySiloCount'),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: selectedValue,
              items: siloIds
                  .map(
                    (id) => DropdownMenuItem<int>(
                      value: id,
                      child: Text('Silo $id'),
                    ),
                  )
                  .toList(),
              onChanged: siloIds.isEmpty
                  ? null
                  : (value) async {
                      if (value == null) return;

                      setState(() {
                        _selectedSettingsSiloId = value;
                      });

                      final loadedMax = await loadSiloConfig(value);
                      if (!mounted) return;

                      setState(() {
                        _settingsMaxWeightController.text = loadedMax.toStringAsFixed(1);
                        _settingsMaxWeightError = _validateMaxWeight(
                          _settingsMaxWeightController.text,
                        );
                      });
                    },
              decoration: const InputDecoration(
                labelText: 'Silo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _settingsMaxWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cân Max (kg)',
                border: OutlineInputBorder(),
                errorText: _settingsMaxWeightError,
              ),
              onChanged: (value) async {
                final validationError = _validateMaxWeight(value);
                if (mounted) {
                  setState(() {
                    _settingsMaxWeightError = validationError;
                  });
                }

                final siloId = _selectedSettingsSiloId;
                final maxWeight = double.tryParse(value.trim().replaceAll(',', '.'));
                if (validationError != null || siloId == null || maxWeight == null) return;

                await saveSiloConfig(siloId, maxWeight);
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final siloId = _selectedSettingsSiloId;
                  final maxWeight = double.tryParse(
                    _settingsMaxWeightController.text.trim().replaceAll(',', '.'),
                  );
                  final validationError = _validateMaxWeight(
                    _settingsMaxWeightController.text,
                  );

                  if (mounted) {
                    setState(() {
                      _settingsMaxWeightError = validationError;
                    });
                  }

                  if (siloId == null || maxWeight == null || validationError != null) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập đúng Silo và Cân Max')),
                    );
                    return;
                  }

                  await saveSiloConfig(siloId, maxWeight);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Đã lưu cấu hình Silo $siloId: ${maxWeight.toStringAsFixed(1)} kg')),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('Lưu cấu hình'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Cấu hình được lưu bằng SharedPreferences và tự động áp dụng khi re-build/responsive.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDashboard(double maxWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    final showStats = screenWidth >= 600;
    final showSettings = _selectedIndex == _settingsTabIndex;
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
                if (showStats && !showSettings)
                  _buildStatsSection(
                    screenWidth: screenWidth,
                    contentWidth: maxWidth,
                  ),
                if (showStats && !showSettings) const SizedBox(height: 16),
                if (showSettings)
                  _buildSettingsConfigurationCard()
                else ...[
                  _buildModulesAndChartSection(maxWidth),
                  const SizedBox(height: 16),
                  _buildPlanAndWarningSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDashboard(double sidebarWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    final showSettings = _selectedIndex == _settingsTabIndex;
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
                          if (!showSettings)
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
                            child: showSettings
                                ? SingleChildScrollView(
                                    child: _buildSettingsConfigurationCard(),
                                  )
                                : Row(
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

class SiloVolumePoint {
  final DateTime time;
  final double weight;

  const SiloVolumePoint({
    required this.time,
    required this.weight,
  });
}

class SiloVolumeChart extends StatelessWidget {
  final String title;
  final List<SiloVolumePoint> points;
  final int rawCount;
  final String selectedTimeframe;
  final List<String> timeframeOptions;
  final ValueChanged<String> onTimeframeSelected;
  final TransformationController transformationController;

  const SiloVolumeChart({
    super.key,
    required this.title,
    required this.points,
    required this.rawCount,
    required this.selectedTimeframe,
    required this.timeframeOptions,
    required this.onTimeframeSelected,
    required this.transformationController,
  });

  String _formatTimeHms(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _formatWeightAxis(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final chartPoints = <FlSpot>[];
    for (final point in points) {
      final x = point.time.millisecondsSinceEpoch.toDouble();
      final y = point.weight.toDouble();

      if (x <= 0 || x.isNaN || x.isInfinite) continue;
      if (y <= 0 || y.isNaN || y.isInfinite) continue;

      chartPoints.add(FlSpot(x, y));
    }

    final hasData = chartPoints.isNotEmpty;
    final validCount = chartPoints.length;
    final minXRaw = hasData ? chartPoints.first.x : 0.0;
    final maxXRaw = hasData ? chartPoints.last.x : 1.0;
    final minX = minXRaw;
    final maxX = (maxXRaw - minXRaw).abs() < 1
      ? minXRaw + const Duration(minutes: 1).inMilliseconds
      : maxXRaw;
    final minWeight = hasData
      ? chartPoints.map((spot) => spot.y).reduce((a, b) => a < b ? a : b)
      : 0.0;
    final maxWeight = hasData
      ? chartPoints.map((spot) => spot.y).reduce((a, b) => a > b ? a : b)
      : 50000.0;
    final minY = hasData ? minWeight * 0.9 : 0.0;
    final maxY = hasData ? maxWeight * 1.1 : 50000.0;
    final xInterval = hasData
      ? ((maxX - minX) / 4).clamp(1.0, double.infinity)
      : 1.0;
    final yInterval = ((maxY - minY) / 5).clamp(1.0, double.infinity);

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'debug $rawCount/$validCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
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
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: hasData
                      ? InteractiveViewer(
                          transformationController: transformationController,
                          minScale: 1.0,
                          maxScale: 6.0,
                          panEnabled: true,
                          scaleEnabled: true,
                          clipBehavior: Clip.hardEdge,
                          child: LineChart(
                            LineChartData(
                              clipData: FlClipData.all(),
                              baselineY: minY,
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
                                        _formatWeightAxis(value),
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
                                          _formatTimeHms(dateTime),
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
                                        '${spot.y.toStringAsFixed(2)} kg\n${_formatTimeHms(spotTime)}',
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
                                  preventCurveOverShooting: true,
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
                            duration: Duration.zero,
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
            ),
          ],
        ),
      ),
    );
  }
}
