import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/time_session.dart';
import '../providers/session_provider.dart';
import '../providers/category_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/bar_chart_demo.dart';
import 'statistics_page.dart';
import '../helpers/format_utils.dart';
import '../helpers/filter_utils.dart';

class CategoryDetailPage extends ConsumerWidget {
  final String category;
  const CategoryDetailPage({super.key, required this.category});

  String _formatTime(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hrs > 0) return '${hrs}h ${mins}m ${secs}s';
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSessions = ref.watch(sessionsProvider).where((s) => s.category == category).toList();
    final filter = ref.watch(statsFilterProvider);
    final offset = ref.watch(statsOffsetProvider);
    final catColor = ref.watch(categoryColorProvider)[category] ?? Colors.blue;
    final customRange = ref.watch(statsCustomRangeProvider);
    
    final filteredSessions = FilterUtils.getFilteredSessions(allSessions, filter, offset, customRange);
    final totalSeconds = filteredSessions.fold(0, (sum, s) => sum + s.durationSeconds);

    final Map<String, List<TimeSession>> grouped = {};
    for (var s in filteredSessions) {
      final dateKey = '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(dateKey, () => []).add(s);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text(category, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [catColor.withOpacity(0.2), catColor.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: catColor.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    FilterUtils.getFilterLabel(filter, offset, customRange),
                    style: TextStyle(color: catColor.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    FormatUtils.formatDurationDetailed(totalSeconds),
                    style: GoogleFonts.shareTechMono(fontSize: 48, fontWeight: FontWeight.bold, color: catColor),
                  ),
                  const SizedBox(height: 4),
                  Text('區段總計時間', style: TextStyle(color: catColor.withOpacity(0.6), fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded, size: 20),
                const SizedBox(width: 8),
                Text('趨勢分析', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 260,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: BarChartDemo(sessions: allSessions, filter: filter, offset: offset),
            ),
            const SizedBox(height: 40),

            Row(
              children: [
                const Icon(Icons.history_rounded, size: 20),
                const SizedBox(width: 8),
                Text('詳細歷史紀錄', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            
            if (sortedDates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('此時段沒有紀錄', style: TextStyle(color: Colors.grey.shade400))),
              )
            else
              ...sortedDates.map((String date) {
                final List<TimeSession> dateSessions = grouped[date]!;
                final dailyTotal = dateSessions.fold(0, (sum, s) => sum + s.durationSeconds);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(_formatTime(dailyTotal), style: TextStyle(color: catColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ...dateSessions.map((TimeSession s) {
                      return Dismissible(
                        key: ValueKey('${s.category}_${s.date.millisecondsSinceEpoch}_${s.durationSeconds}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          ref.read(sessionsProvider.notifier).deleteSession(s);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('已刪除紀錄'),
                            duration: Duration(milliseconds: 1000),
                          ));
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: catColor, shape: BoxShape.circle)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  '${s.date.hour.toString().padLeft(2, '0')}:${s.date.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(_formatTime(s.durationSeconds), style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
