import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/silo_history_model.dart';

class SiloApiService {
  static String get historyUrl => '${AppConfig.baseUrl}/Scales/GetHistory';

  final Duration pollingInterval;
  final http.Client _httpClient;
  final StreamController<List<SiloHistoryModel>> _historyController;

  Timer? _pollTimer;
  List<SiloHistoryModel> _latestHistory = const [];

  SiloApiService({
    this.pollingInterval = const Duration(seconds: 5),
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _historyController = StreamController<List<SiloHistoryModel>>.broadcast();

  List<SiloHistoryModel> get latestHistory => List.unmodifiable(_latestHistory);

  Stream<List<SiloHistoryModel>> watchHistory({
    int sync = -1,
    int id = -1,
  }) {
    _startPolling(sync: sync, id: id);
    return _historyController.stream;
  }

  Future<List<SiloHistoryModel>> fetchHistory({
    int sync = -1,
    int id = -1,
  }) async {
    final uri = Uri.parse(historyUrl).replace(
      queryParameters: {
        'sync': '$sync',
        'Id': '$id',
      },
    );

    final response = await _httpClient
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to load silo history: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final list = SiloHistoryModel.parseListFromResponse(
      decoded,
      defaultId: id,
    )..sort((a, b) => a.recordTime.compareTo(b.recordTime));

    _latestHistory = list;
    return list;
  }

  List<SiloHistoryModel> filterByTimeframe({
    required List<SiloHistoryModel> source,
    required Duration timeframe,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final from = current.subtract(timeframe);

    return source
        .where((row) =>
            !row.recordTime.isBefore(from) && !row.recordTime.isAfter(current))
        .toList()
      ..sort((a, b) => a.recordTime.compareTo(b.recordTime));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    stopPolling();
    _httpClient.close();
    _historyController.close();
  }

  void _startPolling({required int sync, required int id}) {
    stopPolling();

    _emitLatest(sync: sync, id: id);

    _pollTimer = Timer.periodic(pollingInterval, (_) {
      _emitLatest(sync: sync, id: id);
    });
  }

  Future<void> _emitLatest({required int sync, required int id}) async {
    try {
      final list = await fetchHistory(sync: sync, id: id);
      if (!_historyController.isClosed) {
        _historyController.add(list);
      }
    } catch (error) {
      if (!_historyController.isClosed) {
        _historyController.addError(error);
      }
    }
  }
}
