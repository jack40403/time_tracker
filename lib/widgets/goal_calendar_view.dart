import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/goal.dart';
import '../providers/goal_provider.dart';
import '../providers/category_provider.dart';

class GoalCalendarView extends ConsumerStatefulWidget {
  final Goal goal;
  const GoalCalendarView({super.key, required this.goal});

  @override
  ConsumerState<GoalCalendarView> createState() => _GoalCalendarViewState();
}

class _GoalCalendarViewState extends ConsumerState<GoalCalendarView> {
  DateTime _focusedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday; // 1 (Mon) - 7 (Sun)
    
    final leadingEmptyCells = startWeekday - 1;
    
    final List<DateTime?> calendarCells = [];
    for (int i = 0; i < leadingEmptyCells; i++) {
        calendarCells.add(null);
    }
    for (int i = 1; i <= daysInMonth; i++) {
        calendarCells.add(DateTime(_focusedMonth.year, _focusedMonth.month, i));
    }
    while (calendarCells.length < 42) {
        calendarCells.add(null);
    }

    final catColor = ref.watch(categoryColorProvider)[widget.goal.category] ?? Colors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_focusedMonth.year}年 ${_focusedMonth.month}月',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.grey.shade900),
            ),
            Row(
              children: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_left_rounded, size: 28),
                  ),
                  onPressed: () => _changeMonth(-1),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right_rounded, size: 28),
                  ),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Weekday Headers - Minimalist
        Row(
          children: ['一', '二', '三', '四', '五', '六', '日'].map((w) => Expanded(
            child: Center(
              child: Text(
                w, 
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.bold, letterSpacing: 1.2)
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: calendarCells.length,
          itemBuilder: (context, index) {
            final day = calendarCells[index];
            if (day == null) return const SizedBox.shrink();

             final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
             final val = widget.goal.completionHistory[dateStr];
             // Color reflects if goal achieved AS OF THIS DAY
             final isCompleted = ref.read(goalProvider.notifier).getProgress(widget.goal, atDate: day) >= 1.0;
            final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
            final isFuture = day.isAfter(now);
            final isBeforeStart = day.isBefore(DateTime(widget.goal.startDate.year, widget.goal.startDate.month, widget.goal.startDate.day));

            final statusColor = isCompleted ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
            final statusIcon = isCompleted ? Icons.check_rounded : Icons.close_rounded;

            return InkWell(
              onTap: (isFuture || isBeforeStart) ? null : () {
                if (widget.goal.type == GoalType.task) {
                   _showManualCountDialog(context, ref, day);
                } else {
                   ref.read(goalProvider.notifier).toggleManualCompletion(widget.goal.id, day);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: (isFuture || isBeforeStart) ? Colors.grey.shade100 : statusColor,
                  border: isToday 
                      ? Border.all(color: Colors.black, width: 2.5) 
                      : null,
                  boxShadow: [
                    if (!isFuture && !isBeforeStart) BoxShadow(color: statusColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}', 
                            style: GoogleFonts.outfit(
                              fontSize: 26, 
                              color: (isFuture || isBeforeStart) ? Colors.grey.shade300 : Colors.white,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                if (!isFuture && !isBeforeStart) const Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 3),
                              ],
                            )
                          ),
                          if (val != null && val > 0 && !isFuture && !isBeforeStart)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatValue(val, widget.goal.type),
                                  style: GoogleFonts.outfit(
                                    fontSize: _getRelativeFontSize(val, widget.goal),
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isFuture && !isBeforeStart)
                      Positioned(
                        right: 4, bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                          child: Icon(statusIcon, color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        // Legend or minimal hint
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: catColor.withOpacity(0.8), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('完成日', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(width: 16),
            Container(width: 8, height: 8, decoration: BoxDecoration(border: Border.all(color: catColor, width: 1.5), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('今天', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }

  double _getRelativeFontSize(int val, Goal goal) {
    return 12.0;
  }

  String _formatValue(int val, GoalType type) {
    if (type == GoalType.task) return '${val} 單位';
    
    final h = val ~/ 3600;
    final m = (val % 3600) ~/ 60;
    final s = val % 60;

    // Use HH:MM:SS for precision as requested
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showManualCountDialog(BuildContext context, WidgetRef ref, DateTime targetDate) {
    final goal = widget.goal;
    final dateStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    final initialCount = goal.completionHistory[dateStr] ?? 0;
    final controller = TextEditingController(text: initialCount.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('修正歷史紀錄', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            Text('${targetDate.year}/${targetDate.month}/${targetDate.day}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('當前項目: ${goal.category}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              goal.type == GoalType.time ? '(請輸入總計秒數)' : '(請輸入完成單位數)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final count = int.tryParse(controller.text) ?? 0;
              ref.read(goalProvider.notifier).setManualValue(goal.id, targetDate, count);
              Navigator.pop(ctx);
            },
            child: const Text('確認變更'),
          ),
        ],
      ),
    );
  }
}
