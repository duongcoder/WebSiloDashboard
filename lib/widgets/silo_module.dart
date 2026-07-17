import 'package:flutter/material.dart';
import '../models/controller.dart';
import '../models/indicator.dart';
import '../models/silo.dart';
import 'silo_visualizer.dart';

class SiloModule extends StatelessWidget {
  final String id;
  final double? currentWeight;
  final DateTime? lastUpdatedAt;
  final double maxWeight;
  final double level; // not used for UI (level is calculated from weight/max)
  final List<Indicator> indicators;
  final List<Controller> controllers;
  final List<Silo> silos;

  const SiloModule({
    super.key,
    required this.id,
    required this.currentWeight,
    this.lastUpdatedAt,
    required this.maxWeight,
    required this.level,
    required this.indicators,
    required this.controllers,
    required this.silos,
  });

  @override
  Widget build(BuildContext context) {
    // Dữ liệu hiển thị lấy trực tiếp từ state cha để đảm bảo single source of truth.
    return SiloVisualizer(
      siloName: id,
      currentWeight: currentWeight ?? 0,
      maxWeight: maxWeight,
      lastUpdatedAt: lastUpdatedAt,
    );
  }
}
