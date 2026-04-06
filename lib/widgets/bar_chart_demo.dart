import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/time_session.dart';

class BarChartDemo extends StatelessWidget {
  final List<TimeSession> sessions;
  final String filter;
  final int offset;
  const BarChartDemo({super.key, required this.sessions, required this.filter, required this.offset});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final Map<int, double> totals = {};
    late int barCount;
    late double topY;
    // For label computation
    List<String> labels = [];

    if (filter == 'yearly') {
      barCount = 5;
      topY = 500;
      final endYear = now.year - offset;
      for (int i = 0; i < 5; i++) {
        final year = endYear - (4 - i);
        totals[i] = sessions
            .where((s) => s.date.year == year)
            .fold(0.0, (sum, s) => sum + (s.durationSeconds / 3600));
        labels.add('$year');
      }
    } else if (filter == 'monthly') {
      barCount = 6;
      topY = 100;
      final baseMonth = DateTime(now.year, now.month - offset);
      for (int i = 0; i < 6; i++) {
        final m = DateTime(baseMonth.year, baseMonth.month - (5 - i));
        totals[i] = sessions
            .where((s) => s.date.year == m.year && s.date.month == m.month)
            .fold(0.0, (sum, s) => sum + (s.durationSeconds / 3600));
        labels.add('${m.month}月');
      }
    } else if (filter == 'weekly') {
      barCount = 4;
      topY = 50;
      for (int i = 0; i < 4; i++) {
        final refDate = now.subtract(Duration(days: offset * 7));
        final refMon = refDate.subtract(Duration(days: refDate.weekday - 1));
        final weekMon = DateTime(refMon.year, refMon.month, refMon.day - (3 - i) * 7);
        final weekSun = weekMon.add(const Duration(days: 6));
        final sDate = DateTime(weekMon.year, weekMon.month, weekMon.day);
        final eDate = DateTime(weekSun.year, weekSun.month, weekSun.day, 23, 59, 59);
        totals[i] = sessions
            .where((s) => s.date.isAfter(sDate.subtract(const Duration(seconds: 1))) && s.date.isBefore(eDate.add(const Duration(seconds: 1))))
            .fold(0.0, (sum, s) => sum + (s.durationSeconds / 3600));
        labels.add('${weekMon.month}/${weekMon.day}');
      }
    } else {
      barCount = 7;
      topY = 12;
      final refDay = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
      for (int i = 0; i < 7; i++) {
        final d = refDay.subtract(Duration(days: 6 - i));
        totals[i] = sessions
            .where((s) => s.date.year == d.year && s.date.month == d.month && s.date.day == d.day)
            .fold(0.0, (sum, s) => sum + (s.durationSeconds / 3600));
        labels.add('${d.month}/${d.day}');
      }
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: topY,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < labels.length) {
                  return Text(labels[i], style: const TextStyle(fontSize: 9, color: Colors.grey));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9)))),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: topY / 4),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(barCount, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: totals[i] ?? 0,
                color: Theme.of(context).colorScheme.primary,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: topY, color: Theme.of(context).colorScheme.primary.withOpacity(0.05)),
              )
            ],
          );
        }),
      ),
    );
  }
}
