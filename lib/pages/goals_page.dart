import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../models/goal.dart';
import '../providers/goal_provider.dart';
import '../providers/category_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/goal_progress_card.dart';
import '../widgets/category_dialogs.dart';

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _showGoalFormDialog({Goal? existingGoal}) {
    final catColors = ref.read(categoryColorProvider);
    final visibleCategories = ref.read(visibleCategoriesProvider);
    final sessions = ref.read(sessionsProvider);
    final historyCategories = sessions.map((s) => s.category).toSet();
    
    // Combine current visible categories and historical categories
    final allCategories = {...visibleCategories, ...historyCategories}.toList();
    if (allCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 請先新增至少一個項目或開始計時')),
      );
      return;
    }

    final bool isEditing = existingGoal != null;
    GoalPeriod selectedPeriod = existingGoal?.period ?? GoalPeriod.daily;
    GoalType selectedType = existingGoal?.type ?? GoalType.time;
    
    final int initialSeconds = existingGoal?.targetSeconds ?? 7200; // 2h default
    final hoursController = TextEditingController(text: (initialSeconds ~/ 3600).toString());
    final minutesController = TextEditingController(text: ((initialSeconds % 3600) ~/ 60).toString());
    DateTime selectedStartDate = existingGoal?.startDate ?? DateTime.now();
    String? manuallySelectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              final categories = allCategories;
              final currentCategory = manuallySelectedCategory ?? (isEditing ? existingGoal!.category : categories.first);
              final safeCategory = categories.contains(currentCategory) ? currentCategory : categories.first;

              return Container(
              padding: EdgeInsets.only(
                left: 28, right: 28, top: 28,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45, height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(isEditing ? '編輯目標' : '設定新目標', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('選擇項目', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      if (!isEditing)
                         IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                          onPressed: () => showAddCategoryDialog(context, ref),
                          tooltip: '新增項目',
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: safeCategory,
                    style: TextStyle(fontSize: 20, color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    items: categories.map((c) => DropdownMenuItem<String>(
                      value: c,
                      child: Row(children: [
                        Container(
                          width: 14, height: 14, 
                          decoration: BoxDecoration(
                            color: catColors[c] ?? Colors.grey.withOpacity(0.5), 
                            shape: BoxShape.circle
                          )
                        ),
                        const SizedBox(width: 12),
                        Text(c, style: const TextStyle(fontSize: 20)),
                      ]),
                    )).toList(),
                    onChanged: isEditing ? null : (v) { 
                      if (v != null) {
                        setModalState(() => manuallySelectedCategory = v);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

              Text('目標週期 (Period)', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<GoalPeriod>(
                  segments: const [
                    ButtonSegment(value: GoalPeriod.daily, label: Text('日', style: TextStyle(fontSize: 18))),
                    ButtonSegment(value: GoalPeriod.weekly, label: Text('週', style: TextStyle(fontSize: 18))),
                    ButtonSegment(value: GoalPeriod.monthly, label: Text('月', style: TextStyle(fontSize: 18))),
                    ButtonSegment(value: GoalPeriod.yearly, label: Text('年', style: TextStyle(fontSize: 18))),
                  ],
                  selected: {selectedPeriod},
                  onSelectionChanged: (val) => setModalState(() => selectedPeriod = val.first),
                ),
              ),
              const SizedBox(height: 20),

              Text('目標類型 (Type)', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<GoalType>(
                  segments: const [
                    ButtonSegment(value: GoalType.time, label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.timer_outlined, size: 20), SizedBox(width: 8), Text('時間型')])),
                    ButtonSegment(value: GoalType.task, label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_outline, size: 20), SizedBox(width: 8), Text('任務型')])),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (val) => setModalState(() => selectedType = val.first),
                ),
              ),
              const SizedBox(height: 20),

              if (selectedType == GoalType.time) ...[
                Text('目標時間 (Target Time)', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: '小時',
                          labelStyle: const TextStyle(fontSize: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: '分鐘',
                          labelStyle: const TextStyle(fontSize: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                 Text('目標單位/次數 (Target Units)', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 10),
                 TextField(
                    controller: hoursController, // Reusing hoursController for total units
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: '設定本週期的目標總量',
                      hintText: '例如：5 (次)、10 (公里)...',
                      labelStyle: const TextStyle(fontSize: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.numbers_outlined),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Text('開始日期 (Start Date)', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async { 
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedStartDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setModalState(() => selectedStartDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isEditing ? Theme.of(context).disabledColor.withOpacity(0.05) : null,
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        '${selectedStartDate.year}/${selectedStartDate.month.toString().padLeft(2, '0')}/${selectedStartDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
               if (isEditing) ...[
                 const Divider(height: 32),
                 SizedBox(
                   width: double.infinity,
                   child: OutlinedButton.icon(
                     onPressed: () async {
                       final res = await showDialog<bool>(
                         context: context,
                         builder: (ctx) => AlertDialog(
                           title: const Text('確認重新掃描歷史？'),
                           content: const Text('這將根據您原始的「計時紀錄」重新計算過往每一天的產出，所有手動修改過的筆記都會被覆蓋。此動作無法復原，確認執行？'),
                           actions: [
                             TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                             ElevatedButton(
                               onPressed: () => Navigator.pop(ctx, true),
                               style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50),
                               child: Text('確認掃描', style: TextStyle(color: Colors.red.shade700)),
                             ),
                           ],
                         ),
                       );

                       if (res == true) {
                         ref.read(goalProvider.notifier).rescanGoalHistory(existingGoal!.id);
                         Navigator.pop(ctx);
                         _showSuccessSnackBar('✅ 歷史紀錄已重新校準');
                       }
                     },
                     icon: const Icon(Icons.history_toggle_off, size: 20),
                     label: const Text('重新掃描與校正歷史紀錄', style: TextStyle(fontWeight: FontWeight.bold)),
                     style: OutlinedButton.styleFrom(
                       foregroundColor: Colors.grey.shade700,
                       side: BorderSide(color: Colors.grey.shade300),
                       padding: const EdgeInsets.symmetric(vertical: 12),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                   ),
                 ),
                 const SizedBox(height: 16),
               ],

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    final isTask = selectedType == GoalType.task;
                    final hrs = int.tryParse(hoursController.text) ?? 0;
                    final mins = int.tryParse(minutesController.text) ?? 0;
                    final totalValue = isTask ? hrs : (hrs * 3600) + (mins * 60);
                    
                    if (totalValue > 0) {
                      if (isEditing) {
                        final updatedGoal = existingGoal!.copyWith(
                          period: selectedPeriod,
                          type: selectedType,
                          targetSeconds: totalValue,
                          startDate: selectedStartDate,
                        );

                        bool shouldRebackfill = false;
                        final durationChanged = existingGoal.targetSeconds != updatedGoal.targetSeconds;
                        final dateChanged = !DateUtils.isSameDay(existingGoal.startDate, updatedGoal.startDate);

                        if (durationChanged || dateChanged) {
                          final res = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('目標設定已變更'),
                              content: Text(dateChanged 
                                ? '您修改了目標的開始日期，是否要根據新日期重新掃描並計算過去的達成歷史？' 
                                : '您修改了目標的時長標準，是否要根據新標準重新計算過去的達成歷史？'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('保留現狀 (Keep)')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('重新掃描歷史')),
                              ],
                            ),
                          );
                          shouldRebackfill = res ?? false;
                        }

                        ref.read(goalProvider.notifier).updateGoal(updatedGoal, rebackfill: shouldRebackfill);
                        Navigator.pop(ctx);
                        _showSuccessSnackBar('✅ 目標已更新');
                      } else {
                        ref.read(goalProvider.notifier).addGoal(
                          safeCategory,
                          totalValue,
                          selectedPeriod,
                          type: selectedType,
                          startDate: selectedStartDate,
                        );
                        Navigator.pop(ctx);
                        _showSuccessSnackBar('✅ 目標已建立項目');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(isEditing ? '確認更新' : '確認建立', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ], // Close children
          ), // Close Column
        ); // Close Container
            },
          ); // Close StatefulBuilder
    }, // Close Consumer builder
  ), // Close Consumer
); // Close showModalBottomSheet
}

  void _showSuccessSnackBar(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontSize: 15)), 
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  void _triggerMilestoneSurprise(Goal goal) {
    String msg = '';
    switch (goal.lastMilestone) {
      case 25: msg = '🎉 初試身手！"${goal.category}" 已達成 25%！'; break;
      case 50: msg = '🔥 保持火熱！"${goal.category}" 已達成一半！'; break;
      case 75: msg = '🚀 快要到了！"${goal.category}" 已達成 75%！'; break;
      case 100: msg = '🏆 榮耀時刻！"${goal.category}" 已圓滿達成！'; break;
    }
    
    if (msg.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 1500),
        ),
      );
      _confettiController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for milestone achievements
    ref.listen<List<Goal>>(goalProvider, (previous, next) {
      if (previous == null) return;
      for (var nextGoal in next) {
        final prevGoal = previous.firstWhere((g) => g.id == nextGoal.id, orElse: () => nextGoal);
        if (nextGoal.lastMilestone > prevGoal.lastMilestone) {
          _triggerMilestoneSurprise(nextGoal);
        }
      }
    });

    final goals = ref.watch(visibleGoalsProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('專注目標', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
                child: FilledButton.tonalIcon(
                  onPressed: () => _showGoalFormDialog(),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('新增目標', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
          body: goals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('尚未設定目標', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('設定一個目標來挑戰自己吧！', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: goals.length,
                  itemBuilder: (context, index) => GoalProgressCard(
                    goal: goals[index],
                    onEdit: (goal) => _showGoalFormDialog(existingGoal: goal),
                  ),
                ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ),
      ],
    );
  }
}
