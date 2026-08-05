import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_core/signalr_core.dart' as signalr_core;



import 'utils/app_config.dart';
import 'models/controller.dart';
import 'models/indicator.dart';
import 'models/silo.dart';
import 'models/silo_history_model.dart';
import 'services/scale_service.dart';
import 'services/excel_export_service.dart';
import 'services/silo_api_service.dart' hide baseUrl;
import 'services/statistics_report_helper.dart';
import 'services/sql_service.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'widgets/silo_plan_table.dart';
import 'widgets/silo_report_table.dart';
import 'widgets/silo_mass_chart.dart';
import 'widgets/silo_visualizer.dart';
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
      home: FutureBuilder<bool>(
        future: AuthService().hasToken(),
        builder: (context, snapshot) {
          final hasToken = snapshot.data ?? false;
if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return hasToken ? const DashboardPage() : const LoginScreen();
        },
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const int _totalSiloCount = 8;
  static const int _siloMonitorTabIndex = 1;
  static const int _pumpPlanTabIndex = 2;
  static const int _historyTabIndex = 3;
  static const int _warningTabIndex = 4;
  static const int _reportTabIndex = 5;
  static const int _settingsTabIndex = 6;
  static const int _userManagementTabIndex = 7;

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
  bool _isAdmin = true;
  String _currentUserId = '';
  String _currentUserName = 'Admin';
  String _currentUserRole = 'User';
  String _currentUserAvatarUrl = '';
late signalr_core.HubConnection hubConnection;
  // (kept as signalr_core.HubConnection)
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
  final Map<int, double> _siloNoiseThresholdConfig = <int, double>{};
  final Map<int, double> _siloMaxConfig = <int, double>{};
  int? _selectedSettingsSiloId;
  int? _selectedMonitorSiloId;
  int? _selectedStatisticsSiloId;
  String? _settingsMaxWeightError;
  double _settingsNoiseThresholdKg = 5.0;
  final TextEditingController _settingsMaxWeightController =
      TextEditingController(text: '100');

  List<Map<String, dynamic>> _userAccounts = [];
  bool _isLoadingUserAccounts = false;
  String? _userAccountsError;
  Timer? _autoReportExportTimer;
  Timer? _currentUserSyncTimer;
  DateTime? _lastReportExportAt;
  DateTime? _lastRealtimeWeightUpdatedAt;

  @override
  void initState() {
    super.initState();
    _siloApiService = SiloApiService(
      pollingInterval: const Duration(seconds: 5),
    );
    _startCurrentUserSync();
    _initSignalR();
    _initializeDashboard();

    _autoReportExportTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _maybeAutoExportReport();
    });
  }

  @override
  void dispose() {
    _autoReportExportTimer?.cancel();
    _currentUserSyncTimer?.cancel();
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

  Future<void> _syncCurrentUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('user_role') ?? 'admin').trim().toLowerCase();
    final userId = (prefs.getString('user_id') ?? '').trim();
    final username = (prefs.getString('user_name') ?? '').trim();
    final avatarUrl = (prefs.getString('user_avatar_url') ?? '').trim();

    final nextIsAdmin = role == 'admin';
    final nextUserName = username.isNotEmpty
        ? username
        : (nextIsAdmin ? 'Admin' : 'Tài khoản của tôi');
    final nextUserRole = role.isNotEmpty ? role : 'User';

    if (!mounted) return;

    if (_isAdmin == nextIsAdmin &&
        _currentUserId == userId &&
        _currentUserName == nextUserName &&
        _currentUserRole == nextUserRole &&
        _currentUserAvatarUrl == avatarUrl) {
      return;
    }

    setState(() {
      _isAdmin = nextIsAdmin;
      _currentUserId = userId;
      _currentUserName = nextUserName;
      _currentUserRole = nextUserRole;
      _currentUserAvatarUrl = avatarUrl;
    });
  }

  Map<String, dynamic> _normalizeUserAccount(Map<String, dynamic> raw) {
    final id = (raw['id'] ?? raw['userId'] ?? raw['uid'] ?? '').toString().trim();
    final username = (raw['username'] ??
            raw['userName'] ??
            raw['name'] ??
            raw['loginName'] ??
            '')
        .toString()
        .trim();
    final role = (raw['role'] ?? raw['userRole'] ?? 'sub').toString().trim();

    return {
      'id': id,
      'username': username,
      'role': role,
    };
  }

  Future<void> _loadUserAccounts() async {
    if (!_isAdmin) {
      if (!mounted) return;
      setState(() {
        _userAccounts = const <Map<String, dynamic>>[];
        _isLoadingUserAccounts = false;
        _userAccountsError = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingUserAccounts = true;
      _userAccountsError = null;
    });

    try {
      final token = await AuthService().getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/users'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Load users failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final rawUsers = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
              ? (decoded['users'] ?? decoded['data'] ?? decoded['items'])
              : null;

      if (rawUsers is! List) {
        throw Exception('Invalid users payload');
      }

      final users = rawUsers
          .whereType<Map>()
          .map((e) => _normalizeUserAccount(e.cast<String, dynamic>()))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _userAccounts = users;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userAccountsError = 'Không tải được danh sách tài khoản: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUserAccounts = false;
        });
      }
    }
  }

  Future<void> _createUserAccount({
    required String username,
    required String password,
  }) async {
    final token = await AuthService().getToken();
    await http.post(
      Uri.parse('$baseUrl/api/v1/users'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 12));

    await _loadUserAccounts();
  }

  Future<void> _updateUserAccount({
    required String userId,
    required String username,
    required String password,
  }) async {
    final body = <String, dynamic>{'username': username};
    if (password.trim().isNotEmpty) {
      body['password'] = password;
    }

    await http.put(
      Uri.parse('$baseUrl/api/v1/users/$userId'),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 12));

    await _loadUserAccounts();
  }

  Future<void> _changeMyPassword(String newPassword) async {
    await http.post(
      Uri.parse('$baseUrl/api/v1/users/me/password'),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'password': newPassword}),
    ).timeout(const Duration(seconds: 12));
  }

  Future<void> _showCreateUserDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tạo tài khoản mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Mật khẩu'),
                  obscureText: true,
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
                  'username': usernameController.text.trim(),
                  'password': passwordController.text,
                });
              },
              child: const Text('Tạo'),
            ),
          ],
        );
      },
    );

    usernameController.dispose();
    passwordController.dispose();

    if (result == null) return;

    final username = (result['username'] ?? '').trim();
    final password = result['password'] ?? '';
    if (username.isEmpty || password.isEmpty) return;

    try {
      await _createUserAccount(username: username, password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo tài khoản mới')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tạo tài khoản thất bại: $e')),
      );
    }
  }

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final userId = (user['id'] ?? '').toString();
    if (userId.isEmpty) return;

    final usernameController = TextEditingController(
      text: (user['username'] ?? '').toString(),
    );
    final passwordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sửa đổi thông tin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới (để trống nếu không đổi)',
                  ),
                  obscureText: true,
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
                  'username': usernameController.text.trim(),
                  'password': passwordController.text,
                });
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    usernameController.dispose();
    passwordController.dispose();

    if (result == null) return;

    final username = (result['username'] ?? '').trim();
    final password = result['password'] ?? '';
    if (username.isEmpty) return;

    try {
      await _updateUserAccount(
        userId: userId,
        username: username,
        password: password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật tài khoản')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật thất bại: $e')),
      );
    }
  }

  Future<void> _showChangeMyPasswordDialog() async {
    final passwordController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(passwordController.text),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    passwordController.dispose();

    final newPassword = (result ?? '').trim();
    if (newPassword.isEmpty) return;

    try {
      await _changeMyPassword(newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật mật khẩu')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đổi mật khẩu thất bại: $e')),
      );
    }
  }

  void _startCurrentUserSync() {
    _syncCurrentUserFromPrefs();
    _currentUserSyncTimer?.cancel();
    _currentUserSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _syncCurrentUserFromPrefs();
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  List<int> _buildSystemSiloIds() {
    return List<int>.generate(_totalSiloCount, (index) => index + 1);
  }

  int? _normalizeSelectedSiloId(int? siloId) {
    if (siloId == null || siloId <= 0) {
      return null;
    }
    return siloId;
  }

  Future<void> _fetchStatisticsReport({int? siloId}) async {
    try {
      final normalizedSiloId = _normalizeSelectedSiloId(siloId);
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AppConfig.baseUrl}/Scales/GetHistory').replace(
        queryParameters: <String, String>{
          'sync': '-1',
          'Id': '-1',
          if (normalizedSiloId != null) 'siloId': '$normalizedSiloId',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Không tải được dữ liệu báo cáo: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final rows = SiloHistoryModel.parseListFromResponse(decoded, defaultId: -1)
        ..sort((a, b) => a.id.compareTo(b.id));

      if (!mounted) return;
      setState(() {
        _siloHistory = rows;
        if (rows.isNotEmpty) {
          _lastProcessedId = rows.last.id;
        }
      });
    } catch (e) {
      debugPrint('Error fetching statistics report: $e');
      _showErrorSnackBar('Không tải được dữ liệu báo cáo: $e');
    }
  }

  Future<void> _handleStatisticsSiloChanged(int? siloId) async {
    final normalizedSiloId = _normalizeSelectedSiloId(siloId);

    if (!mounted) return;
    setState(() {
      _selectedStatisticsSiloId = normalizedSiloId;
    });

    await _fetchStatisticsReport(siloId: normalizedSiloId);
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

  Future<void> saveSiloNoiseConfig(int siloId, double noiseThresholdKg) async {
    if (siloId <= 0 || noiseThresholdKg < 0) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('silo_noise_threshold_$siloId', noiseThresholdKg);

    if (!mounted) return;
    setState(() {
      _siloNoiseThresholdConfig[siloId] = noiseThresholdKg;
      if (_getActiveSiloId() == siloId) {
        _noiseThresholdKg = noiseThresholdKg;
      }
    });
  }

  Future<double> loadSiloNoiseConfig(int siloId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('silo_noise_threshold_$siloId') ?? 5.0;
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
    final Map<int, double> loadedNoise = <int, double>{};
    final List<int> availableIds = <int>[];

    for (var i = 0; i < silos.length; i++) {
      final silo = silos[i];
      final siloId = _extractSiloId(silo.id, fallback: i + 1);
      if (!availableIds.contains(siloId)) {
        availableIds.add(siloId);
      }
      loaded[siloId] = await loadSiloConfig(siloId);
      loadedNoise[siloId] = await loadSiloNoiseConfig(siloId);
    }

    if (!mounted) return;
    setState(() {
      _siloMaxConfig
        ..clear()
        ..addAll(loaded);
      _siloNoiseThresholdConfig
        ..clear()
        ..addAll(loadedNoise);

      if (availableIds.isEmpty) {
        _selectedSettingsSiloId = null;
        _settingsMaxWeightController.text = '';
        _settingsMaxWeightError = null;
        _settingsNoiseThresholdKg = 5.0;
        _noiseThresholdKg = 5.0;
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
      _settingsNoiseThresholdKg = loadedNoise[selected] ?? 5.0;
      _noiseThresholdKg = loadedNoise[_getActiveSiloId()] ?? 5.0;
    });
  }

  double _getSiloMaxWeight(int siloId) {
    return _siloMaxConfig[siloId] ?? _defaultSiloMaxWeight;
  }

  int _getActiveSiloId() {
    final ids = _getSettingsSiloIds();
    if (ids.isEmpty) return 1;
    return ids.first;
  }

  List<int> _getSettingsSiloIds() {
    final ids = <int>[];
    for (var id = 1; id <= _totalSiloCount; id++) {
      ids.add(id);
    }
    return ids;
  }

  int? _getEffectiveMonitorSiloId() {
    final ids = _getSettingsSiloIds();
    if (ids.isEmpty) return null;

    final selected = _selectedMonitorSiloId;
    if (selected != null && ids.contains(selected)) {
      return selected;
    }

    return ids.first;
  }

  String _getMonitorSiloName(int siloId) {
    for (final silo in _silos) {
      final id = _extractSiloId(silo.id, fallback: -1);
      if (id == siloId) {
        return silo.id;
      }
    }
    return 'Silo $siloId';
  }

  Silo? _findSiloById(int siloId) {
    for (var i = 0; i < _silos.length; i++) {
      final silo = _silos[i];
      final id = _extractSiloId(silo.id, fallback: i + 1);
      if (id == siloId) return silo;
    }
    return null;
  }

  double _getSiloNoiseThreshold(int siloId) {
    final configured = _siloNoiseThresholdConfig[siloId];
    if (configured != null) return configured;

    if (_selectedSettingsSiloId == siloId) {
      return _settingsNoiseThresholdKg;
    }

    return 5.0;
  }

  double _getRawLiveWeightForSilo(int siloId) {
    // Ưu tiên nguồn realtime đang được tab Tổng quan dùng cho silo active.
    if (siloId == _getActiveSiloId() && _currentWeight != null) {
      return _currentWeight!;
    }

    for (var i = _siloHistory.length - 1; i >= 0; i--) {
      final row = _siloHistory[i];
      if (row.idScale == siloId) {
        return row.weightNow;
      }
    }

    final silo = _findSiloById(siloId);
    if (silo != null) {
      return silo.weight;
    }

    return 0.0;
  }

  double _normalizeWeightForDisplay({
    required int siloId,
    required double rawWeight,
  }) {
    var value = rawWeight;

    // Đồng bộ xử lý ngưỡng nhiễu giữa các tab.
    final noiseThreshold = _getSiloNoiseThreshold(siloId);
    if (value.abs() < noiseThreshold) {
      value = 0.0;
    }

    // Đồng bộ tỷ lệ theo cấu hình Cân Max.
    final maxWeight = _getSiloMaxWeight(siloId);
    return value.clamp(0.0, maxWeight);
  }

  double _getDisplayWeightForSilo(int siloId) {
    final raw = _getRawLiveWeightForSilo(siloId);
    return _normalizeWeightForDisplay(siloId: siloId, rawWeight: raw);
  }

  DateTime? _getLatestTimestampForSilo(int siloId) {
    DateTime? historyTimestamp;
    for (var i = _siloHistory.length - 1; i >= 0; i--) {
      final row = _siloHistory[i];
      if (row.idScale == siloId) {
        historyTimestamp = row.time;
        break;
      }
    }

    if (siloId == _getActiveSiloId()) {
      return _lastRealtimeWeightUpdatedAt ?? historyTimestamp;
    }

    return historyTimestamp;
  }

  DateTime? _extractRealtimeTimestamp(dynamic payload) {
    DateTime? parseFrom(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) {
        final isMillis = raw.abs() > 9999999999;
        final millis = isMillis ? raw : raw * 1000;
        return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      }
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed.toLocal();
        final asInt = int.tryParse(raw);
        if (asInt != null) {
          final isMillis = asInt.abs() > 9999999999;
          final millis = isMillis ? asInt : asInt * 1000;
          return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
        }
      }
      return null;
    }

    if (payload is Map<String, dynamic>) {
      return parseFrom(
        payload['dateTime'] ??
            payload['time'] ??
            payload['timestamp'] ??
            payload['Time'] ??
            payload['DateTime'],
      );
    }

    return null;
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
        _settingsNoiseThresholdKg = 5.0;
      });
      return;
    }

    final siloId = (_selectedSettingsSiloId != null && ids.contains(_selectedSettingsSiloId))
        ? _selectedSettingsSiloId!
        : ids.first;
    final maxWeight = await loadSiloConfig(siloId);
    final noiseThreshold = await loadSiloNoiseConfig(siloId);
    if (!mounted) return;
    setState(() {
      _selectedSettingsSiloId = siloId;
      _settingsMaxWeightController.text = maxWeight.toStringAsFixed(1);
      _settingsMaxWeightError = _validateMaxWeight(_settingsMaxWeightController.text);
      _settingsNoiseThresholdKg = noiseThreshold;
      _noiseThresholdKg = _siloNoiseThresholdConfig[_getActiveSiloId()] ?? 5.0;
    });
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSilos(),
      _loadIndicators(),
      _loadControllers(),
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
hubConnection = signalr_core.HubConnectionBuilder()
          .withUrl(AppConfig.signalRHubUrl)
          .build();

      hubConnection.on('ReceiveScaleValue', (List<Object?>? args) {
        if (args == null || args.isEmpty || !mounted) return;

        final raw = args[0];

        if (raw is Map<String, dynamic>) {
          final timestamp = _extractRealtimeTimestamp(raw) ?? DateTime.now();
          setState(() {
            _currentWeight = (raw['value'] as num).toDouble();
            _lastRealtimeWeightUpdatedAt = timestamp;
          });
        } else if (raw is String) {
          final data = jsonDecode(raw);
          final timestamp = _extractRealtimeTimestamp(data) ?? DateTime.now();
          setState(() {
            _currentWeight = (data['value'] as num).toDouble();
            _lastRealtimeWeightUpdatedAt = timestamp;
          });
        } else if (raw is num) {
          setState(() {
            _currentWeight = raw.toDouble();
            _lastRealtimeWeightUpdatedAt = DateTime.now();
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

  List<int> _getStatisticsSiloIds() {
    return _buildSystemSiloIds();
  }

  int? _getEffectiveStatisticsSiloId() {
    final selected = _selectedStatisticsSiloId;
    if (selected == null) return null;

    final ids = _getStatisticsSiloIds();
    if (ids.contains(selected)) {
      return selected;
    }
    return null;
  }

  List<SiloHistoryModel> _buildStatisticsHistorySource() {
    final selectedSiloId = _getEffectiveStatisticsSiloId();
    if (selectedSiloId == null) {
      return _siloHistory;
    }

    return _siloHistory.where((row) => row.idScale == selectedSiloId).toList();
  }

  String _buildReportFileName() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    return 'ThongKe_${day}_${month}_$year.xlsx';
  }

  Future<void> _exportStatisticsReport({
    List<CompressedStatisticsReportItem>? customRows,
    required bool isAuto,
  }) async {
    final rows = customRows ??
        generateCompressedStatisticsReport(_buildStatisticsHistorySource())
            .reversed
            .toList();

    if (rows.isEmpty) return;

    final selectedSiloId = _getEffectiveStatisticsSiloId();
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = (now.year % 100).toString().padLeft(2, '0');
    final filePrefix = 'ThongKe_$day-$month-$year';
    final downloadFileName = _buildReportFileName();

    final result = await exportStatisticsReportToExcel(
      filePrefix: filePrefix,
      rows: rows,
      selectedSiloId: selectedSiloId,
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

  void _select(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == _userManagementTabIndex) {
      _loadUserAccounts();
    }
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
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade900,
        ),
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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? const Color(0xFF2563EB) : Colors.transparent,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFFCBD5E1),
                ),
              ),
            ),
            if (selected)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _sidebarMenuConfig {
    final items = <Map<String, dynamic>>[
      {'icon': Icons.grid_view_rounded, 'label': 'Tổng quan'},
      // Tab giám sát silo luôn mở cho cả Admin và User.
      {'icon': Icons.sensors_rounded, 'label': 'Giám sát silo'},
      {'icon': Icons.monitor_weight_outlined, 'label': 'Trạng thái Silo'},
      {'icon': Icons.history_toggle_off_rounded, 'label': 'Lịch sử'},
      {'icon': Icons.warning_amber_rounded, 'label': 'Cảnh báo'},
      {'icon': Icons.description_outlined, 'label': 'Báo cáo'},
      {'icon': Icons.settings_outlined, 'label': 'Cài đặt'},
    ];

    // Chỉ giữ phân quyền admin cho menu quản lý người dùng.
    if (_isAdmin) {
      items.add({'icon': Icons.people_alt_outlined, 'label': 'Quản lý người dùng'});
    }

    return items;
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
            final label = item['label'] as String;
            final isSettingsItem = label == 'Cài đặt';

            if (!_isAdmin && isSettingsItem) {
              // Tài khoản con: bấm Cài đặt thì giữ im lặng, không làm gì.
              return;
            }

            _select(i);
            if (closeDrawerAfterTap) {
              Navigator.of(context).maybePop();
            }
          },
        ),
      );

      if (i < _sidebarMenuConfig.length - 1) {
        widgets.add(const SizedBox(height: 6));
      }
    }

    return widgets;
  }

  Widget _buildSidebar(double sidebarWidth) {
    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1B3D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    ),
                  ),
                  child: const Icon(Icons.insights, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'FeedFarm',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Silo Dashboard',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
    Color color,
    IconData icon, {
    bool compact = false,
    bool isWarning = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isWarning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isWarning
                ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 28 : 34,
                height: compact ? 28 : 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: compact ? 16 : 19),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 11.5 : 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              if (isWarning)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEF4444),
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: compact ? 17 : 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection({
    required double screenWidth,
    required double contentWidth,
  }) {
    _syncSilosWithLiveState();

    final totalWeightKg = _silos.fold<double>(0.0, (sum, s) => sum + s.weight);
    final totalMassTons = totalWeightKg / 1000.0;
    final activeSilosCount = _silos.where((s) => s.weight > 0).length;
    final lowLevelCount = _silos.where((s) {
      final pct = s.level * 100;
      return pct >= 20.0 && pct <= 50.0;
    }).length;
    final warningCount = _silos.where((s) {
      final pct = s.level * 100;
      return pct < 20.0;
    }).length;
    const double consumedTodayTons = 0.0;

    final stats = <Map<String, dynamic>>[
      {
        'title': 'Tổng khối lượng',
        'value': '${totalMassTons.toStringAsFixed(2)} tấn',
        'color': const Color(0xFF2563EB),
        'icon': Icons.scale_outlined,
      },
      {
        'title': 'Silo hoạt động',
        'value': '$activeSilosCount/8',
        'color': const Color(0xFF10B981),
        'icon': Icons.sensors_rounded,
      },
      {
        'title': 'Silo mức thấp',
        'value': '$lowLevelCount silo',
        'color': const Color(0xFFF59E0B),
        'icon': Icons.water_drop_outlined,
      },
      {
        'title': 'Cảnh báo',
        'value': '$warningCount cảnh báo',
        'color': const Color(0xFFEF4444),
        'icon': Icons.notifications_active_outlined,
        'isWarning': true,
      },
      {
        'title': 'Lượng ăn hôm nay',
        'value': '${consumedTodayTons.toStringAsFixed(2)} tấn',
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.analytics_outlined,
      },
    ];

    // Mobile thật: ẩn hoàn toàn Stats.
    if (screenWidth < 600) {
      return const SizedBox.shrink();
    }

    final isTablet = screenWidth < 1100;
    final horizontalPadding = isTablet ? 4.0 : 6.0;
    final gap = 10.0;
    final rawCardWidth = isTablet
        ? 158.0
        : ((contentWidth - (horizontalPadding * 2) - (gap * (stats.length - 1))) /
                stats.length)
            .clamp(165.0, 220.0);
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
              item['icon'] as IconData,
              compact: isTablet,
              isWarning: (item['isWarning'] as bool?) ?? false,
            ),
          ),
        );
      }),
    );

    return SizedBox(
      height: isTablet ? 108 : 116,
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


  List<SiloMassPoint> _buildSiloMassPoints({int? siloId}) {
    if (_siloHistory.isEmpty) return const <SiloMassPoint>[];

    final sourceHistory = siloId == null
        ? _siloHistory
        : _siloHistory.where((row) => row.idScale == siloId).toList(growable: false);

    if (sourceHistory.isEmpty) return const <SiloMassPoint>[];

    final timeframeDuration = _timeframeDurations[_selectedTimeframe] ??
        const Duration(hours: 1);

    final rows = _siloApiService.filterByTimeframe(
      source: sourceHistory,
      timeframe: timeframeDuration,
    );

    // Nếu filter theo timeframe rỗng thì lấy tạm 20 điểm gần nhất để tránh chart trống.
    final sourceRows = rows.isNotEmpty
      ? rows
      : (sourceHistory.length > 20
        ? sourceHistory.sublist(sourceHistory.length - 20)
        : sourceHistory);

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
        .map((row) => SiloMassPoint(
              time: row.time,
              weight: row.weightNow.toDouble(),
            ))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    // Fallback lần cuối: nếu toàn bộ điểm bị loại thì thử lấy lại từ 20 điểm mới nhất không qua filter timeframe.
    if (points.isEmpty) {
      final latestRows = sourceHistory.length > 20
          ? sourceHistory.sublist(sourceHistory.length - 20)
          : sourceHistory;

      return latestRows
          .map((row) => SiloMassPoint(
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
    if (maxWidth >= 720) {
      crossAxisCount = 4;
    } else if (maxWidth >= 500) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    final moduleCardAspectRatio = switch (crossAxisCount) {
      1 => 1.05,
      2 => 0.95,
      4 => 0.82,
      _ => 0.85,
    };


    final chartPoints = _buildSiloMassPoints();

    final overviewSiloIds = _getSettingsSiloIds();

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
          children: overviewSiloIds.map((siloId) {
            final idx = siloId - 1;
            final silo = _findSiloById(siloId);
            final siloName = silo?.id ?? 'Silo $siloId';

            final indicatorsForSilo = _indicators.isNotEmpty
                ? <Indicator>[_indicators[idx % _indicators.length]]
                : <Indicator>[];

            final controllersForSilo = _controllers.isNotEmpty
                ? <Controller>[_controllers[idx % _controllers.length]]
                : <Controller>[];

            return SiloModule(
              id: siloName,
              currentWeight: _getDisplayWeightForSilo(siloId),
              lastUpdatedAt: _getLatestTimestampForSilo(siloId),
              maxWeight: _getSiloMaxWeight(siloId),
              level: silo?.level ?? 0,
              indicators: indicatorsForSilo,
              controllers: controllersForSilo,
              silos: _silos,
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 20),
        SiloMassChart(
          title: 'Biểu đồ tổng hợp khối lượng',
          chartData: chartPoints,

          rawCount: _siloHistory.length,
          selectedTimeRange: _selectedTimeframe,
          timeRangeOptions: _timeframeDurations.keys.toList(growable: false),
          onTimeRangeChanged: _handleTimeframeSelected,
          transformationController: _chartTransformController,
        ),
      ],
    );
  }

  void _syncSilosWithLiveState() {
    if (_silos.isEmpty) {
      _silos = List<Silo>.generate(_totalSiloCount, (index) {
        final siloId = index + 1;
        final weight = _getDisplayWeightForSilo(siloId);
        final maxWeight = _getSiloMaxWeight(siloId);
        final level = maxWeight > 0 ? (weight / maxWeight).clamp(0.0, 1.0) : 0.0;
        return Silo(id: 'Silo $siloId', weight: weight, level: level);
      });
      return;
    }

    for (var i = 0; i < _silos.length; i++) {
      final s = _silos[i];
      final siloId = _extractSiloId(s.id, fallback: i + 1);
      final liveWeight = _getDisplayWeightForSilo(siloId);
      final maxWeight = _getSiloMaxWeight(siloId);
      final liveLevel = maxWeight > 0 ? (liveWeight / maxWeight).clamp(0.0, 1.0) : 0.0;

      if (s.weight != liveWeight || s.level != liveLevel) {
        _silos[i] = Silo(
          id: s.id,
          weight: liveWeight,
          level: liveLevel,
        );
      }
    }
  }

  Widget _buildPumpPlanCard({bool isCompactOverview = false}) {
    _syncSilosWithLiveState();

    return SiloPlanTable(
      silos: _silos,
      scrollController: _pumpPlanTableScrollController,
      onExportExcel: (exportItems) async {
        final messenger = ScaffoldMessenger.of(context);
        final result = await exportSiloStatusToExcel(
          items: exportItems,
        );

        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      },
      isCompactOverview: isCompactOverview,
    );
  }

  Widget _buildStatisticsReportCard({bool isCompactOverview = false}) {
    final statisticsSiloIds = _getStatisticsSiloIds();
    final selectedStatisticsSiloId = _getEffectiveStatisticsSiloId();
    final sourceHistory = _buildStatisticsHistorySource();
    final rows = generateCompressedStatisticsReport(sourceHistory)
        .reversed
        .toList();
    return SiloReportTable(
      siloIds: statisticsSiloIds,
      selectedSiloId: selectedStatisticsSiloId,
      rows: rows,
      scrollController: _statisticsTableScrollController,
      onSiloChanged: (value) async {
        await _handleStatisticsSiloChanged(value);
      },
      onExportPressed: (filteredRows) async {
        await _exportStatisticsReport(
          customRows: filteredRows,
          isAuto: false,
        );
      },
      isCompactOverview: isCompactOverview,
    );
  }

  Widget _buildPlanAndWarningSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPumpPlanCard(isCompactOverview: true),
        const SizedBox(height: 12),
        _buildStatisticsReportCard(isCompactOverview: true),
      ],
    );
  }

  Widget _buildReportTabSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatisticsReportCard(isCompactOverview: false),
      ],
    );
  }

  Widget _buildHistoryTabSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatisticsReportCard(isCompactOverview: false),
      ],
    );
  }


  Widget _buildWarningTabSection() {
    return Container(
      margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch sử cảnh báo hệ thống',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Giám sát các sự cố vượt ngưỡng cân và gián đoạn kết nối',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Text(
                  '5 cảnh báo gần nhất',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.error_outline, color: Color(0xFFEF4444)),
            title: Text('Silo 2: Khối lượng đạt 95% sức chứa Max', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            subtitle: Text('Thời gian: 14:32:10 - 29/07/2026', style: TextStyle(color: Color(0xFF64748B))),
            trailing: Chip(label: Text('Mức cao', style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Color(0xFFEF4444)),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
            title: Text('Silo 3: Mức nguyên liệu thấp (< 20%)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            subtitle: Text('Thời gian: 11:15:42 - 29/07/2026', style: TextStyle(color: Color(0xFF64748B))),
            trailing: Chip(label: Text('Cần nạp', style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Color(0xFFF59E0B)),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.sensors_off_rounded, color: Color(0xFF64748B)),
            title: Text('Cảm biến Silo 4: Gián đoạn tín hiệu SignalR tạm thời', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            subtitle: Text('Thời gian: 08:05:00 - 29/07/2026', style: TextStyle(color: Color(0xFF64748B))),
            trailing: Chip(label: Text('Đã tự khôi phục', style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Color(0xFF10B981)),
          ),
        ],
      ),
    );
  }

  Widget _buildPumpPlanTabSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPumpPlanCard(),
      ],
    );
  }


  Widget _buildSiloMonitorTabSection() {
    final monitorSiloIds = _getSettingsSiloIds();
    final selectedMonitorSiloId = _getEffectiveMonitorSiloId();

    if (selectedMonitorSiloId == null) {
      return Card(
        elevation: 4,
        margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Chưa có dữ liệu silo để giám sát'),
        ),
      );
    }

    final monitorWeight = _getDisplayWeightForSilo(selectedMonitorSiloId);
    final monitorUpdatedAt = _getLatestTimestampForSilo(selectedMonitorSiloId);
    final monitorSilo = _findSiloById(selectedMonitorSiloId);
    final monitorName = monitorSilo?.id ?? _getMonitorSiloName(selectedMonitorSiloId);
    final monitorChartData = _buildSiloMassPoints(siloId: selectedMonitorSiloId);
    final monitorRawCount = _siloHistory
      .where((row) => row.idScale == selectedMonitorSiloId)
      .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Giám sát mô phỏng silo',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedMonitorSiloId,
                    items: monitorSiloIds
                        .map(
                          (id) => DropdownMenuItem<int>(
                            value: id,
                            child: Text('Silo $id'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMonitorSiloId = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Silo',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Widget mô phỏng dùng chung cho khu vực Tổng quan và tab Giám sát silo.
        SiloVisualizer(
          siloName: monitorName,
          currentWeight: monitorWeight,
          maxWeight: _getSiloMaxWeight(selectedMonitorSiloId),
          lastUpdatedAt: monitorUpdatedAt,
        ),
        const SizedBox(height: 12),
        SiloMassChart(
          title: 'Biểu đồ khối lượng $monitorName',
          chartData: monitorChartData,
          rawCount: monitorRawCount,
          selectedTimeRange: _selectedTimeframe,
          timeRangeOptions: _timeframeDurations.keys.toList(growable: false),
          onTimeRangeChanged: _handleTimeframeSelected,
          transformationController: _chartTransformController,
        ),
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cài đặt Cân Max & Ngưỡng nhiễu',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              _buildInfoBadge('Silo hiện có: $displaySiloCount'),
            ],
          ),
          const SizedBox(height: 16),
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
                    final loadedNoise = await loadSiloNoiseConfig(value);
                    if (!mounted) return;

                    setState(() {
                      _settingsMaxWeightController.text = loadedMax.toStringAsFixed(1);
                      _settingsMaxWeightError = _validateMaxWeight(
                        _settingsMaxWeightController.text,
                      );
                      _settingsNoiseThresholdKg = loadedNoise;
                    });
                  },
            decoration: InputDecoration(
              labelText: 'Chọn Silo',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _settingsMaxWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cân Max (kg)',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ngưỡng nhiễu: ${_settingsNoiseThresholdKg.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0369A1),
                  ),
                ),
                Slider(
                  value: _settingsNoiseThresholdKg,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  activeColor: const Color(0xFF0284C7),
                  label: '${_settingsNoiseThresholdKg.toStringAsFixed(0)} kg',
                  onChanged: (value) {
                    setState(() {
                      _settingsNoiseThresholdKg = value;
                      if (_selectedSettingsSiloId == _getActiveSiloId()) {
                        _noiseThresholdKg = value;
                      }
                    });
                  },
                  onChangeEnd: (value) async {
                    final siloId = _selectedSettingsSiloId;
                    if (siloId == null) return;
                    await saveSiloNoiseConfig(siloId, value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                await saveSiloNoiseConfig(siloId, _settingsNoiseThresholdKg);
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    content: Text(
                      'Đã lưu Silo $siloId | Cân Max: ${maxWeight.toStringAsFixed(1)} kg | Ngưỡng nhiễu: ${_settingsNoiseThresholdKg.toStringAsFixed(0)} kg',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Lưu cấu hình'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Cấu hình được lưu tự động và áp dụng trên toàn bộ các widget theo thời gian thực.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserManagementCard() {
    if (_isAdmin) {
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Quản lý người dùng',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                _buildInfoBadge('Tài khoản: ${_userAccounts.length}'),
                OutlinedButton.icon(
                  onPressed: _loadUserAccounts,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Tải lại'),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateUserDialog,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Tạo tài khoản mới'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingUserAccounts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_userAccountsError != null)
              Text(
                _userAccountsError!,
                style: const TextStyle(color: Color(0xFFEF4444)),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.resolveWith(
                    (states) => const Color(0xFFF8FAFC),
                  ),
                  columns: const [
                    DataColumn(label: Text('Tên đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                    DataColumn(label: Text('Vai trò', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                    DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  ],
                  rows: _userAccounts.map((user) {
                    final username = (user['username'] ?? '').toString();
                    final role = (user['role'] ?? 'sub').toString();

                    return DataRow(
                      cells: [
                        DataCell(Text(username, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                        DataCell(Text(role, style: const TextStyle(color: Color(0xFF475569)))),
                        DataCell(
                          OutlinedButton.icon(
                            onPressed: () => _showEditUserDialog(user),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Sửa đổi thông tin'),
                          ),
                        ),
                      ],
                    );
                  }).toList(growable: false),
                ),
              ),
          ],
        ),
      );
    }

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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Thông tin cá nhân',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEEF2FF),
              child: Icon(Icons.person, color: Color(0xFF2563EB)),
            ),
            title: Text(_currentUserName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            subtitle: const Text('Tài khoản con', style: TextStyle(color: Color(0xFF64748B))),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _showChangeMyPasswordDialog,
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('Đổi mật khẩu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCompactDashboard(double maxWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    final showStats = screenWidth >= 600;
    final isOverview = _selectedIndex <= 0;
    final showSiloMonitorTab = _selectedIndex == _siloMonitorTabIndex;
    final showPumpPlanTab = _selectedIndex == _pumpPlanTabIndex;
    final showHistoryTab = _selectedIndex == _historyTabIndex;
    final showWarningTab = _selectedIndex == _warningTabIndex;
    final showReportTab = _selectedIndex == _reportTabIndex;
    final showSettings = _selectedIndex == _settingsTabIndex;
    final showUserManagement = _selectedIndex == _userManagementTabIndex;
    final horizontalPadding = maxWidth < 640 ? 10.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          'TỔNG QUAN HỆ THỐNG',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0B1B3D),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0B1B3D),
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
                if (showStats && isOverview)
                  _buildStatsSection(
                    screenWidth: screenWidth,
                    contentWidth: maxWidth,
                  ),
                if (showStats && isOverview)
                  const SizedBox(height: 16),
                if (showSettings)
                  _buildSettingsConfigurationCard()
                else if (showUserManagement)
                  _buildUserManagementCard()
                else if (showSiloMonitorTab)
                  _buildSiloMonitorTabSection()
                else if (showPumpPlanTab)
                  _buildPumpPlanTabSection()
                else if (showHistoryTab)
                  _buildHistoryTabSection()
                else if (showWarningTab)
                  _buildWarningTabSection()
                else if (showReportTab)
                  _buildReportTabSection()
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
    final isOverview = _selectedIndex <= 0;
    final showSiloMonitorTab = _selectedIndex == _siloMonitorTabIndex;
    final showPumpPlanTab = _selectedIndex == _pumpPlanTabIndex;
    final showHistoryTab = _selectedIndex == _historyTabIndex;
    final showWarningTab = _selectedIndex == _warningTabIndex;
    final showReportTab = _selectedIndex == _reportTabIndex;
    final showSettings = _selectedIndex == _settingsTabIndex;
    final showUserManagement = _selectedIndex == _userManagementTabIndex;
    final rightPanelWidth = (screenWidth * 0.30).clamp(420.0, 560.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TỔNG QUAN HỆ THỐNG',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Giám sát & Điều khiển hệ thống cân định lượng silo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Trực tuyến',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              color: Color(0xFF475569),
                              size: 26,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      PopupMenuButton<String>(
                        tooltip: 'Tài khoản',
                        onSelected: (value) async {
                          if (value != 'logout') return;

                          final authService = AuthService();
                          await authService.logout();

                          if (!mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, size: 18, color: Color(0xFFEF4444)),
                                SizedBox(width: 8),
                                Text('Đăng xuất', style: TextStyle(color: Color(0xFFEF4444))),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                  ),
                                ),
                                child: ClipOval(
                                  child: _currentUserAvatarUrl.isNotEmpty
                                      ? Image.network(
                                          _currentUserAvatarUrl,
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 20,
                                            );
                                          },
                                        )
                                      : const Icon(Icons.person, color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentUserName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    _currentUserRole,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSidebar(sidebarWidth),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isOverview)
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
                                : showUserManagement
                                    ? SingleChildScrollView(
                                        child: _buildUserManagementCard(),
                                      )
                                : showSiloMonitorTab
                                  ? SingleChildScrollView(
                                    child: _buildSiloMonitorTabSection(),
                                    )
                                : showPumpPlanTab
                                  ? SingleChildScrollView(
                                    child: _buildPumpPlanTabSection(),
                                    )
                                : showHistoryTab
                                  ? SingleChildScrollView(
                                    child: _buildHistoryTabSection(),
                                    )
                                : showWarningTab
                                  ? SingleChildScrollView(
                                    child: _buildWarningTabSection(),
                                    )
                                : showReportTab
                                    ? SingleChildScrollView(
                                        child: _buildReportTabSection(),
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
