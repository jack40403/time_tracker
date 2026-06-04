import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/cartoon_theme.dart';
import '../providers/app_theme_provider.dart';
import '../models/goal.dart';
import '../providers/session_provider.dart';
import '../providers/task_goal_provider.dart';
import '../providers/category_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/bar_chart_demo.dart';
import '../widgets/trend_line_chart.dart';
import '../widgets/elite_date_range_picker.dart';
import 'category_detail_page.dart';
import '../helpers/format_utils.dart';
import '../helpers/filter_utils.dart';
import '../helpers/responsive_helper.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  Widget _buildFilterChip(String value, String label, String currentFilter, WidgetRef ref, BuildContext context) {
    final isSelected = currentFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: ResponsiveHelper.sp(context, 14), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
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
    final t = ref.watch(currentAppThemeProvider);
    final allSessions = ref.watch(sessionsProvider);
    final filter = ref.watch(statsFilterProvider);
    final offset = ref.watch(statsOffsetProvider);
    final customRange = ref.watch(statsCustomRangeProvider);
    final catColors = ref.watch(categoryColorProvider);
    final visibleCats = ref.watch(visibleCategoriesProvider);
    final categoryFilter = ref.watch(statsCategoryFilterProvider);
    final taskGoals = ref.watch(taskGoalProvider);
    
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
    final Goal? binaryGoal = categoryFilter == null
        ? null
        : _findBinaryGoal(taskGoals, categoryFilter);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CartoonAppBar(title: '統計 📊'),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (filter == 'custom') return;
          const velocityThreshold = 500;
          if (details.primaryVelocity! < -velocityThreshold) {
            // Swipe Left -> Move Forward (Next Period)
            if (offset > 0) ref.read(statsOffsetProvider.notifier).setOffset(offset - 1);
          } else if (details.primaryVelocity! > velocityThreshold) {
            // Swipe Right -> Move Backward (Previous Period)
            ref.read(statsOffsetProvider.notifier).setOffset(offset + 1);
          }
        },
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Chips
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.ink.withOpacity(0.2), width: 2),
                ),
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
            Text(
              '時間分配',
              style: GoogleFonts.outfit(
                fontSize: ResponsiveHelper.sp(context, 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (categoryFilter != null && binaryGoal != null)
              _BinaryGoalCalendarCard(
                goal: binaryGoal,
                categoryColor: catColors[categoryFilter] ?? Theme.of(context).colorScheme.primary,
              )
            else if (totalSeconds == 0)
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
                    Text(
                      categoryFilter,
                      style: GoogleFonts.outfit(
                        fontSize: ResponsiveHelper.sp(context, 24),
                        fontWeight: FontWeight.bold,
                        color: catColors[categoryFilter],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        FormatUtils.formatDurationDetailed(totalSeconds),
                        style: GoogleFonts.shareTechMono(
                          fontSize: ResponsiveHelper.sp(context, 36),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '佔比 ${((totalSeconds / globalTotalTotal) * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: ResponsiveHelper.sp(context, 14),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                return;
                              }
                              final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              if (index < 0 || index >= categoryTotals.length) return;
                              
                              final entry = categoryTotals.entries.elementAt(index);
                              final categoryName = entry.key;
                              final seconds = entry.value;

                              // Show info on tap (not hover)
                              if (event is FlTapUpEvent) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Container(width: 12, height: 12, decoration: BoxDecoration(color: catColors[categoryName], shape: BoxShape.circle)),
                                        const SizedBox(width: 12),
                                        Text('$categoryName: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(FormatUtils.formatDurationDetailed(seconds)),
                                      ],
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                          ),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: categoryTotals.entries.map((e) {
                            final percentage = (e.value / totalSeconds) * 100;
                            return PieChartSectionData(
                              color: catColors[e.key] ?? Colors.grey,
                              value: e.value.toDouble(),
                              title: percentage > 12 ? '${percentage.toStringAsFixed(0)}%' : '',
                              radius: 62,
                              titleStyle: TextStyle(fontSize: ResponsiveHelper.sp(context, 12), fontWeight: FontWeight.bold, color: Colors.white),
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
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('合計　', style: TextStyle(fontSize: ResponsiveHelper.sp(context, 14), color: Colors.grey.shade600)),
                          Text(
                            FormatUtils.formatDurationDetailed(totalSeconds),
                            style: GoogleFonts.shareTechMono(
                              fontSize: ResponsiveHelper.sp(context, 18),
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
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
            Text('分類趨勢', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              filter == 'daily' || filter == 'custom' ? '近 14 天' :
              filter == 'weekly' ? '近 8 週' :
              filter == 'monthly' ? '近 12 個月' : '近 5 年',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            Container(
              height: 240,
              padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: () {
                final top5Colors = categoryFilter != null
                    ? catColors
                    : Map.fromEntries(
                        (categoryTotals.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                          .take(5)
                          .map((e) => MapEntry(e.key, catColors[e.key] ?? Colors.grey)),
                      );
                if (top5Colors.isEmpty) {
                  return Center(child: Text('此區段無紀錄', style: TextStyle(color: Colors.grey.shade400)));
                }
                return TrendLineChart(
                  sessions: allSessions,
                  filter: filter,
                  offset: offset,
                  catColors: top5Colors,
                  categoryFilter: categoryFilter,
                );
              }(),
            ),
            if (categoryFilter == null && categoryTotals.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: (categoryTotals.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(5)
                  .map((e) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: catColors[e.key] ?? Colors.grey, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(e.key, style: const TextStyle(fontSize: 12)),
                    ],
                  ))
                  .toList(),
              ),
            ],
            const SizedBox(height: 40),
            Text(
              '詳細項目',
              style: GoogleFonts.outfit(
                fontSize: ResponsiveHelper.sp(context, 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...categoryTotals.entries.map((e) {
              final color = catColors[e.key] ?? Colors.grey;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    // Show time info popup
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                             Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                             const SizedBox(width: 12),
                             Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                             Text(FormatUtils.formatDurationDetailed(e.value)),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );

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
                            Expanded(
                              child: Text(
                                e.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: ResponsiveHelper.sp(context, 18),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              FormatUtils.formatDuration(e.value),
                              style: GoogleFonts.shareTechMono(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: ResponsiveHelper.sp(context, 18),
                              ),
                            ),
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
    ),
    );
  }

  Goal? _findBinaryGoal(List<Goal> taskGoals, String category) {
    final matches = taskGoals
        .where((g) => g.category == category && g.type == GoalType.binary && g.isActive)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (matches.isEmpty) return null;
    return matches.first;
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

class _BinaryGoalCalendarCard extends ConsumerStatefulWidget {
  final Goal goal;
  final Color categoryColor;

  const _BinaryGoalCalendarCard({
    required this.goal,
    required this.categoryColor,
  });

  @override
  ConsumerState<_BinaryGoalCalendarCard> createState() => _BinaryGoalCalendarCardState();
}

class _BinaryGoalCalendarCardState extends ConsumerState<_BinaryGoalCalendarCard> {
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month, 1);
  }

  void _changeMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta, 1);
    });
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentGoal = ref.watch(taskGoalProvider).firstWhere(
          (g) => g.id == widget.goal.id,
          orElse: () => widget.goal,
        );
    final now = DateTime.now();
    final firstDayOfMonth = _viewMonth;
    final lastDayOfMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final leadingDays = firstDayOfMonth.weekday - 1;
    final completedDays = List.generate(lastDayOfMonth.day, (index) {
      final day = index + 1;
      final date = DateTime(_viewMonth.year, _viewMonth.month, day);
      final val = currentGoal.completionHistory[_dateKey(date)] ?? 0;
      return val > 0 ? 1 : 0;
    }).fold<int>(0, (sum, val) => sum + val);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.categoryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.categoryColor.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentGoal.category,
                      style: GoogleFonts.outfit(
                        fontSize: ResponsiveHelper.sp(context, 22),
                        fontWeight: FontWeight.bold,
                        color: widget.categoryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currentGoal.title} 的月曆完成狀態',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: ResponsiveHelper.sp(context, 13),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '$completedDays / ${lastDayOfMonth.day}',
                style: GoogleFonts.shareTechMono(
                  fontSize: ResponsiveHelper.sp(context, 18),
                  fontWeight: FontWeight.bold,
                  color: widget.categoryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _changeMonth(-1),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              Text(
                '${_viewMonth.year}年 ${_viewMonth.month}月',
                style: GoogleFonts.outfit(
                  fontSize: ResponsiveHelper.sp(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _viewMonth.year == now.year && _viewMonth.month == now.month ? null : () => _changeMonth(1),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const ['一', '二', '三', '四', '五', '六', '日']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final dayIndex = index - leadingDays;
              if (dayIndex < 0 || dayIndex >= lastDayOfMonth.day) {
                return const SizedBox.shrink();
              }

              final dayNum = dayIndex + 1;
              final date = DateTime(_viewMonth.year, _viewMonth.month, dayNum);
              final dateStr = _dateKey(date);
              final isCompleted = (currentGoal.completionHistory[dateStr] ?? 0) > 0;
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

              return Container(
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withOpacity(0.88)
                      : Colors.red.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: isToday ? Border.all(color: widget.categoryColor, width: 2) : null,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      right: 5,
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? Colors.white.withOpacity(0.75) : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        isCompleted ? Icons.check_rounded : Icons.close_rounded,
                        size: 20,
                        color: isCompleted ? Colors.white : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BinaryLegend(color: Colors.green, label: '已完成'),
              const SizedBox(width: 16),
              _BinaryLegend(color: Colors.redAccent, label: '未完成'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BinaryLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _BinaryLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
