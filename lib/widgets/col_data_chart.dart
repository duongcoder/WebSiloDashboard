import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/col_data.dart';

class ColDataChart extends StatelessWidget {
  final List<ColData> data;

  // Constructor nhận dữ liệu từ bên ngoài
  const ColDataChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("Không có dữ liệu ColData"));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                int index = value.toInt();
                if (index < 0 || index >= data.length) return Container();
                final date = data[index].recordDate.split("T").first;
                return Text(date, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        barGroups: data.asMap().entries.map((entry) {
          int index = entry.key;
          ColData item = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: item.weightKg,
                color: Colors.blue,
                width: 16,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
