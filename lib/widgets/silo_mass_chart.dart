import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SiloMassPoint {
  final DateTime time;
  final double weight;

  const SiloMassPoint({
    required this.time,
    required this.weight,
  });
}

class SiloMassChart extends StatefulWidget {
  final String title;
  final List<SiloMassPoint> chartData;
  final int rawCount;
  final String selectedTimeRange;
  final List<String> timeRangeOptions;
  final ValueChanged<String> onTimeRangeChanged;
  final TransformationController transformationController;

  const SiloMassChart({
    super.key,
    required this.title,
    required this.chartData,
    required this.rawCount,
    required this.selectedTimeRange,
    required this.timeRangeOptions,
    required this.onTimeRangeChanged,
    required this.transformationController,
  });

  @override
  State<SiloMassChart> createState() => _SiloMassChartState();
}

class _SiloMassChartState extends State<SiloMassChart> {
  static const List<Color> _siloColors = [
    Color(0xFF2563EB), // Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Crimson Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
  ];

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

  Widget _buildLegendRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(8, (index) {
          final color = _siloColors[index % _siloColors.length];
          final siloNum = index + 1;
          final isActive = index == 0; // Default active indicator

          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Silo $siloNum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartPoints = <FlSpot>[];
    for (final point in widget.chartData) {
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
    final maxWeight = hasData
        ? chartPoints.map((spot) => spot.y).reduce((a, b) => a > b ? a : b)
        : 50000.0;
    final maxY = hasData
        ? (maxWeight * 1.15).clamp(1.0, double.infinity)
        : 50000.0;
    final xInterval = hasData
        ? ((maxX - minX) / 4).clamp(1.0, double.infinity)
        : 1.0;
    final yInterval = ((maxY - 0.0) / 5).clamp(1.0, double.infinity);

    return Container(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Biểu đồ biến thiên khối lượng theo thời gian thực (kg)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  'Dữ liệu ${widget.rawCount}/$validCount điểm',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildLegendRow(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Khung thời gian:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.timeRangeOptions.map((option) {
                    final selected = option == widget.selectedTimeRange;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(
                          option,
                          style: TextStyle(
                            color: selected ? Colors.white : const Color(0xFF475569),
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 11.5,
                          ),
                        ),
                        selected: selected,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (_) => widget.onTimeRangeChanged(option),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasData
                    ? InteractiveViewer(
                        transformationController: widget.transformationController,
                        minScale: 1.0,
                        maxScale: 6.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        clipBehavior: Clip.hardEdge,
                        child: LineChart(
                          LineChartData(
                            clipData: FlClipData.all(),
                            baselineY: 0,
                            minX: minX,
                            maxX: maxX,
                            minY: 0,
                            maxY: maxY,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              horizontalInterval: yInterval,
                              verticalInterval: xInterval,
                              getDrawingHorizontalLine: (value) => const FlLine(
                                color: Color(0xFFF1F5F9),
                                strokeWidth: 1,
                              ),
                              getDrawingVerticalLine: (value) => const FlLine(
                                color: Color(0xFFF1F5F9),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 46,
                                  interval: yInterval,
                                  getTitlesWidget: (value, meta) => SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      _formatWeightAxis(value),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: xInterval,
                                  reservedSize: 32,
                                  getTitlesWidget: (value, meta) {
                                    final dateTime = DateTime.fromMillisecondsSinceEpoch(
                                      value.toInt(),
                                    );

                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        _formatTimeHms(dateTime),
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
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
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            lineTouchData: LineTouchData(
                              enabled: true,
                              handleBuiltInTouches: true,
                              touchTooltipData: LineTouchTooltipData(
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final spotTime = DateTime.fromMillisecondsSinceEpoch(
                                      spot.x.toInt(),
                                    );

                                    return LineTooltipItem(
                                      '${spot.y.toStringAsFixed(2)} kg\n${_formatTimeHms(spotTime)}',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }).toList(growable: false);
                                },
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: chartPoints,
                                isCurved: true,
                                preventCurveOverShooting: true,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
                                ),
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: 4,
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                      strokeColor: const Color(0xFF2563EB),
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF2563EB).withValues(alpha: 0.20),
                                      const Color(0xFF2563EB).withValues(alpha: 0.0),
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
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
