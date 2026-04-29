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
import '../theme/cartoon_theme.dart';

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
            Container(width: 3, height: constraints.maxHeight, color: CartoonTheme.inkBlack.withOpacity(0.2)),
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
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryList(context, ref),
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
          Text(
            'Me Time',
            style: GoogleFonts.fredoka(
              fontSize: ResponsiveHelper.sp(context, 24),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          GestureDetector(
            onTap: timerNotifier.forceSync,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
              ),
              child: const Icon(Icons.sync_rounded, size: 20, color: Colors.white),
            ),
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
          CartoonSectionLabel(
            text: '項目列表 (可拖曳排序)',
            trailing: Row(
              children: [
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('💡 長按分類按鈕也能進行編輯')),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    ),
                    child: const Icon(Icons.info_outline_rounded, size: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => showAddCategoryDialog(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: CartoonTheme.sunYellow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CartoonTheme.inkBlack, width: 2),
                      boxShadow: const [BoxShadow(color: CartoonTheme.inkBlack, offset: Offset(2, 2))],
                    ),
                    child: const Icon(Icons.add_rounded, size: 16, color: CartoonTheme.inkBlack),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: CartoonTheme.panelDecoration(),
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                ref.read(categoryColorProvider.notifier).reorderCategories(oldIndex, newIndex);
              },
              padding: const EdgeInsets.all(8),
              children: [
                ...visible.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cat = entry.value;
                  return _buildCategoryChip(context, ref, cat, timerState, i);
                }),
                if (visible.isEmpty)
                  const Padding(
                    key: ValueKey('empty_prompt'),
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        '尚未新增項目，點擊上方＋號',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, WidgetRef ref, String cat, TimerState timerState, int index) {
    final isSelected = timerState.category == cat;
    final catColor = ref.watch(categoryColorProvider)[cat] ?? Colors.grey;

    return Padding(
      key: ValueKey(cat),
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => ref.read(timerProvider.notifier).changeCategory(cat),
        onLongPress: () => showCategoryOptions(context, cat, ref),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: CartoonTheme.chipDecoration(isSelected: isSelected, activeColor: catColor),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: isSelected ? CartoonTheme.inkBlack.withOpacity(0.4) : Colors.grey.withOpacity(0.5),
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  cat,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : CartoonTheme.inkBlack,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isSelected && timerState.currentElapsed > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
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
      fontSize: 96 * displayScale,
      fontWeight: FontWeight.w700,
      color: CartoonTheme.goldenOrange,
      shadows: [
        const Shadow(color: Color(0x22000000), offset: Offset(3, 3), blurRadius: 0),
        if (timerState.isRunning)
          Shadow(color: CartoonTheme.warmYellow.withOpacity(0.5), blurRadius: 24),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: EdgeInsets.all(32 * scale),
      decoration: CartoonTheme.cardDecoration(
        color: CartoonTheme.creamWhite,
        radius: 40,
        borderWidth: 4,
        shadowOffset: 6,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timerState.isRunning ? 'GO GO GO! 🎯' : 'ME TIME ⏱',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              fontSize: ResponsiveHelper.sp(context, 18) * scale,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: CartoonTheme.warmYellow,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_formatTime(timerState.currentElapsed), style: digitalStyle),
          ),
          SizedBox(height: 20 * scale),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: CartoonTheme.inkBlack.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CartoonTheme.inkBlack.withOpacity(0.12), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_rounded, size: 18, color: Color(0xFF555555)),
                const SizedBox(width: 8),
                Text(
                  '今天已累積',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.sp(context, 14) * scale,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF444444),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(realTimeDailyTotal),
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.w700,
                    fontSize: ResponsiveHelper.sp(context, 18) * scale,
                    color: CartoonTheme.inkBlack,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 30.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reset button
          if (timerState.currentElapsed > 0)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('重置計時', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text('確定要清除目前的計時數據嗎？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      TextButton(
                        onPressed: () {
                          timerNotifier.resetTimer();
                          Navigator.pop(ctx);
                        },
                        child: const Text('確定重置', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                width: 58, height: 58,
                decoration: CartoonTheme.cardDecoration(
                  color: CartoonTheme.softGrey,
                  radius: 18,
                  borderWidth: 3,
                  shadowOffset: 3,
                ),
                child: const Icon(Icons.refresh_rounded, size: 26, color: Color(0xFF888888)),
              ),
            )
          else
            const SizedBox(width: 58),

          const SizedBox(width: 36),

          // Play / Pause button
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 500),
            tween: Tween<double>(begin: 1.0, end: timerState.isRunning ? 1.06 : 1.0),
            curve: Curves.elasticOut,
            builder: (context, scaleValue, child) => Transform.scale(
              scale: scaleValue,
              child: GestureDetector(
                onTap: timerNotifier.toggleTimer,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 100, height: 100,
                  decoration: CartoonTheme.buttonDecoration(
                    color: timerState.isRunning ? Colors.white : CartoonTheme.sunYellow,
                    radius: 50,
                    borderWidth: 4,
                    shadowOffset: 5,
                  ),
                  child: Icon(
                    timerState.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 58,
                    color: timerState.isRunning ? CartoonTheme.inkBlack : CartoonTheme.inkBlack,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 36),

          // Stop & Save button
          if (timerState.currentElapsed > 0)
            GestureDetector(
              onTap: () => _showStopAndSaveDialog(context, ref),
              child: Container(
                width: 58, height: 58,
                decoration: CartoonTheme.cardDecoration(
                  color: CartoonTheme.softRed,
                  radius: 18,
                  borderWidth: 3,
                  shadowOffset: 3,
                ),
                child: const Icon(Icons.stop_rounded, size: 30, color: Colors.white),
              ),
            )
          else
            const SizedBox(width: 58),
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
            Text('專注總時長: ${_formatTime(timerState.currentElapsed)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已儲存專注日誌 ✨')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CartoonTheme.sunYellow,
              foregroundColor: CartoonTheme.inkBlack,
              side: const BorderSide(color: CartoonTheme.inkBlack, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('完成並儲存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
