import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/goal.dart';
import '../models/time_session.dart';
import '../theme/cartoon_theme.dart';
import '../providers/session_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/task_goal_provider.dart';
import '../providers/category_provider.dart';
import '../helpers/goal_calendar_utils.dart';
import '../providers/ui_providers.dart';
import '../widgets/day_timeline_chart.dart';
import '../widgets/elite_date_range_picker.dart';
import '../helpers/filter_utils.dart';
import '../helpers/responsive_helper.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  bool _showHeatmap = true;
  String _formatTime(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hrs > 0) return '${hrs}h ${mins}m ${secs}s';
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }

  void _showManualAddDialog() {
    final visibleCategories = ref.read(historySelectableCategoriesProvider);
    final catColors = ref.read(categoryColorProvider);
    if (visibleCategories.isEmpty) return;

    String selectedCategory = visibleCategories.first;
    DateTime selectedDate = DateTime.now();
    TimeOfDay endTime = TimeOfDay.now();
    // Default start time to 1 hour ago
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    TimeOfDay startTime = TimeOfDay(hour: oneHourAgo.hour, minute: oneHourAgo.minute);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 28, right: 28, top: 28,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '手動新增紀錄',
                  style: GoogleFonts.outfit(
                    fontSize: ResponsiveHelper.sp(context, 24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                    
                    // Category
                    Text('選擇分類', style: TextStyle(fontSize: ResponsiveHelper.sp(context, 14), color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          items: visibleCategories.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Row(children: [
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: catColors[c] ?? Colors.grey, shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Text(c, style: const TextStyle(fontSize: 16)),
                              ]),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => selectedCategory = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date
                    Text('選擇日期', style: TextStyle(fontSize: ResponsiveHelper.sp(context, 14), color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setModalState(() => selectedDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 10),
                          Text('${selectedDate.year}/${selectedDate.month}/${selectedDate.day}', style: const TextStyle(fontSize: 16)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Times
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('開始時間', style: TextStyle(fontSize: ResponsiveHelper.sp(context, 14), color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () async {
                              final t = await showTimePicker(context: context, initialTime: startTime);
                              if (t != null) setModalState(() => startTime = t);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).colorScheme.outline),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(children: [
                                const Icon(Icons.access_time_outlined, size: 18),
                                const SizedBox(width: 10),
                                Text(startTime.format(context), style: const TextStyle(fontSize: 16)),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('結束時間', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () async {
                              final t = await showTimePicker(context: context, initialTime: endTime);
                              if (t != null) setModalState(() => endTime = t);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).colorScheme.outline),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(children: [
                                const Icon(Icons.access_time_filled_outlined, size: 18),
                                const SizedBox(width: 10),
                                Text(endTime.format(context), style: const TextStyle(fontSize: 16)),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消', style: TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            final startDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime.hour, startTime.minute);
                            final endDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime.hour, endTime.minute);
                            
                            if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('錯誤：結束時間必須晚於開始時間'), 
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(milliseconds: 1500),
                              ));
                              return;
                            }

                            final duration = endDt.difference(startDt).inSeconds;
                            ref.read(sessionsProvider.notifier).addSession(
                              TimeSession(
                                category: selectedCategory,
                                durationSeconds: duration,
                                date: startDt,
                              )
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('已成功新增紀錄', style: TextStyle(fontSize: 18)), 
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(milliseconds: 1500),
                            ));
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('新增紀錄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final allSessions = ref.watch(sessionsProvider);
    final catColors = ref.watch(categoryColorProvider);
    final visibleCats = ref.watch(historyVisibleCategoriesProvider);
    final filter = ref.watch(historyFilterProvider);
    final offset = ref.watch(historyOffsetProvider);
    final customRange = ref.watch(historyCustomRangeProvider);
    final goals = ref.watch(visibleTimeGoalsProvider);
    final taskGoals = ref.watch(visibleTaskGoalsProvider);
    final categoryFilter = ref.watch(historyCategoryFilterProvider);
    final timerState = ref.watch(timerProvider);

    var filteredSessions = FilterUtils.getFilteredSessions(allSessions, filter, offset, customRange);

    final visibleSet = visibleCats.toSet();
    final effectiveCategoryFilter = categoryFilter != null && visibleSet.contains(categoryFilter)
        ? categoryFilter
        : null;

    // Apply category filter only when the selected category is still visible here.
    if (effectiveCategoryFilter != null) {
      filteredSessions = filteredSessions.where((s) => s.category == effectiveCategoryFilter).toList();
    }

    filteredSessions = filteredSessions.where((s) => visibleSet.contains(s.category)).toList();

    final Map<String, List<dynamic>> grouped = {};
    for (var s in filteredSessions) {
      final dateKey = '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(dateKey, () => []).add(s);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: CartoonAppBar(
        title: '歷史紀錄 📅',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
            child: FilledButton.tonalIcon(
              onPressed: _showManualAddDialog,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('手動新增', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (filter == 'custom') return;
          const velocityThreshold = 500;
          if (details.primaryVelocity! < -velocityThreshold) {
            // Swipe Left -> Move Forward (Next Period)
            if (offset > 0) ref.read(historyOffsetProvider.notifier).setOffset(offset - 1);
          } else if (details.primaryVelocity! > velocityThreshold) {
            // Swipe Right -> Move Backward (Previous Period)
            ref.read(historyOffsetProvider.notifier).setOffset(offset + 1);
          }
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const SizedBox(height: 16),
          // Filter Chips
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface, 
                  borderRadius: BorderRadius.circular(16)
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterChip('daily', '每日', filter, ref),
                    _buildFilterChip('weekly', '每週', filter, ref),
                    _buildFilterChip('monthly', '每月', filter, ref),
                    _buildFilterChip('yearly', '每年', filter, ref),
                    _buildFilterChip('custom', '自定義 📅', filter, ref),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Time Machine
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (filter != 'custom')
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => ref.read(historyOffsetProvider.notifier).setOffset(offset + 1)),
              InkWell(
                onTap: filter == 'custom' ? () async {
                  final range = await EliteDateRangePicker.show(
                    context,
                    initialDateRange: customRange,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (range != null) {
                    ref.read(historyCustomRangeProvider.notifier).setRange(range);
                  }
                } : null,
                child: Row(
                  children: [
                    Text(FilterUtils.getFilterLabel(filter, offset, customRange), style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (filter == 'custom') ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_calendar_outlined, size: 16, color: Colors.blue),
                    ],
                  ],
                ),
              ),
              if (filter != 'custom')
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: offset > 0 ? () => ref.read(historyOffsetProvider.notifier).setOffset(offset - 1) : null),
            ],
          ),
          const SizedBox(height: 12),
          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildCategoryChip(null, '全部', effectiveCategoryFilter == null, ref),
                ...visibleCats.map((cat) => _buildCategoryChip(cat, cat, effectiveCategoryFilter == cat, ref)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(() => _showHeatmap = !_showHeatmap),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_graph, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(_showHeatmap ? '隱藏達成概覽' : '顯示達成概覽', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                        Icon(_showHeatmap ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                ),
                if (_showHeatmap) ...[
                  const SizedBox(height: 8),
                _buildGoalHeatmapSection(ref, filter, offset, customRange, goals, taskGoals, catColors, effectiveCategoryFilter),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (sortedDates.isEmpty)
            SizedBox(
              height: 200,
              child: Center(child: Text('沒有紀錄', style: TextStyle(color: Colors.grey.shade400))),
            )
          else
            ...sortedDates.map((date) {
              final dateSessions = grouped[date]!;
              final isToday = date == '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
              final int liveSeconds = isToday && timerState.isRunning ? timerState.currentElapsed : 0;
              final int dailyTotal = dateSessions.whereType<TimeSession>().fold(0, (sum, s) => sum + s.durationSeconds) + liveSeconds;
              final liveStart = timerState.sessionStartTime?.toLocal() ?? timerState.startTime?.toLocal();
              final chartShowsLive = isToday &&
                  timerState.isRunning &&
                  liveStart != null &&
                  liveStart.year == DateTime.now().year &&
                  liveStart.month == DateTime.now().month &&
                  liveStart.day == DateTime.now().day;
              final chartSessions = chartShowsLive
                  ? [
                      ...allSessions,
                      TimeSession(
                        category: timerState.category,
                        durationSeconds: timerState.currentElapsed,
                        date: timerState.sessionStartTime?.toLocal() ?? timerState.startTime?.toLocal() ?? DateTime.now(),
                      ),
                    ]
                  : allSessions;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('總計 ${_formatTime(dailyTotal)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    DayTimelineChart(
                      sessions: chartSessions,
                      catColors: catColors,
                      targetDay: DateTime.parse(date),
                    ),
                    const SizedBox(height: 12),
                    ...dateSessions.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final color = catColors[s.category] ?? Colors.grey;
                      return Dismissible(
                        key: ValueKey('session_${s.category}_${s.date.millisecondsSinceEpoch}_${s.durationSeconds}_$i'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          final deletedSession = s;
                          ref.read(sessionsProvider.notifier).deleteSession(s);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('已刪除紀錄'),
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: '復原',
                              onPressed: () {
                                ref.read(sessionsProvider.notifier).addSession(deletedSession);
                              },
                            ),
                          ));
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        child: InkWell(
                          onTap: () => _showEditSessionDialog(s),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                                          Builder(builder: (context) {
                                            final end = s.date.add(Duration(seconds: s.durationSeconds));
                                            final start = '${s.date.hour.toString().padLeft(2, '0')}:${s.date.minute.toString().padLeft(2, '0')}';
                                            final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
                                            return Text('$start → $endStr', style: const TextStyle(fontSize: 15, color: Colors.grey));
                                          }),
                                        ],
                                      ),
                                    ),
                                    Text(_formatTime(s.durationSeconds), style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 18)),
                                  ],
                                ),
                                if (s.note != null && s.note!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                                    child: Text(s.note!, style: const TextStyle(fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    ),
    );
  }

  void _showEditSessionDialog(TimeSession session) {
    final catColors = ref.read(categoryColorProvider);
    final visibleCategories = ref.read(historySelectableCategoriesProvider);
    String selectedCategory = session.category;
    DateTime selectedDate = DateTime(session.date.year, session.date.month, session.date.day);
    TimeOfDay startTime = TimeOfDay(hour: session.date.hour, minute: session.date.minute);
    final hoursController = TextEditingController(text: (session.durationSeconds ~/ 3600).toString());
    final minutesController = TextEditingController(text: ((session.durationSeconds % 3600) ~/ 60).toString());
    final secondsController = TextEditingController(text: (session.durationSeconds % 60).toString());
    final noteController = TextEditingController(text: session.note ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('編輯紀錄 / 日誌', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分類
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: '分類'),
                  items: visibleCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setModalState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 20),

                // 日期
                const Text('日期', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setModalState(() => selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text('${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // 起始時間
                const Text('起始時間', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: startTime);
                    if (t != null) setModalState(() => startTime = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(startTime.format(ctx), style: const TextStyle(fontSize: 16)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // 時間長度
                const Text('時間長度', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: TextField(controller: hoursController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '時', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: minutesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '分', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: secondsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '秒', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 20),

                // 備註
                TextField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '專注紀錄 / 日誌備註',
                    hintText: '記下這段時間做了什麼或心得...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final h = int.tryParse(hoursController.text) ?? 0;
                final m = int.tryParse(minutesController.text) ?? 0;
                final s = int.tryParse(secondsController.text) ?? 0;
                final newDuration = h * 3600 + m * 60 + s;
                if (newDuration <= 0) return;

                final newDate = DateTime(
                  selectedDate.year, selectedDate.month, selectedDate.day,
                  startTime.hour, startTime.minute,
                );
                final updated = TimeSession(
                  id: session.id,
                  category: selectedCategory,
                  durationSeconds: newDuration,
                  date: newDate,
                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                );
                await ref.read(sessionsProvider.notifier).updateSession(updated);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('紀錄已更新')));
              },
              child: const Text('確認修改'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, String currentFilter, WidgetRef ref) {
    final isSelected = value == currentFilter;
    return GestureDetector(
      onTap: () async {
        ref.read(historyFilterProvider.notifier).setFilter(value);
        if (value == 'custom') {
          final range = await EliteDateRangePicker.show(
            context,
            initialDateRange: ref.read(historyCustomRangeProvider),
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (range != null) {
            ref.read(historyCustomRangeProvider.notifier).setRange(range);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String? value, String label, bool isSelected, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => ref.read(historyCategoryFilterProvider.notifier).setCategory(value),
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

  Widget _buildGoalHeatmapSection(
    WidgetRef ref,
    String filter,
    int offset,
    DateTimeRange? customRange,
    List<Goal> timeGoals,
    List<Goal> taskGoals,
    Map<String, Color> catColors,
    String? categoryFilter,
  ) {
    if (filter == 'daily') return const SizedBox.shrink();

    final allGoals = [...timeGoals, ...taskGoals];
    final displayGoals = allGoals.where((g) => categoryFilter == null || g.category == categoryFilter).toList();
    if (displayGoals.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    List<DateTime> datesToShow = [];
    String title = "";

    if (filter == 'weekly') {
      final targetDate = now.subtract(Duration(days: offset * 7));
      final mon = targetDate.subtract(Duration(days: targetDate.weekday - 1));
      datesToShow = List.generate(7, (i) => DateTime(mon.year, mon.month, mon.day + i));
      title = "本週達成概覽";
    } else if (filter == 'monthly') {
      final targetMonth = DateTime(now.year, now.month - offset, 1);
      final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
      datesToShow = List.generate(lastDay, (i) => DateTime(targetMonth.year, targetMonth.month, i + 1));
      title = "本月達成概覽";
    } else if (filter == 'yearly') {
       // 每年模式 (暫不變動)
       final targetYear = now.year - offset;
       return _buildYearlyHeatmap(targetYear);
    } else {
      return const SizedBox.shrink();
    }

    // 關鍵修正：絕斷式隔離顯示
    if (categoryFilter == null) {
      // 模式 A：只有點選「全部」標籤時，才顯示多列橫條概覽
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: displayGoals.map((g) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 80, child: Text(g.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      ...datesToShow.map((d) {
                        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        final val = g.completionHistory[key] ?? 0;
                        final bool periodAchieved = GoalCalendarUtils.isPeriodGoalAchievedOnDate(g, d);
                        final bool isSuccess = g.period == GoalPeriod.daily
                            ? (g.type == GoalType.binary ? val >= 1 : val >= g.targetSeconds)
                            : periodAchieved;
                        return Container(
                          width: filter == 'weekly' ? 30 : 12,
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: periodAchieved ? Colors.green.withOpacity(0.72) : (val == 0 ? Colors.grey.withOpacity(0.1) : (isSuccess ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.5))),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
        ],
      );
    } else {
      // 模式 B：點選「個別項目」時，只顯示該項目的 7 欄大月曆格子
      // 過濾出當前選取的那個目標
      final g = displayGoals.firstWhere((goal) => goal.category == categoryFilter, orElse: () => displayGoals.first);
      final color = catColors[g.category] ?? Colors.blue;
      int leadingSpaces = (filter == 'monthly') ? (datesToShow.first.weekday - 1) : 0;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 6, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 12),
                Text('${g.title} - $title', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.0,
              ),
              itemCount: datesToShow.length + leadingSpaces,
              itemBuilder: (ctx, idx) {
                if (idx < leadingSpaces) return const SizedBox();
                final date = datesToShow[idx - leadingSpaces];
                final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final val = g.completionHistory[key] ?? 0;
                final bool periodAchieved = GoalCalendarUtils.isPeriodGoalAchievedOnDate(g, date);
                final isSuccess = g.period == GoalPeriod.daily
                    ? (g.type == GoalType.binary ? val >= 1 : val >= g.targetSeconds)
                    : periodAchieved;
                final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                
                return Container(
                  decoration: BoxDecoration(
                    color: periodAchieved ? Colors.green.withOpacity(0.72) : (val == 0 ? Colors.grey.withOpacity(0.04) : (isSuccess ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.5))),
                    borderRadius: BorderRadius.circular(8),
                    border: (isToday ? Border.all(color: color, width: 2.5) : Border.all(color: Colors.black.withOpacity(0.05))) as BoxBorder,
                    boxShadow: val > 0 ? [BoxShadow(color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}', 
                      style: GoogleFonts.outfit(
                        fontSize: 18, 
                        fontWeight: FontWeight.w900, 
                        color: val == 0 ? Colors.grey.shade400 : Colors.white,
                        letterSpacing: -1.0,
                      )
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildYearlyHeatmap(int targetYear) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("年度月度概覽", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: List.generate(12, (m) {
            final month = m + 1;
            return Container(
              width: 45, height: 45,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
              child: Center(child: Text("${month}月", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            );
          }),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  bool _isDateInRange(DateTime d, String filter, int offset, DateTimeRange? customRange) {
    if (filter == 'custom' && customRange != null) {
      final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
      final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
      return d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end.add(const Duration(seconds: 1)));
    }
    
    final now = DateTime.now();
    if (filter == 'daily') {
      final target = now.subtract(Duration(days: offset));
      return d.year == target.year && d.month == target.month && d.day == target.day;
    } else if (filter == 'weekly') {
      final targetDate = now.subtract(Duration(days: offset * 7));
      final mon = targetDate.subtract(Duration(days: targetDate.weekday - 1));
      final sun = mon.add(const Duration(days: 6));
      final start = DateTime(mon.year, mon.month, mon.day);
      final end = DateTime(sun.year, sun.month, sun.day, 23, 59, 59);
      return d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end.add(const Duration(seconds: 1)));
    } else if (filter == 'monthly') {
      final targetMonth = DateTime(now.year, now.month - offset);
      return d.year == targetMonth.year && d.month == targetMonth.month;
    } else if (filter == 'yearly') {
      final targetYear = now.year - offset;
      return d.year == targetYear;
    }
    return true;
  }
}
