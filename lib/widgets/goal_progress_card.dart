import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/goal.dart';
import '../models/time_session.dart';
import '../providers/goal_provider.dart';
import '../providers/task_goal_provider.dart';
import '../providers/category_provider.dart';
import '../providers/session_provider.dart';
import 'goal_calendar_view.dart';

class GoalProgressCard extends ConsumerStatefulWidget {
  final Goal goal;
  final Function(Goal)? onEdit;
  final Function(Goal)? onDelete;
  const GoalProgressCard({super.key, required this.goal, this.onEdit, this.onDelete});

  @override
  ConsumerState<GoalProgressCard> createState() => _GoalProgressCardState();
}

class _GoalProgressCardState extends ConsumerState<GoalProgressCard> {
  bool _isExpanded = false;

  String _formatTime(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hrs > 0) return '${hrs}h ${mins}m';
    return '${mins}m';
  }

  String _formatDate(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final isTaskMode = goal.type != GoalType.time;
    
    final progress = isTaskMode 
        ? ref.watch(taskGoalProvider.notifier).getProgress(goal)
        : ref.watch(goalProvider.notifier).getProgress(goal);
        
    final remainingText = isTaskMode 
        ? ref.watch(taskGoalProvider.notifier).getRemainingText(goal)
        : ref.watch(goalProvider.notifier).getRemainingText(goal);

    final catColor = ref.watch(categoryColorProvider)[goal.category] ?? Colors.blue;
    final isAchieved = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 12)),
          BoxShadow(color: catColor.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: -0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (goal.title != goal.category)
                      Text(goal.category, style: TextStyle(fontSize: 13, color: catColor, fontWeight: FontWeight.w500)),
                    Text(
                      '始於 ${_formatDate(goal.startDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              if (isTaskMode)
                IconButton(
                  onPressed: () {
                    if (goal.type == GoalType.binary) {
                      ref.read(taskGoalProvider.notifier).toggleManualCompletion(goal.id, DateTime.now());
                    } else {
                      _showManualCountDialog(context, ref);
                    }
                  },
                  icon: Icon(isAchieved ? Icons.check_circle : Icons.add_circle_outline, color: isAchieved ? Colors.green : catColor, size: 28),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: catColor.withOpacity(0.12), borderRadius: BorderRadius.circular(22)),
                child: Text(
                  goal.period == GoalPeriod.daily ? '每日' : goal.period == GoalPeriod.weekly ? '每週' : '每月',
                  style: TextStyle(fontSize: 18, color: catColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.type == GoalType.time 
                  ? '本期目標: ${_formatTime(goal.targetSeconds)}' 
                  : (goal.type == GoalType.binary ? '是否達成？' : '目標完成數: ${goal.targetSeconds}'),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Text('${(progress * 100).toInt()}%', style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 34, color: isAchieved ? Colors.green : catColor)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(isAchieved ? Colors.green : catColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (goal.type == GoalType.binary) {
                    ref.read(taskGoalProvider.notifier).toggleManualCompletion(goal.id, DateTime.now());
                  } else if (goal.type == GoalType.task) {
                    _showManualCountDialog(context, ref);
                  } else {
                    _showAddTimeDialog(context, ref);
                  }
                },
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: catColor.withOpacity(0.15),
                  child: Icon(
                    goal.type == GoalType.time 
                      ? Icons.add 
                      : (progress >= 1.0 ? Icons.check_box : Icons.check_box_outline_blank), 
                    color: catColor, 
                    size: 26
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Achievements Section
          _buildAchievementSection(context, ref, goal, catColor),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(remainingText, style: TextStyle(fontSize: 17, color: isAchieved ? Colors.green : Colors.grey.shade600, fontWeight: FontWeight.bold))),
              Row(
                children: [
                  // 時間型：手動更新歷史按鈕
                  if (goal.type == GoalType.time)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.teal, size: 24),
                      tooltip: '重新抴取歷史計時紀錄',
                      onPressed: () {
                        ref.read(goalProvider.notifier).recalculateHistoryFromSessions(goal.id);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('已重新從計時紀錄更新目標歷史 📊'),
                          backgroundColor: Colors.teal,
                          behavior: SnackBarBehavior.floating,
                        ));
                      },
                    ),
                  IconButton(icon: Icon(_isExpanded ? Icons.calendar_month : Icons.calendar_month_outlined, color: Colors.indigo, size: 28), onPressed: () => setState(() => _isExpanded = !_isExpanded)),
                  IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 24), onPressed: () => widget.onEdit?.call(goal), tooltip: '編輯目標'),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24), onPressed: () => widget.onDelete?.call(goal), tooltip: '刪除目標'),
                  IconButton(icon: const Icon(Icons.share_outlined, color: Colors.blue, size: 24), onPressed: () => Share.share('我正在「${goal.category}」挑戰中，目前進度 ${(progress * 100).toInt()}%！')),
                ],
              ),
            ],
          ),
          if (_isExpanded) ...[
            const Divider(height: 24),
            GoalCalendarView(goal: goal),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievementSection(BuildContext context, WidgetRef ref, Goal goal, Color catColor) {
    final stats = goal.type == GoalType.time 
        ? ref.read(goalProvider.notifier).getRecords(goal)
        : ref.read(taskGoalProvider.notifier).getRecords(goal);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [catColor.withOpacity(0.08), catColor.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: catColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, size: 16, color: catColor),
              const SizedBox(width: 6),
              Text('連續達成記錄', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: catColor)),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _buildStatItem('🔥 歷史最高', stats['historical']!, stats['historical_date']!, catColor)),
                VerticalDivider(width: 32, thickness: 1, color: catColor.withOpacity(0.2)),
                Expanded(child: _buildStatItem('📅 本月最佳', stats['monthly']!, stats['monthly_date']!, Colors.amber.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String date, Color color) {
    return Tooltip(
      message: date.isEmpty ? '尚無紀錄' : '達成日期: $date',
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          if (date.isNotEmpty)
            Text(
              date,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }

  void _showAddTimeDialog(BuildContext context, WidgetRef ref) {
    final hController = TextEditingController();
    final mController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增專注時長'),
        content: Row(
          children: [
            Expanded(child: TextField(controller: hController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '時'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: mController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '分'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () {
            final h = int.tryParse(hController.text) ?? 0;
            final m = int.tryParse(mController.text) ?? 0;
            final seconds = h * 3600 + m * 60;
            if (seconds > 0) {
              ref.read(sessionsProvider.notifier).addSession(
                TimeSession(
                  category: widget.goal.category,
                  durationSeconds: seconds,
                  date: DateTime.now(),
                ),
              );
              Navigator.pop(ctx);
            }
          }, child: const Text('新增')),
        ],
      ),
    );
  }

  void _showManualCountDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('設定今日進度'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '輸入完成單位')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () {
            final val = int.tryParse(controller.text) ?? 0;
            ref.read(taskGoalProvider.notifier).setManualValue(widget.goal.id, DateTime.now(), val);
            Navigator.pop(ctx);
          }, child: const Text('確認')),
        ],
      ),
    );
  }

  void _showMoreOptionsMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('任務管理選項', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.edit_outlined, color: Colors.blue)),
              title: const Text('編輯目標內容', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(ctx); widget.onEdit?.call(widget.goal); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.visibility_off_outlined, color: Colors.orange)),
              title: const Text('僅在此頁隱藏', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('目標會隱藏，但計時與數據將保留'),
              onTap: () { 
                ref.read(goalsHiddenCategoriesProvider.notifier).hideCategory(widget.goal.category);
                Navigator.pop(ctx); 
              },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.brown.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.archive_outlined, color: Colors.brown)),
              title: const Text('封存整個類別', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('在全球視圖中同步隱藏此類別'),
              onTap: () { 
                 ref.read(categoryColorProvider.notifier).archiveCategory(widget.goal.category);
                 Navigator.pop(ctx); 
              },
            ),
            Divider(height: 32, indent: 20, endIndent: 20, color: Colors.grey.withOpacity(0.2)),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_forever_outlined, color: Colors.red)),
              title: const Text('永久移除此目標條目', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () { 
                if (widget.goal.type == GoalType.time) {
                  ref.read(goalProvider.notifier).deleteGoal(widget.goal.id);
                } else {
                  ref.read(taskGoalProvider.notifier).deleteGoal(widget.goal.id);
                }
                Navigator.pop(ctx); 
              },
            ),
          ],
        ),
      ),
    );
  }
}
