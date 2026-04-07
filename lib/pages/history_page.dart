import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/time_session.dart';
import '../providers/session_provider.dart';
import '../providers/category_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/day_timeline_chart.dart';
import '../widgets/elite_date_range_picker.dart';
import '../helpers/filter_utils.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _formatTime(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hrs > 0) return '${hrs}h ${mins}m ${secs}s';
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }

  void _showManualAddDialog() {
    final catColors = ref.read(categoryColorProvider);
    if (catColors.isEmpty) return;

    String selectedCategory = catColors.keys.first;
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime = TimeOfDay(hour: (startTime.hour + 1) % 24, minute: startTime.minute);

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
                Text('手動新增紀錄', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                    
                    // Category
                    Text('選擇分類', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
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
                          items: catColors.keys.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Row(children: [
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: catColors[c], shape: BoxShape.circle)),
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
                    Text('選擇日期', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
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
                          Text('開始時間', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
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
    final visibleCats = ref.watch(visibleCategoriesProvider);
    final filter = ref.watch(historyFilterProvider);
    final offset = ref.watch(historyOffsetProvider);
    final customRange = ref.watch(historyCustomRangeProvider);
    final categoryFilter = ref.watch(historyCategoryFilterProvider);

    var filteredSessions = FilterUtils.getFilteredSessions(allSessions, filter, offset, customRange);
    
    // Apply category filter
    if (categoryFilter != null) {
      filteredSessions = filteredSessions.where((s) => s.category == categoryFilter).toList();
    }

    final Map<String, List<TimeSession>> grouped = {};
    for (var s in filteredSessions) {
      final dateKey = '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(dateKey, () => []).add(s);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text('歷史紀錄', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        child: Column(
          children: [
          const SizedBox(height: 16),
          // Filter Chips
          Center(
            child: Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
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
                _buildCategoryChip(null, '全部', categoryFilter == null, ref),
                ...visibleCats.map((cat) => _buildCategoryChip(cat, cat, categoryFilter == cat, ref)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: sortedDates.isEmpty
                ? Center(child: Text('沒有紀錄', style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, idx) {
                      final date = sortedDates[idx];
                      final dateSessions = grouped[date]!;
                      final dailyTotal = dateSessions.fold(0, (sum, s) => sum + s.durationSeconds);
                      return Column(
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
                            sessions: allSessions,
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
                                  content: Text('已刪除紀錄'),
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
                                                  Text('${s.date.hour.toString().padLeft(2, '0')}:${s.date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 15, color: Colors.grey)),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    );
  }

  void _showEditSessionDialog(TimeSession session) {
    final catColors = ref.read(categoryColorProvider);
    String selectedCategory = session.category;
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
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: '分類'),
                  items: catColors.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setModalState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: TextField(controller: hoursController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '時'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: minutesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '分'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: secondsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '秒'))),
                  ],
                ),
                const SizedBox(height: 20),
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
              onPressed: () {
                final h = int.tryParse(hoursController.text) ?? 0;
                final m = int.tryParse(minutesController.text) ?? 0;
                final s = int.tryParse(secondsController.text) ?? 0;
                final newDuration = h * 3600 + m * 60 + s;
                
                if (newDuration <= 0) return;

                final updated = session.copyWith(
                  category: selectedCategory,
                  durationSeconds: newDuration,
                  note: noteController.text.trim(),
                );
                
                ref.read(sessionsProvider.notifier).updateSession(updated);
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
}
