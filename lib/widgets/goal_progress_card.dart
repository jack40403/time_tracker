import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/goal.dart';
import '../providers/goal_provider.dart';
import '../providers/category_provider.dart';
import 'goal_calendar_view.dart';

class GoalProgressCard extends ConsumerStatefulWidget {
  final Goal goal;
  final Function(Goal)? onEdit;
  const GoalProgressCard({super.key, required this.goal, this.onEdit});

  @override
  ConsumerState<GoalProgressCard> createState() => _GoalProgressCardState();
}

class _GoalProgressCardState extends ConsumerState<GoalProgressCard> {
  bool _isExpanded = false;

  String _getAverageText(Goal goal) {
    if (goal.type == GoalType.task) return '';
    final hrs = goal.targetSeconds / 3600;
    switch (goal.period) {
      case GoalPeriod.daily: return ''; // No sub-average for daily
      case GoalPeriod.weekly: return '每日平均: ${(hrs / 7).toStringAsFixed(1)} 小時';
      case GoalPeriod.monthly: return '每週平均: ${(hrs / 4).toStringAsFixed(1)} 小時';
      case GoalPeriod.yearly: return '每月平均: ${(hrs / 12).toStringAsFixed(1)} 小時';
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final progress = ref.watch(goalProvider.notifier).getProgress(goal);
    final remainingText = ref.watch(goalProvider.notifier).getRemainingText(goal);
    final averageText = _getAverageText(goal);
    final catColor = ref.watch(categoryColorProvider)[goal.category] ?? Colors.blue;
    final isAchieved = progress >= 1.0;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    // isTodayCompleted is true if manually checked (> 0 units) OR progress is 100%
    final isTodayCompleted = ((goal.completionHistory[todayStr] ?? 0) > 0) || isAchieved;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: isAchieved ? catColor.withOpacity(0.6) : Theme.of(context).colorScheme.outlineVariant, width: 1.5),
        boxShadow: [
          if (isAchieved) BoxShadow(color: catColor.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    goal.category,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ],
              ),
              Row(
                children: [
                   // Sophisticated Glassmorphism Toggle
                  // Manual Completion Toggle (Only for Tasks)
                  if (goal.type == GoalType.task)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                         onLongPress: () => _showManualCountDialog(context, ref),
                         child: InkWell(
                          onTap: () {
                            final current = goal.completionHistory[todayStr] ?? 0;
                            ref.read(goalProvider.notifier).setManualValue(goal.id, DateTime.now(), (current as int) + 1);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isAchieved ? Colors.green.withOpacity(0.15) : catColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isAchieved ? Colors.green.withOpacity(0.4) : catColor.withOpacity(0.4), 
                                width: 1.2
                              ),
                              boxShadow: [
                                if (isAchieved) BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 10, spreadRadius: 1),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '今日進度: ${_formatTodayValue(goal.completionHistory[todayStr] ?? 0, goal.type)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold, 
                                    color: isAchieved ? Colors.green.shade700 : (catColor is MaterialColor ? (catColor as MaterialColor).shade700 : catColor)
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.add_circle_outline,
                                  color: isAchieved ? Colors.green.shade700 : (catColor is MaterialColor ? (catColor as MaterialColor).shade700 : catColor),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    // Informative tag for time-based goals
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text('自動追蹤中', style: TextStyle(fontSize: 13, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      goal.period == GoalPeriod.daily ? '每日' : goal.period == GoalPeriod.weekly ? '每週' : goal.period == GoalPeriod.monthly ? '每月' : '每年',
                      style: TextStyle(fontSize: 14, color: catColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.type == GoalType.task ? '目標: ${goal.targetSeconds} 單位' : '目標: ${ (goal.targetSeconds / 3600).floor() > 0 ? '${(goal.targetSeconds / 3600).floor()}h ' : ''}${((goal.targetSeconds % 3600) / 60).round()}m',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  if (averageText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        averageText,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.shareTechMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  color: isAchieved ? Colors.green : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(isAchieved ? Colors.green : catColor),
            ),
          ),
          const SizedBox(height: 16),
          // Streak Stats Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStreakBadge(
                  context, 
                  '🔥 歷史最高連續', 
                  '${ref.read(goalProvider.notifier).getStreaks(goal)['success']} 天', 
                  Colors.orange.shade800,
                  Colors.orange.shade50,
                ),
                const SizedBox(width: 12),
                _buildStreakBadge(
                  context, 
                  '🌙 本月最高紀錄', 
                  '${ref.read(goalProvider.notifier).getStreaks(goal)['month']} 天', 
                  Colors.indigo.shade800,
                  Colors.indigo.shade50,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  remainingText,
                  style: TextStyle(
                    fontSize: 16,
                    color: isAchieved ? Colors.green : Colors.grey.shade600,
                    fontWeight: isAchieved ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              Row(
                children: [
                   InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isExpanded ? Icons.calendar_month : Icons.calendar_month_outlined, size: 22, color: Colors.indigoAccent),
                        const SizedBox(width: 4),
                        Text(
                          _isExpanded ? '隱藏日誌' : '達成日誌',
                          style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 22, color: Colors.blueAccent),
                    onPressed: () {
                      final percent = (progress * 100).toInt();
                      final isDone = progress >= 1.0;
                      final random = DateTime.now().millisecond;
                      
                      final achievedTemplates = [
                        '【Me Time】達成！🕵️‍♂️ 「${goal.category}」目標圓滿完成！🏆',
                        '管理大師！💪 【Me Time】「${goal.category}」成就達成！💯',
                      ];

                      final progressTemplates = [
                        '【Me Time】🔥 「${goal.category}」進度 $percent% ✨',
                        '拒絕躺平！😤 「${goal.category}」達成率 $percent%。🚀',
                      ];

                      final templates = isDone ? achievedTemplates : progressTemplates;
                      final shareMsg = templates[random % templates.length];
                      Share.share(shareMsg);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 24, color: Colors.blueGrey),
                    onPressed: () {
                      if (widget.onEdit != null) {
                        widget.onEdit!(goal);
                      }
                    },
                    tooltip: '編輯目標',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 24, color: Colors.redAccent),
                    onPressed: () => _showDeleteConfirmation(context, ref),
                    tooltip: '刪除目標',
                  ),
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

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final goal = widget.goal;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('刪除目標選項', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('請選擇您要執行的刪除動作：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDeleteOption(
              context,
              title: '僅刪除此目標',
              subtitle: '只將目標從清單移除，保留分類與所有歷史統計。',
              color: Colors.blueGrey,
              onTap: () {
                Navigator.pop(ctx);
                ref.read(goalProvider.notifier).deleteGoal(goal.id);
                _showSuccessSnackBar(context, '目標已移除，歷史紀錄已保留。');
              },
            ),
            const SizedBox(height: 12),
            _buildDeleteOption(
              context,
              title: '整體徹底刪除',
              subtitle: '移除目標、分類標籤、以及所有專注歷史紀錄。',
              color: Colors.redAccent,
              isDangerous: true,
              onTap: () {
                Navigator.pop(ctx);
                _showTotalWipeFinalConfirmation(context, ref, goal);
              },
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteOption(BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDangerous = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDangerous ? color.withOpacity(0.08) : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(isDangerous ? Icons.warning_amber_rounded : Icons.delete_outline, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  void _showTotalWipeFinalConfirmation(BuildContext context, WidgetRef ref, Goal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ 最後確認', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('這是一個不可逆的操作！「${goal.category}」的所有專注時數、日曆紀錄與統計資料都將灰飛煙滅。確認執行？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我再想想', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(goalProvider.notifier).deleteGoalCompletely(goal);
              _showSuccessSnackBar(context, '⚠️ 已徹底刪除「${goal.category}」的所有資料。', isWarning: true);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('確認徹底刪除', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isWarning ? Colors.red.shade900 : Colors.blueGrey.shade900,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStreakBadge(BuildContext context, String label, String value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.outfit(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showManualCountDialog(BuildContext context, WidgetRef ref) {
    final goal = widget.goal;
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final initialCount = goal.completionHistory[todayStr] ?? 0;
    final controller = TextEditingController(text: initialCount.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('設定今日數值', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('當前項目: ${goal.category}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
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
              ref.read(goalProvider.notifier).setManualValue(goal.id, DateTime.now(), count);
              Navigator.pop(ctx);
            },
            child: const Text('確認變更'),
          ),
        ],
      ),
    );
  }

  String _formatTodayValue(int val, GoalType type) {
    if (val <= 0) return '+0';
    if (type == GoalType.task) return '+$val 單位';
    
    if (val < 60) return '+$val s';
    if (val < 3600) return '+${(val / 60).toStringAsFixed(0)}m';
    return '+${(val / 3600).toStringAsFixed(1)}h';
  }
}
