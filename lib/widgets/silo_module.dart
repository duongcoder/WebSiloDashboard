import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/controller.dart';
import '../models/indicator.dart';
import '../models/silo.dart';
import 'silo_visualizer.dart';

class SiloModule extends StatefulWidget {
  final String id;
  final double? currentWeight;
  final double maxWeight;
  final double level; // not used for UI (level is calculated from weight/max)
  final List<Indicator> indicators;
  final List<Controller> controllers;
  final List<Silo> silos;

  const SiloModule({
    super.key,
    required this.id,
    required this.currentWeight,
    required this.maxWeight,
    required this.level,
    required this.indicators,
    required this.controllers,
    required this.silos,
  });

  @override
  State<SiloModule> createState() => _SiloModuleState();
}

class _SiloModuleState extends State<SiloModule> {
  double _currentWeight = 0;
  bool _isFetchingScale = false;

  DateTime? _lastUpdatedAt;


  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentWeight = widget.currentWeight ?? 0;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadScaleValue();
    });

    _loadScaleValue();
  }

  Future<void> _loadScaleValue() async {
    if (_isFetchingScale) return;
    _isFetchingScale = true;

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/Scales/GetScaleValue?id=1'),
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final value = (data['value'] as num).toDouble();
        setState(() {
          _currentWeight = value;
          final dynamic rawTime = data['dateTime'];
          if (rawTime is String) {
            _lastUpdatedAt = DateTime.tryParse(rawTime);
          } else {
            _lastUpdatedAt = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      _isFetchingScale = false;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SiloVisualizer(
      siloName: widget.id,
      currentWeight: _currentWeight,
      maxWeight: widget.maxWeight,
      lastUpdatedAt: _lastUpdatedAt,
    );
  }
}
