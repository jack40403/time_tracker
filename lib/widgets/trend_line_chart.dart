import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/time_session.dart';

class TrendLineChart extends StatelessWidget {
  final List<TimeSession> sessions;
  final String filter;
  final int offset;
  final Map<String, Color> catColors; // 只傳要顯示的分類
  final String? categoryFilter;

  const TrendLineChart({
    super.key,
    required this.sessions,
    required this.filter,
    required this.offset,
    required this.catColors,
    this.categoryFilter,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final labels = <String>[];
    final bucketStarts = <DateTime>[];
    final bucketEnds = <DateTime>[];

    switch (filter) {
      case 'weekly':
        final refDate = now.subtract(Duration(days: offset * 7));
        final refMon = refDate.subtract(Duration(days: refDate.weekday - 1));
        for (int i = 0; i < 8; i++) {
          final mon = DateTime(refMon.year, refMon.month, refMon.day - (7 - i) * 7);
          final sun = mon.add(const Duration(days: 6));
          bucketStarts.add(mon);
          bucketEnds.add(DateTime(sun.year, sun.month, sun.day, 23, 59, 59));
          labels.add('${mon.month}/${mon.day}');
        }
      case 'monthly':
        final base = DateTime(now.year, now.month - offset);
        for (int i = 0; i < 12; i++) {
          final m = DateTime(base.year, base.month - (11 - i));
          bucketStarts.add(m);
          bucketEnds.add(DateTime(m.year, m.month + 1).subtract(const Duration(seconds: 1)));
          labels.add('${m.month}月');
        }
      case 'yearly':
        final endYear = now.year - offset;
        for (int i = 0; i < 5; i++) {
          final y = endYear - (4 - i);
          bucketStarts.add(DateTime(y));
          bucketEnds.add(DateTime(y, 12, 31, 23, 59, 59));
          labels.add('$y');
        }
      default: // daily / custom → 顯示 14 天
        final refDay = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
        for (int i = 0; i < 14; i++) {
          final d = refDay.subtract(Duration(days: 13 - i));
          bucketStarts.add(DateTime(d.year, d.month, d.day));
          bucketEnds.add(DateTime(d.year, d.month, d.day, 23, 59, 59));
          labels.add('${d.month}/${d.day}');
        }
    }

    final catsToShow = categoryFilter != null ? [categoryFilter!] : catColors.keys.toList();

    final lines = <LineChartBarData>[];
    for (final cat in catsToShow) {
      final color = catColors[cat] ?? Colors.grey;
      final spots = <FlSpot>[];
      for (int i = 0; i < bucketStarts.length; i++) {
        final h = sessions
            .where((s) =>
                s.category == cat &&
                !s.date.isBefore(bucketStarts[i]) &&
                !s.date.isAfter(bucketEnds[i]))
            .fold(0.0, (sum, s) => sum + s.durationSeconds / 3600);
        spots.add(FlSpot(i.toDouble(), double.parse(h.toStringAsFixed(2))));
      }
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: color.withOpacity(0.08)),
      ));
    }

    double maxY = lines.expand((l) => l.spots).fold(0.0, (a, s) => s.y > a ? s.y : a);
    if (maxY < 1) maxY = 1;
    maxY = (maxY * 1.3).ceilToDouble();

    final labelInterval = labels.length > 8 ? (labels.length / 7).ceil().toDouble() : 1.0;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((ts) {
              final cat = catsToShow[ts.barIndex];
              return LineTooltipItem(
                '$cat  ${ts.y.toStringAsFixed(1)}h',
                TextStyle(
                  color: catColors[cat] ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: labelInterval,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (v == i.toDouble() && i >= 0 && i < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(labels[i], style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) {
                if (v == v.roundToDouble()) {
                  return Text('${v.toInt()}h', style: const TextStyle(fontSize: 9, color: Colors.grey));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).clamp(0.5, double.infinity),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: lines,
      ),
    );
  }
}
