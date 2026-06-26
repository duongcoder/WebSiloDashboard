import 'dart:async';
import 'dart:convert';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

import '../models/silo_history_model.dart';

// lấy origin động khi release (production), còn debug dùng IP cố định
String get baseUrl {
  if (!kReleaseMode) {
    return 'http://14.232.245.56:8089';
  }
  return Uri.base.origin;
}




class SiloApiService {
  // Debug: IP cố định; Release: origin động (đúng IP/Domain máy khách)
  static String get _directHistoryUrl => '$baseUrl/api/Scales/GetHistory';



  final Duration pollingInterval;
  final http.Client _httpClient;
  final StreamController<List<SiloHistoryModel>> _historyController;

  Timer? _pollTimer;
  List<SiloHistoryModel> _latestHistory = const [];
  bool _isFetching = false;

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
    final endpointCandidates = _buildHistoryEndpoints();

    Object? lastError;

    for (final endpoint in endpointCandidates) {
      try {
        final uri = Uri.parse(endpoint).replace(
          queryParameters: {
            'sync': '$sync',
            'Id': '$id',
          },
        );

        final response = await _httpClient
            .get(uri)
            .timeout(const Duration(seconds: 12));

        if (response.statusCode != 200) {
          lastError = Exception(
            'Failed to load silo history from $endpoint: ${response.statusCode}',
          );
          continue;
        }

        final decoded = jsonDecode(response.body);
        final list = SiloHistoryModel.parseListFromResponse(
          decoded,
          defaultId: id,
        )..sort((a, b) => a.recordTime.compareTo(b.recordTime));

        _latestHistory = list;
        return list;
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception('History polling failed on all endpoints: $lastError');
  }

  List<String> _buildHistoryEndpoints() {
    final proxyEndpoint = '${AppConfig.baseUrl}/Scales/GetHistory';

    // Web luôn đi qua backend proxy để tránh CORS từ upstream 14.232.*
    if (kIsWeb) {
      return <String>[proxyEndpoint];
    }

    return <String>[
      _directHistoryUrl,
      proxyEndpoint,
    ];
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

    _emitLatest(sync: sync, id: _resolvePollingId(baseId: id));

    _pollTimer = Timer.periodic(pollingInterval, (_) {
      _emitLatest(sync: sync, id: _resolvePollingId(baseId: id));
    });
  }

  Future<void> _emitLatest({required int sync, required int id}) async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final list = await fetchHistory(sync: sync, id: id);
      if (!_historyController.isClosed) {
        _historyController.add(list);
      }
    } catch (error) {
      if (!_historyController.isClosed) {
        _historyController.addError(error);
      }
    } finally {
      _isFetching = false;
    }
  }

  int _resolvePollingId({required int baseId}) {
    if (baseId >= 0) return baseId;

    if (_latestHistory.isEmpty) return -1;

    final latestId = _latestHistory
        .map((row) => row.id)
        .reduce((a, b) => a > b ? a : b);

    return latestId;
  }
}
