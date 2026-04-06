import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/goal.dart';
import '../providers/goal_provider.dart';

class GoalCalendarDialog extends ConsumerWidget {
  final Goal goal;
  final Color categoryColor;

  const GoalCalendarDialog({
    super.key,
    required this.goal,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday; // 1 (Mon) to 7 (Sun)

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${now.year}年 ${now.month}月',
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${goal.category} 達成紀錄',
                      style: TextStyle(color: categoryColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Weekdays header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['一', '二', '三', '四', '五', '六', '日'].map((d) => 
                Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))))
              ).toList(),
            ),
            const SizedBox(height: 12),
            // Calendar Grid
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 42, // Max 6 rows
                itemBuilder: (context, index) {
                  final dayIndex = index - (startWeekday - 1);
                  if (dayIndex < 0 || dayIndex >= daysInMonth) {
                    return const SizedBox();
                  }

                  final dayNum = dayIndex + 1;
                  final date = DateTime(now.year, now.month, dayNum);
                  final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  final isCompleted = (goal.completionHistory[dateStr] ?? 0) > 0;
                  final isToday = dayNum == now.day;

                  return GestureDetector(
                    onTap: () {
                        // Allow toggling for ANY day in the current month in the history view
                        ref.read(goalProvider.notifier).toggleManualCompletion(goal.id, date);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCompleted ? categoryColor.withOpacity(0.9) : (isToday ? categoryColor.withOpacity(0.1) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                        border: isToday ? Border.all(color: categoryColor, width: 2) : null,
                      ),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dayNum.toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: (isToday || isCompleted) ? FontWeight.bold : FontWeight.normal,
                                    color: isCompleted ? Colors.white.withOpacity(0.7) : (isToday ? categoryColor : Colors.black38),
                                  ),
                                ),
                                if (isCompleted) ...[
                                  Text(
                                    goal.type == GoalType.time 
                                      ? '${(goal.completionHistory[dateStr]! / 60).round()}m'
                                      : '${goal.completionHistory[dateStr]}x',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      fontSize: 12 + ( (goal.completionHistory[dateStr]! / (goal.type == GoalType.time ? 60 : 1)).clamp(1, 100) / 10 ).clamp(0, 10),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (isCompleted && false) // Hidden check icon to give space
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Icon(Icons.check, size: 10, color: Colors.white.withOpacity(0.8)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(categoryColor, '已達成'),
                const SizedBox(width: 20),
                _buildLegendItem(Colors.grey.shade200, '未達成'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
