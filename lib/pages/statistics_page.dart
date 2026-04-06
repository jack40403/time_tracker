import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/time_session.dart';
import '../providers/session_provider.dart';
import '../providers/category_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/bar_chart_demo.dart';
import '../widgets/elite_date_range_picker.dart';
import 'category_detail_page.dart';
import '../helpers/format_utils.dart';

import '../helpers/filter_utils.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  Widget _buildFilterChip(String value, String label, String currentFilter, WidgetRef ref, BuildContext context) {
    final isSelected = currentFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (val) async {
        if (val) {
          ref.read(statsFilterProvider.notifier).setFilter(value);
          if (value == 'custom') {
            final range = await EliteDateRangePicker.show(
              context,
              initialDateRange: ref.read(statsCustomRangeProvider),
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (range != null) {
              ref.read(statsCustomRangeProvider.notifier).setRange(range);
            }
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSessions = ref.watch(sessionsProvider);
    final filter = ref.watch(statsFilterProvider);
    final offset = ref.watch(statsOffsetProvider);
    final customRange = ref.watch(statsCustomRangeProvider);
    final catColors = ref.watch(categoryColorProvider);
    final visibleCats = ref.watch(visibleCategoriesProvider);
    final categoryFilter = ref.watch(statsCategoryFilterProvider);
    
    var filteredSessions = FilterUtils.getFilteredSessions(allSessions, filter, offset, customRange);

    // Calculate total for percentage before filtering for specific category
    final globalTotalTotal = filteredSessions.fold(0, (sum, s) => sum + s.durationSeconds);

    // Apply category filter
    if (categoryFilter != null) {
      filteredSessions = filteredSessions.where((s) => s.category == categoryFilter).toList();
    }
    final Map<String, int> categoryTotals = {};
    for (var s in filteredSessions) {
      categoryTotals[s.category] = (categoryTotals[s.category] ?? 0) + s.durationSeconds;
    }

    // NEW: Include currently running timer if we are looking at "Today"
    final timerState = ref.watch(timerProvider);
    bool isViewingToday = (filter == 'daily' && offset == 0);
    
    if (isViewingToday && timerState.currentElapsed > 0) {
      categoryTotals[timerState.category] = (categoryTotals[timerState.category] ?? 0) + timerState.currentElapsed;
    }

    final totalSeconds = categoryTotals.values.fold(0, (sum, val) => sum + val);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('統計', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Chips
            Center(
              child: Container(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterChip('daily', '日', filter, ref, context),
                    _buildFilterChip('weekly', '週', filter, ref, context),
                    _buildFilterChip('monthly', '月', filter, ref, context),
                    _buildFilterChip('yearly', '年', filter, ref, context),
                    _buildFilterChip('custom', '自定義 📅', filter, ref, context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Category Chips
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCategoryChip(null, '全部', categoryFilter == null, ref, context),
                    ...visibleCats.map((cat) => _buildCategoryChip(cat, cat, categoryFilter == cat, ref, context)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Time Machine controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (filter != 'custom')
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => ref.read(statsOffsetProvider.notifier).setOffset(offset + 1),
                  ),
                InkWell(
                  onTap: filter == 'custom' ? () async {
                    final range = await EliteDateRangePicker.show(
                      context,
                      initialDateRange: customRange,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (range != null) {
                      ref.read(statsCustomRangeProvider.notifier).setRange(range);
                    }
                  } : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          FilterUtils.getFilterLabel(filter, offset, customRange),
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                        ),
                        if (filter == 'custom') ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.edit_calendar_outlined, size: 16, color: Colors.blue),
                        ],
                      ],
                    ),
                  ),
                ),
                if (filter != 'custom')
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: offset > 0 ? () => ref.read(statsOffsetProvider.notifier).setOffset(offset - 1) : null,
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Text('時間分配', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (totalSeconds == 0)
              Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('此區段無紀錄', style: TextStyle(color: Colors.grey.shade400))))
            else if (categoryFilter != null)
              // Specific category focus view
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (catColors[categoryFilter] ?? Colors.blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: (catColors[categoryFilter] ?? Colors.blue).withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(categoryFilter, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: catColors[categoryFilter])),
                    const SizedBox(height: 8),
                    Text(FormatUtils.formatDurationDetailed(totalSeconds), style: GoogleFonts.shareTechMono(fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('佔比 ${((totalSeconds / globalTotalTotal) * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: categoryTotals.entries.map((e) {
                            final percentage = (e.value / totalSeconds) * 100;
                            final mins = e.value ~/ 60;
                            final hrs = mins ~/ 60;
                            final remainMins = mins % 60;
                            final timeLabel = hrs > 0 ? '${hrs}h${remainMins}m' : '${mins}m';
                            return PieChartSectionData(
                              color: catColors[e.key] ?? Colors.grey,
                              value: e.value.toDouble(),
                              title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%\n$timeLabel' : '',
                              radius: 62,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: categoryTotals.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: catColors[e.key], shape: BoxShape.circle)),
                            const SizedBox(width: 14),
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 40),
            Text('近期趨勢', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
              child: BarChartDemo(sessions: allSessions, filter: filter, offset: offset),
            ),
            const SizedBox(height: 40),
            Text('詳細項目', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...categoryTotals.entries.map((e) {
              final color = catColors[e.key] ?? Colors.grey;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    if (categoryFilter == e.key) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryDetailPage(category: e.key)));
                    } else {
                      ref.read(statsCategoryFilterProvider.notifier).setCategory(e.key);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 16),
                        Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                        Text(FormatUtils.formatDuration(e.value), style: GoogleFonts.shareTechMono(color: Theme.of(context).colorScheme.primary, fontSize: 18)),
                        const SizedBox(width: 12),
                        const Icon(Icons.chevron_right_rounded, size: 24, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String? value, String label, bool isSelected, WidgetRef ref, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => ref.read(statsCategoryFilterProvider.notifier).setCategory(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
