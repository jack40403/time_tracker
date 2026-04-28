import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vibration/vibration.dart';
import '../providers/timer_provider.dart';
import '../providers/category_provider.dart';
import '../providers/session_provider.dart';
import '../providers/firestore_provider.dart';
import '../providers/layout_provider.dart';
import '../widgets/category_dialogs.dart';
import '../helpers/responsive_helper.dart';

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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        SliverToBoxAdapter(child: _buildHeader(context, ref)),
        SliverToBoxAdapter(child: const SizedBox(height: 16)),
        SliverToBoxAdapter(child: _buildCategoryList(context, ref)),
        SliverToBoxAdapter(child: const SizedBox(height: 10)),
        SliverToBoxAdapter(child: _buildTimerCard(context, ref)),
        SliverToBoxAdapter(child: _buildActionButtons(context, ref)),
        // Add padding at the bottom for navigation bar
        SliverToBoxAdapter(child: const SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context, WidgetRef ref, BoxConstraints constraints) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side: Main Timer Card & Actions
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    _buildTimerCard(context, ref, scale: 1.1),
                    const SizedBox(height: 12),
                    _buildActionButtons(context, ref),
                  ],
                ),
              ),
            ),
            // Vertical Divider
            Container(width: 1, height: constraints.maxHeight, color: Colors.white.withOpacity(0.1)),
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
                  _buildCategoryList(context, ref), // Use the component to keep consistent
                ],
              ),
            ),
          ],
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
                  fontSize: ResponsiveHelper.sp(context, 22),
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
          const SizedBox.shrink(),
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
                  fontSize: ResponsiveHelper.sp(context, 14),
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
            constraints: const BoxConstraints(maxHeight: 320), // 限制高度，避免佔用過多空間
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(), // 允許內部滑動
              onReorder: (oldIndex, newIndex) {
                 ref.read(categoryColorProvider.notifier).reorderCategories(oldIndex, newIndex);
              },
              padding: const EdgeInsets.all(8),
              children: [
                ...visible.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cat = entry.value;
                    return _buildCategoryChip(context, ref, cat, timerState, i, isWide: true);
                }),
                if (visible.isEmpty)
                   const Padding(
                      key: ValueKey('empty_prompt'),
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('尚未新增項目，點擊上方＋號', style: TextStyle(color: Colors.grey, fontSize: 13))),
                    ),
              ],
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

    final displayScale = scale * ResponsiveHelper.getTimerScale(context);

    final digitalStyle = GoogleFonts.fredoka(
      fontSize: 100 * displayScale,
      fontWeight: FontWeight.bold,
      color: timerColor,
      shadows: [
        Shadow(color: Colors.black.withOpacity(0.1), offset: const Offset(4, 4), blurRadius: 2),
        if (timerState.isRunning) Shadow(color: timerColor.withOpacity(0.4), blurRadius: 30),
      ],
    );

    return Container(
      margin: const EdgeInsets.all(24),
      padding: EdgeInsets.all(40 * scale),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.black, width: 4),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(8, 8)),
          BoxShadow(color: timerColor.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GO GO GO!',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontSize: ResponsiveHelper.sp(context, 20) * scale,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(fit: BoxFit.scaleDown, child: Text(_formatTime(timerState.currentElapsed), style: digitalStyle)),
              SizedBox(height: 24 * scale),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withOpacity(0.1), width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_rounded, size: 20, color: Colors.black54),
                      const SizedBox(width: 10),
                      Text('今天已累積', style: TextStyle(fontSize: ResponsiveHelper.sp(context, 15) * scale, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text(_formatTime(realTimeDailyTotal), style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: ResponsiveHelper.sp(context, 18) * scale)),
                    ],
                  ),
                ),
              ),
            ],
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

          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 600),
            tween: Tween<double>(begin: 1.0, end: timerState.isRunning ? 1.05 : 1.0),
            curve: Curves.elasticOut,
            builder: (context, scaleValue, child) => Transform.scale(
              scale: scaleValue,
              child: GestureDetector(
                onTap: () {
                   timerNotifier.toggleTimer();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: timerState.isRunning ? Colors.white : timerColor,
                    border: Border.all(color: Colors.black, width: 4),
                    boxShadow: [
                      const BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                      if (!timerState.isRunning) 
                        BoxShadow(color: timerColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Icon(
                    timerState.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 60,
                    color: timerState.isRunning ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 40),

          if (timerState.currentElapsed > 0)
            IconButton.filled(
              onPressed: () => _showStopAndSaveDialog(context, ref),
              icon: const Icon(Icons.stop_rounded, size: 30),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                side: const BorderSide(color: Colors.black, width: 3),
              ),
              tooltip: '結束並儲存',
            )
          else
            const SizedBox(width: 60),
        ],
      ),
    );
  }

  void _showStopAndSaveDialog(BuildContext context, WidgetRef ref) {
    final timerState = ref.read(timerProvider);
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('完成專注 / 紀錄日誌', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('類別: ${timerState.category}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('專注總時長: ${_formatTime(timerState.currentElapsed)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: noteController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '專注心得 / 日誌 (可不填)',
                hintText: '剛才的時間裡，你做了什麼有趣的紀錄嗎？',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              ref.read(timerProvider.notifier).stopAndSave(note: noteController.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存專注日誌 ✨')));
            }, 
            child: const Text('完成並儲存'),
          ),
        ],
      ),
    );
  }
}
