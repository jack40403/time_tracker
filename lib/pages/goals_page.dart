import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/goal.dart';
import '../providers/goal_provider.dart';
import '../theme/cartoon_theme.dart';
import '../providers/task_goal_provider.dart';
import '../providers/category_provider.dart';
import '../providers/goal_order_provider.dart';
import '../providers/firestore_provider.dart';
import '../widgets/goal_progress_card.dart';

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});
  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  @override
  void initState() {
    super.initState();
    // 進入頁面時自動抓取歷史紀錄套入目標
    WidgetsBinding.instance.addPostFrameCallback((_) {
       ref.read(goalProvider.notifier).recalculateAllGoalsHistory();
    });
  }

  // ── 用排序後的 ID 列表組合顯示順序
  List<Goal> _sortedGoals(List<Goal> all, List<String> order) {
    final map = {for (final g in all) g.id: g};
    final sorted = <Goal>[];
    // 先按已知順序加入
    for (final id in order) {
      if (map.containsKey(id)) sorted.add(map[id]!);
    }
    // 新增但還沒在順序列表中的目標加到末尾
    for (final g in all) {
      if (!order.contains(g.id)) {
        sorted.add(g);
        ref.read(goalOrderProvider.notifier).ensureContains(g.id);
      }
    }
    return sorted;
  }

  void _onReorder(List<Goal> current, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final updated = List<Goal>.from(current);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    ref.read(goalOrderProvider.notifier).reorder(updated.map((g) => g.id).toList());
  }

  // ──────────────────────────────────────────────────────
  // 強制同步
  // ──────────────────────────────────────────────────────
  void _forceSync() async {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) {
      _showError('請先登入才能同步');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('正在從雲端同步...'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
    // 直接讀取 Firestore 目前快照，繞過 stream 快取
    try {
      final goals = await firestore.fetchGoalsOnce();
      final taskGoals = await firestore.fetchTaskGoalsOnce();
      if (goals.isNotEmpty) {
        final remote = goals.map((e) => Goal.fromJson(e)).toList();
        ref.read(goalProvider.notifier).forceMergeFromCloud(remote);
      }
      if (taskGoals.isNotEmpty) {
        final remote = taskGoals.map((e) => Goal.fromJson(e)).toList();
        ref.read(taskGoalProvider.notifier).forceMergeFromCloud(remote);
      }
      if (mounted) {
        _showSuccess('同步完成！共載入 ${goals.length + taskGoals.length} 個目標');
      }
    } catch (e) {
      if (mounted) _showError('同步失敗：$e');
    }
  }

  // ──────────────────────────────────────────────────────
  // 新增目標 Dialog
  // ──────────────────────────────────────────────────────
  void _showAddGoalDialog({String? initialCategory}) {
    final visibleCategories = ref.read(goalsVisibleCategoriesProvider);
    final catColors = ref.read(categoryColorProvider);
    if (visibleCategories.isEmpty) { _showNoCategoryDialog(); return; }

    String selectedCategory = initialCategory ?? visibleCategories.first;
    if (initialCategory != null && !visibleCategories.contains(initialCategory)) {
      selectedCategory = visibleCategories.first;
    }
    GoalType selectedType = GoalType.time;
    GoalPeriod selectedPeriod = GoalPeriod.daily;
    DateTime selectedStartDate = DateTime.now();
    final hoursCtrl  = TextEditingController(text: '1');
    final minsCtrl   = TextEditingController(text: '0');
    final countCtrl  = TextEditingController(text: '5');
    bool isReminderEnabled = false;
    TimeOfDay selectedReminderTime = const TimeOfDay(hour: 9, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('設定新目標', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(height: 28),
                Text('追蹤項目', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedCategory, isExpanded: true, underline: const SizedBox(),
                          style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87),
                          items: visibleCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setS(() => selectedCategory = v!),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                        tooltip: '新增項目類別',
                        onPressed: () { Navigator.pop(ctx); _showAddCategoryThenGoal(); },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('目標模式', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _typeChip(GoalType.time,   '⏱ 時間型', selectedType, (v) => setS(() => selectedType = v)),
                    _typeChip(GoalType.task,   '🔢 計數型', selectedType, (v) => setS(() => selectedType = v)),
                    _typeChip(GoalType.binary, '✅ 是非型', selectedType, (v) => setS(() => selectedType = v)),
                  ],
                ),
                const SizedBox(height: 20),
                if (selectedType == GoalType.time) ...[
                  Text('每期目標時數', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _bigField(hoursCtrl, '小時', '時')),
                    const SizedBox(width: 12),
                    Expanded(child: _bigField(minsCtrl, '分鐘', '分')),
                  ]),
                ] else if (selectedType == GoalType.task) ...[
                  Text('每期目標次數', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  _bigField(countCtrl, '次數', '次'),
                ],
                const SizedBox(height: 20),
                Text('統計週期', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                  child: DropdownButton<GoalPeriod>(
                    value: selectedPeriod, isExpanded: true, underline: const SizedBox(),
                    style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87),
                    items: const [
                      DropdownMenuItem(value: GoalPeriod.daily,   child: Text('每日')),
                      DropdownMenuItem(value: GoalPeriod.weekly,  child: Text('每週')),
                      DropdownMenuItem(value: GoalPeriod.monthly, child: Text('每月')),
                      DropdownMenuItem(value: GoalPeriod.yearly,  child: Text('每年')),
                    ],
                    onChanged: (v) => setS(() => selectedPeriod = v!),
                  ),
                ),
                const SizedBox(height: 20),
                Text('目標起始日', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: selectedStartDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setS(() => selectedStartDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 18, color: Colors.blueGrey),
                      const SizedBox(width: 12),
                      Text('${selectedStartDate.year}-${selectedStartDate.month.toString().padLeft(2,'0')}-${selectedStartDate.day.toString().padLeft(2,'0')}', style: GoogleFonts.outfit(fontSize: 16)),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                // --- 提醒時間設定 ---
                Row(
                  children: [
                    Text('開啟提醒', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                    const Spacer(),
                    Switch(
                      value: isReminderEnabled,
                      onChanged: (v) => setS(() => isReminderEnabled = v),
                    ),
                  ],
                ),
                if (isReminderEnabled) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: selectedReminderTime);
                      if (picked != null) setS(() => selectedReminderTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.access_time, size: 18, color: Colors.blueGrey),
                        const SizedBox(width: 12),
                        Text('提醒時間: ${selectedReminderTime.format(context)}', style: GoogleFonts.outfit(fontSize: 16)),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('取消'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      int target;
                      if (selectedType == GoalType.time) {
                        final h = int.tryParse(hoursCtrl.text) ?? 0;
                        final m = int.tryParse(minsCtrl.text) ?? 0;
                        target = h * 3600 + m * 60;
                        if (target <= 0) { _showError('請填寫時間目標'); return; }
                      } else if (selectedType == GoalType.task) {
                        target = int.tryParse(countCtrl.text) ?? 0;
                        if (target <= 0) { _showError('請填寫目標次數'); return; }
                      } else {
                        target = 1;
                      }
                      Navigator.pop(ctx);
                      if (selectedType == GoalType.time) {
                        final newId = ref.read(goalProvider.notifier).addGoal(
                          selectedCategory, target, selectedPeriod,
                          title: selectedCategory, type: selectedType, startDate: selectedStartDate,
                          reminderTime: isReminderEnabled ? '${selectedReminderTime.hour.toString().padLeft(2, "0")}:${selectedReminderTime.minute.toString().padLeft(2, "0")}' : null,
                          isReminderEnabled: isReminderEnabled,
                        );
                        ref.read(goalOrderProvider.notifier).ensureContains(newId);
                        _showApplyHistoryDialog(newId, selectedCategory);
                      } else {
                        ref.read(taskGoalProvider.notifier).addGoal(
                          selectedCategory, target, selectedPeriod,
                          title: selectedCategory, type: selectedType, startDate: selectedStartDate,
                          reminderTime: isReminderEnabled ? '${selectedReminderTime.hour.toString().padLeft(2, "0")}:${selectedReminderTime.minute.toString().padLeft(2, "0")}' : null,
                          isReminderEnabled: isReminderEnabled,
                        );
                        _showSuccess('目標「$selectedCategory」已建立 ✨');
                      }
                    },
                    child: Text('建立目標', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                  )),
                ]),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _typeChip(GoalType type, String label, GoalType selected, ValueChanged<GoalType> onTap) {
    final isSelected = type == selected;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
      selected: isSelected,
      onSelected: (_) => onTap(type),
      selectedColor: Colors.blue.shade100,
      side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300),
    );
  }

  Widget _bigField(TextEditingController ctrl, String label, String suffix) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label, suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _showApplyHistoryDialog(String goalId, String category) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('📊 套用過去計時紀錄？'),
          content: Text('是否要根據「$category」項目過去的計時紀錄，自動填入目標月曆？'),
          actions: [
            TextButton(onPressed: () { Navigator.pop(ctx); _showSuccess('目標「$category」已建立 ✨'); }, child: const Text('不套用')),
            ElevatedButton(
              onPressed: () {
                ref.read(goalProvider.notifier).recalculateHistoryFromSessions(goalId);
                Navigator.pop(ctx);
                _showSuccess('已套用歷史紀錄 📊');
              },
              child: const Text('套用歷史紀錄'),
            ),
          ],
        ),
      );
    });
  }

  // ──────────────────────────────────────────────────────
  // 編輯目標 Dialog
  // ──────────────────────────────────────────────────────
  void _showEditGoalDialog(Goal goal) {
    final titleCtrl = TextEditingController(text: goal.title);
    GoalPeriod selectedPeriod = goal.period;
    DateTime selectedStartDate = goal.startDate;
    final hoursCtrl = TextEditingController(text: goal.type == GoalType.time ? (goal.targetSeconds ~/ 3600).toString() : goal.targetSeconds.toString());
    final minsCtrl = TextEditingController(text: goal.type == GoalType.time ? ((goal.targetSeconds % 3600) ~/ 60).toString() : '0');
    bool isReminderEnabled = goal.isReminderEnabled;
    TimeOfDay selectedReminderTime = const TimeOfDay(hour: 9, minute: 0);
    if (goal.reminderTime != null) {
      final parts = goal.reminderTime!.split(':');
      selectedReminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('編輯目標', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
              const Divider(height: 28),
              TextField(controller: titleCtrl, style: GoogleFonts.outfit(fontSize: 16),
                decoration: InputDecoration(labelText: '目標名稱', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
              const SizedBox(height: 20),
              Text('統計週期', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: DropdownButton<GoalPeriod>(value: selectedPeriod, isExpanded: true, underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: GoalPeriod.daily, child: Text('每日')),
                    DropdownMenuItem(value: GoalPeriod.weekly, child: Text('每週')),
                    DropdownMenuItem(value: GoalPeriod.monthly, child: Text('每月')),
                    DropdownMenuItem(value: GoalPeriod.yearly, child: Text('每年')),
                  ],
                  onChanged: (v) => setS(() => selectedPeriod = v!)),
              ),
              const SizedBox(height: 20),
              if (goal.type == GoalType.time) ...[
                Text('每期目標時數', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: _bigField(hoursCtrl, '小時', '時')), const SizedBox(width: 12), Expanded(child: _bigField(minsCtrl, '分鐘', '分'))]),
              ] else if (goal.type == GoalType.task) ...[
                Text('每期目標次數', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                _bigField(hoursCtrl, '次數', '次'),
              ],
              const SizedBox(height: 20),
              Text('目標起始日', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: selectedStartDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (picked != null) setS(() => selectedStartDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 12),
                    Text('${selectedStartDate.year}-${selectedStartDate.month.toString().padLeft(2,'0')}-${selectedStartDate.day.toString().padLeft(2,'0')}', style: GoogleFonts.outfit(fontSize: 16)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              // --- 提醒時間設定 ---
              Row(
                children: [
                  Text('開啟提醒', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                  const Spacer(),
                  Switch(
                    value: isReminderEnabled,
                    onChanged: (v) => setS(() => isReminderEnabled = v),
                  ),
                ],
              ),
              if (isReminderEnabled) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(context: ctx, initialTime: selectedReminderTime);
                    if (picked != null) setS(() => selectedReminderTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.access_time, size: 18, color: Colors.blueGrey),
                      const SizedBox(width: 12),
                      Text('提醒時間: ${selectedReminderTime.format(context)}', style: GoogleFonts.outfit(fontSize: 16)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('取消'))),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    int target;
                    if (goal.type == GoalType.time) {
                      final h = int.tryParse(hoursCtrl.text) ?? 0;
                      final m = int.tryParse(minsCtrl.text) ?? 0;
                      target = h * 3600 + m * 60;
                      if (target <= 0) { _showError('請填寫時間目標'); return; }
                    } else if (goal.type == GoalType.task) {
                      target = int.tryParse(hoursCtrl.text) ?? 0;
                      if (target <= 0) { _showError('請填寫目標次數'); return; }
                    } else { target = 1; }
                    final updated = goal.copyWith(
                      title: titleCtrl.text.isNotEmpty ? titleCtrl.text : goal.category, 
                      period: selectedPeriod, 
                      targetSeconds: target, 
                      startDate: selectedStartDate,
                      reminderTime: isReminderEnabled ? '${selectedReminderTime.hour.toString().padLeft(2, "0")}:${selectedReminderTime.minute.toString().padLeft(2, "0")}' : null,
                      isReminderEnabled: isReminderEnabled,
                    );
                    if (selectedStartDate != goal.startDate && goal.type == GoalType.time) {
                      Navigator.pop(ctx); _showRecalculateDialog(updated);
                    } else {
                      if (goal.type == GoalType.time) ref.read(goalProvider.notifier).updateGoal(updated);
                      else ref.read(taskGoalProvider.notifier).updateGoal(updated);
                      Navigator.pop(ctx); _showSuccess('目標已更新');
                    }
                  },
                  child: Text('確認更新', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                )),
              ]),
            ],
          ),
        ),
      )),
    );
  }

  void showDeleteGoalDialog(Goal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認刪除目標'),
        content: Text('確定要永久移除「${goal.title}」這個目標嗎？\n\n計時紀錄不受影響。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(goalOrderProvider.notifier).remove(goal.id);
              if (goal.type == GoalType.time) ref.read(goalProvider.notifier).deleteGoal(goal.id);
              else ref.read(taskGoalProvider.notifier).deleteGoal(goal.id);
              Navigator.pop(ctx);
              _showSuccess('目標已刪除');
            },
            child: const Text('確認刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRecalculateDialog(Goal updatedGoal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('起始日期已變更'),
        content: const Text('是否根據過去的計時紀錄，自動重算目標達成狀況？'),
        actions: [
          TextButton(onPressed: () { ref.read(goalProvider.notifier).updateGoal(updatedGoal); Navigator.pop(ctx); }, child: const Text('僅更新日期')),
          ElevatedButton(
            onPressed: () {
              ref.read(goalProvider.notifier).updateGoal(updatedGoal);
              ref.read(goalProvider.notifier).recalculateHistoryFromSessions(updatedGoal.id);
              Navigator.pop(ctx); _showSuccess('已根據歷史紀錄重新計算 ✨');
            },
            child: const Text('套用過去紀錄'),
          ),
        ],
      ),
    );
  }

  void _showNoCategoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ 尚未建立任何項目'),
        content: const Text('請先在計時頁新增一個計時項目，再回來設定目標。'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))],
      ),
    );
  }

  void _showAddCategoryThenGoal() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增項目類別'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '例如：閱讀 📚、冥想 🧘'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final newCat = ctrl.text.trim();
              if (newCat.isNotEmpty) {
                ref.read(categoryColorProvider.notifier).addCategory(newCat, Colors.blueAccent);
                Navigator.pop(ctx);
                _showAddGoalDialog(initialCategory: newCat);
              }
            },
            child: const Text('新增並繼續'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating));

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('⚠️ $msg'), backgroundColor: Colors.orange.shade800, behavior: SnackBarBehavior.floating));

  // ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final timeGoals  = ref.watch(visibleTimeGoalsProvider);
    final taskGoals  = ref.watch(visibleTaskGoalsProvider);
    final order      = ref.watch(goalOrderProvider);
    final allGoals   = _sortedGoals([...timeGoals, ...taskGoals], order);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CartoonAppBar(
        title: '專注目標 🎯',
        actions: [
          IconButton(
            onPressed: _forceSync,
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: '強制從雲端同步',
          ),
          IconButton(
            onPressed: _showAddGoalDialog,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '新增目標',
          ),
        ],
      ),
      body: allGoals.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('尚無目標，開啟新挑戰吧！', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(onPressed: _showAddGoalDialog, icon: const Icon(Icons.add), label: const Text('建立第一個目標')),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) => _onReorder(allGoals, oldIndex, newIndex),
              itemCount: allGoals.length,
              itemBuilder: (context, index) {
                final goal = allGoals[index];
                return Container(
                  key: ValueKey(goal.id),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 專屬拖把區域（只有這個區域可以拖曳）
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 18, right: 4, left: 0),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: Colors.grey.withOpacity(0.5),
                            size: 22,
                          ),
                        ),
                      ),
                      // 卡片本體（不參與拖曳）
                      Expanded(
                        child: GoalProgressCard(
                          goal: goal,
                          onEdit: _showEditGoalDialog,
                          onDelete: showDeleteGoalDialog,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
