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
    const minY = 0.0;
    final maxY = hasData
        ? (maxWeight * 1.15).clamp(1.0, double.infinity)
        : 50000.0;
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
                    widget.title,
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
                    'debug ${widget.rawCount}/$validCount',
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
                children: widget.timeRangeOptions.map((option) {
                  final selected = option == widget.selectedTimeRange;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option),
                      selected: selected,
                      onSelected: (_) => widget.onTimeRangeChanged(option),
                    ),
                  );
                }).toList(growable: false),
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