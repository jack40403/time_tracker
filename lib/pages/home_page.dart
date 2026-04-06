import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import '../providers/timer_provider.dart';
import '../providers/category_provider.dart';
import '../providers/session_provider.dart';
import '../providers/firestore_provider.dart';
import '../providers/layout_provider.dart';
import '../widgets/category_dialogs.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _formatTime(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hrs > 0) return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildWideLayout(context, ref, constraints);
          } else {
            return _buildMobileLayout(context, ref, constraints);
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, WidgetRef ref, BoxConstraints constraints) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildHeader(context, ref),
          const SizedBox(height: 16),
          _buildCategoryList(context, ref),
          const SizedBox(height: 10),
          _buildTimerCard(context, ref),
          _buildActionButtons(context, ref),
        ],
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, WidgetRef ref, BoxConstraints constraints) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left side: Main Timer Card & Actions
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    Expanded(child: Center(child: _buildTimerCard(context, ref, scale: 1.1))),
                    _buildActionButtons(context, ref),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
              // Vertical Divider
              Container(width: 1, color: Colors.white.withOpacity(0.1)),
              // Right side: Header & Category Selector
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    _buildHeader(context, ref),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'SELECT CATEGORY',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ReorderableListView(
                        onReorder: (oldIndex, newIndex) {
                          ref.read(categoryColorProvider.notifier).reorderCategories(oldIndex, newIndex);
                        },
                        buildDefaultDragHandles: false,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                        children: [
                          if (ref.watch(timerVisibleCategoriesProvider).isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Text('尚未新增項目，請點擊下方開始', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ),
                            ),
                          ...ref.watch(timerVisibleCategoriesProvider).asMap().entries.map((entry) {
                            final i = entry.key;
                            final cat = entry.value;
                            return Padding(
                              key: ValueKey('wide_$cat'),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildCategoryChip(context, ref, cat, ref.watch(timerProvider), i, isWide: true),
                            );
                          }),
                          ListTile(
                            key: const ValueKey('add_btn'),
                            onTap: () => showAddCategoryDialog(context, ref),
                            leading: const Icon(Icons.add_rounded),
                            title: const Text('新增分類'),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            tileColor: Theme.of(context).colorScheme.surface,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final timerNotifier = ref.read(timerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Me Time',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.5,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: timerNotifier.forceSync,
                icon: const Icon(Icons.sync, size: 18),
                tooltip: '手動同步雲端',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (ref.watch(firestoreServiceProvider) != null) const Icon(Icons.cloud_done, color: Colors.green, size: 14),
                    const SizedBox(width: 6),
                    Text('UID: ${timerNotifier.debugId}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary.withOpacity(0.6))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final visible = ref.watch(timerVisibleCategoriesProvider);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '項目列表 (可拖曳排序)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
              ),
              Row(
                children: [
                   IconButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('💡 秘訣：長按分類按鈕也能進行編輯'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    ),
                    icon: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                    tooltip: '編輯說明',
                  ),
                  IconButton(
                    onPressed: () => showAddCategoryDialog(context, ref),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 250), // Prevent too tall on mobile
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(), // Important for SingleChildScrollView
              onReorder: (oldIndex, newIndex) {
                 ref.read(categoryColorProvider.notifier).reorderCategories(oldIndex, newIndex);
              },
              padding: const EdgeInsets.all(8),
              children: visible.isEmpty 
                ? [
                    const Padding(
                      key: ValueKey('empty_prompt'),
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('尚未新增項目，點擊右上方＋開始', style: TextStyle(color: Colors.grey, fontSize: 13))),
                    )
                  ]
                : visible.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cat = entry.value;
                    return _buildCategoryChip(context, ref, cat, timerState, i, isWide: true);
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCategoryChip(BuildContext context, WidgetRef ref, String cat, TimerState timerState, int index, {bool isWide = false}) {
    final isSelected = timerState.category == cat;
    final catColor = ref.watch(categoryColorProvider)[cat] ?? Colors.grey.withOpacity(0.5);
    return Padding(
      key: ValueKey(isWide ? 'wide_$cat' : cat),
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => ref.read(timerProvider.notifier).changeCategory(cat),
        onLongPress: () => showCategoryOptions(context, cat, ref),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? catColor.withOpacity(0.9) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? catColor : Theme.of(context).colorScheme.outlineVariant,
              width: isSelected ? 0 : 1,
            ),
            boxShadow: isSelected ? [BoxShadow(color: catColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
          ),
          child: Row(
            children: [
              // Use Drag Handle
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.drag_indicator_rounded, color: (isSelected ? Colors.white : Colors.grey).withOpacity(0.5), size: 20),
                ),
              ),
              Expanded(
                child: Text(
                  cat,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected && timerState.currentElapsed > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(timerState.currentElapsed / 60).floor()}m',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerCard(BuildContext context, WidgetRef ref, {double scale = 1.0}) {
    final timerState = ref.watch(timerProvider);
    final timerColor = ref.watch(timerColorProvider);
    final sessions = ref.watch(sessionsProvider);
    
    final now = DateTime.now();
    int dailyBaseTotal = sessions.where((s) {
      final sDate = s.date.toLocal();
      return sDate.year == now.year && sDate.month == now.month && sDate.day == now.day;
    }).fold(0, (sum, s) => sum + s.durationSeconds);
    
    int realTimeDailyTotal = dailyBaseTotal + timerState.currentElapsed;

    final digitalStyle = GoogleFonts.shareTechMono(
      fontSize: 110 * scale,
      fontWeight: FontWeight.bold,
      color: timerColor,
      shadows: [if (timerState.isRunning) Shadow(color: timerColor.withOpacity(0.5), blurRadius: 25)],
    );

    return Container(
      margin: const EdgeInsets.all(24),
      padding: EdgeInsets.all(40 * scale),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: timerColor.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'SESSION TIME',
              style: TextStyle(
                fontSize: 18 * scale,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(_formatTime(timerState.currentElapsed), style: digitalStyle)),
          SizedBox(height: 24 * scale),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.today, size: 18, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text('今日累計: ', style: TextStyle(fontSize: 15 * scale, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6))),
                  Text(_formatTime(realTimeDailyTotal), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * scale)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);
    final timerColor = ref.watch(timerColorProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 30.0), // Reduced from 60.0 to prevent clipping
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (timerState.currentElapsed > 0)
            IconButton.filledTonal(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('重置計時'),
                    content: const Text('確定要清除目前的計時數據嗎？這不會儲存到歷史紀錄中。'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      TextButton(
                        onPressed: () {
                          timerNotifier.resetTimer();
                          Navigator.pop(ctx);
                        },
                        child: const Text('確定重置', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.refresh_rounded, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.withOpacity(0.12),
                foregroundColor: Colors.grey,
                padding: const EdgeInsets.all(16),
              ),
              tooltip: '重置清除',
            )
          else
            const SizedBox(width: 60),

          const SizedBox(width: 40),

          GestureDetector(
            onTap: timerNotifier.toggleTimer,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: timerState.isRunning ? Colors.transparent : timerColor,
                border: timerState.isRunning ? Border.all(color: timerColor, width: 4) : null,
                boxShadow: [
                  if (!timerState.isRunning) 
                    BoxShadow(color: timerColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Icon(
                timerState.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 52,
                color: timerState.isRunning ? timerColor : Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 40),

          if (timerState.currentElapsed > 0)
            IconButton.filledTonal(
              onPressed: timerNotifier.stopAndSave,
              icon: const Icon(Icons.stop_rounded, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.12),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.all(16),
              ),
              tooltip: '結束並儲存',
            )
          else
            const SizedBox(width: 60),
        ],
      ),
    );
  }
}
