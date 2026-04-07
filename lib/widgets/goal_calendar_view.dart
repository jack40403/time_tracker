import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 修正：移至頂部
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/goal.dart';
import '../providers/goal_provider.dart';
import '../providers/task_goal_provider.dart';
import '../providers/category_provider.dart';

class GoalCalendarView extends StatefulWidget {
  final Goal goal;
  const GoalCalendarView({super.key, required this.goal});

  @override
  State<GoalCalendarView> createState() => _GoalCalendarViewState();
}

class _GoalCalendarViewState extends State<GoalCalendarView> {
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _changeMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta, 1);
    });
  }

  String _formatVal(int val, GoalType type) {
    if (type == GoalType.time) {
      if (val <= 0) return '-';
      final h = val ~/ 3600;
      final m = (val % 3600) ~/ 60;
      if (h > 0) return '${h}h${m}m';
      return '${m}m';
    }
    return val > 0 ? '✓' : '✗';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (ctx, ref, _) {
        // 關鍵修正：從 Provider 中監聽最新的目標數據，而不是依賴外部傳入的靜態 Snapshot
        final Goal currentGoal;
        if (widget.goal.type == GoalType.time) {
          final goals = ref.watch(goalProvider);
          currentGoal = goals.firstWhere((g) => g.id == widget.goal.id, orElse: () => widget.goal);
        } else {
          final taskGoals = ref.watch(taskGoalProvider);
          currentGoal = taskGoals.firstWhere((g) => g.id == widget.goal.id, orElse: () => widget.goal);
        }

        final catColor = ref.watch(categoryColorProvider)[currentGoal.category] ?? Colors.blue;
        final now = DateTime.now();
        final firstDayOfMonth = _viewMonth;
        final lastDayOfMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
        
        final int leadingDays = firstDayOfMonth.weekday - 1;
        final totalCells = leadingDays + lastDayOfMonth.day;
        final rows = (totalCells / 7).ceil();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () => _changeMonth(-1), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                    const SizedBox(width: 8),
                    Text('${_viewMonth.year}年 ${_viewMonth.month}月', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () => _changeMonth(1), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                  ],
                ),
                Text('點擊格子可修改紀錄', style: TextStyle(fontSize: 10, color: catColor.withOpacity(0.8), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['一', '二', '三', '四', '五', '六', '日'].map((w) => Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))))).toList(),
            ),
            const SizedBox(height: 8),
            for (int r = 0; r < rows; r++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: List.generate(7, (c) {
                    final dayIdx = r * 7 + c - leadingDays + 1;
                    final bool isCurrentMonth = dayIdx >= 1 && dayIdx <= lastDayOfMonth.day;
                    
                    if (!isCurrentMonth) return const Expanded(child: SizedBox());

                    final date = DateTime(_viewMonth.year, _viewMonth.month, dayIdx);
                    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    // 使用當前從 Provider 獲取的目標數據
                    final val = currentGoal.completionHistory[dateKey] ?? 0;
                    final bool isToday = date.day == now.day && date.month == now.month && date.year == now.year;
                    
                    bool isSuccess = false;
                    if (currentGoal.type == GoalType.binary) {
                      isSuccess = val >= 1;
                    } else {
                      isSuccess = val >= currentGoal.targetSeconds;
                    }

                    Color cellColor = Colors.grey.withOpacity(0.07);
                    if (val > 0) {
                      if (currentGoal.type == GoalType.time) {
                        cellColor = isSuccess 
                            ? Colors.green.withOpacity((val / currentGoal.targetSeconds).clamp(0.5, 1.0))
                            : Colors.red.withOpacity(0.55);
                      } else {
                        cellColor = isSuccess ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.55);
                      }
                    }

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: Material(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(8),
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: isToday ? BorderSide(color: catColor, width: 2) : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: currentGoal.type == GoalType.time 
                                ? null  // 時間型禁止手動編輯
                                : () {
                                    HapticFeedback.mediumImpact();
                                    if (currentGoal.type == GoalType.binary) {
                                      ref.read(taskGoalProvider.notifier).toggleManualCompletion(currentGoal.id, date);
                                    } else {
                                      _showEditValueDialog(context, ref, date, val, currentGoal);
                                    }
                                  },
                            child: SizedBox(
                              height: 52,
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 3, 
                                    right: 4, 
                                    child: IgnorePointer(
                                      child: Text('$dayIdx', style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                    ),
                                  ),
                                  Center(
                                    child: IgnorePointer(
                                      child: Text(
                                        _formatVal(val, currentGoal.type),
                                        style: GoogleFonts.shareTechMono(
                                          fontSize: currentGoal.type == GoalType.time ? 13 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: val > 0 ? (currentGoal.type == GoalType.time ? Colors.black87 : Colors.white) : Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showEditValueDialog(BuildContext context, WidgetRef ref, DateTime date, int currentVal, Goal latestGoal) {
    final controller = TextEditingController(text: latestGoal.type == GoalType.time ? (currentVal ~/ 60).toString() : currentVal.toString());
    final dateStr = '${date.year}/${date.month}/${date.day}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$dateStr 數據修改'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (latestGoal.type == GoalType.binary)
              const Text('點擊下方按鈕切換達成狀態：')
            else
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: latestGoal.type == GoalType.time ? '輸入分鐘數' : '輸入完成單位',
                  border: const OutlineInputBorder(),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          if (latestGoal.type == GoalType.binary)
             ElevatedButton(
               onPressed: () {
                 ref.read(taskGoalProvider.notifier).toggleManualCompletion(latestGoal.id, date);
                 Navigator.pop(ctx);
               },
               child: Text(currentVal > 0 ? '標記為未達成' : '標記為已達成'),
             )
          else
            ElevatedButton(
              onPressed: () {
                final input = int.tryParse(controller.text) ?? 0;
                final finalVal = latestGoal.type == GoalType.time ? input * 60 : input;
                if (latestGoal.type == GoalType.time) {
                  ref.read(goalProvider.notifier).setManualValue(latestGoal.id, date, finalVal);
                } else {
                  ref.read(taskGoalProvider.notifier).setManualValue(latestGoal.id, date, finalVal);
                }
                Navigator.pop(ctx);
              },
              child: const Text('儲存修改'),
            ),
        ],
      ),
    );
  }
}
