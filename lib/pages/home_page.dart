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
import '../theme/app_themes.dart';
import '../providers/app_theme_provider.dart';

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
    final t = ref.watch(currentAppThemeProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildWideLayout(context, ref, constraints, t);
          } else {
            return _buildMobileLayout(context, ref, constraints, t);
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, WidgetRef ref, BoxConstraints constraints, AppTheme t) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        SliverToBoxAdapter(child: _buildHeader(context, ref, t)),
        SliverToBoxAdapter(child: const SizedBox(height: 16)),
        SliverToBoxAdapter(child: _buildCategoryList(context, ref, t)),
        SliverToBoxAdapter(child: const SizedBox(height: 10)),
        SliverToBoxAdapter(child: _buildTimerCard(context, ref, t)),
        SliverToBoxAdapter(child: _buildActionButtons(context, ref, t)),
        SliverToBoxAdapter(child: const SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context, WidgetRef ref, BoxConstraints constraints, AppTheme t) {
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
                    _buildTimerCard(context, ref, t, scale: 1.1),
                    const SizedBox(height: 12),
                    _buildActionButtons(context, ref, t),
                  ],
                ),
              ),
            ),
            Container(width: 3, height: constraints.maxHeight, color: t.ink.withOpacity(0.2)),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  _buildHeader(context, ref, t),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'SELECT CATEGORY',
                      style: GoogleFonts.getFont(
                        t.fontBody,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: t.mute,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryList(context, ref, t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, AppTheme t) {
    final timerNotifier = ref.read(timerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Me Time',
            style: GoogleFonts.getFont(
              t.fontDisplay,
              fontSize: ResponsiveHelper.sp(context, 24),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: t.appBarInk,
            ),
          ),
          GestureDetector(
            onTap: timerNotifier.forceSync,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.appBarInk.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.appBarInk.withOpacity(0.4), width: 2),
              ),
              child: Icon(Icons.sync_rounded, size: 20, color: t.appBarInk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, WidgetRef ref, AppTheme t) {
    final selectedCategory = ref.watch(timerProvider.select((s) => s.category));
    final visible = ref.watch(timerVisibleCategoriesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ThemedSectionLabel(
            text: 'Category List (drag to reorder)',
            textColor: t.mute,
            trailing: Row(
              children: [
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Long press a category to edit it.')),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: t.appBarInk.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.appBarInk.withOpacity(0.4), width: 1.5),
                    ),
                    child: Icon(Icons.info_outline_rounded, size: 16, color: t.appBarInk),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => showAddCategoryDialog(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: t.action,
                      borderRadius: BorderRadius.circular(8),
                      border: t.borderW > 0 ? Border.all(color: t.border, width: 2) : null,
                      boxShadow: t.shadowOffset != Offset.zero
                          ? [BoxShadow(color: t.shadowColor, offset: const Offset(2, 2))]
                          : null,
                    ),
                    child: Icon(Icons.add_rounded, size: 16, color: t.actionInk),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: t.surface.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.ink.withOpacity(0.25), width: 2.5),
            ),
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                ref.read(categoryColorProvider.notifier).reorderCategories(
                  oldIndex,
                  newIndex,
                  reorderableCategories: visible,
                );
              },
              padding: const EdgeInsets.all(8),
              children: [
                for (final entry in visible.asMap().entries)
                  _buildCategoryChip(context, ref, entry.value, selectedCategory == entry.value, entry.key, t),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No categories yet. Tap + to add one.',
                        style: TextStyle(color: t.mute, fontSize: 13),
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

  Widget _buildCategoryChip(BuildContext context, WidgetRef ref, String cat, bool isSelected, int index, AppTheme t) {
    final catColor = ref.watch(categoryColorProvider)[cat] ?? Colors.grey;
    final timerNotifier = ref.read(timerProvider.notifier);

    return Padding(
      key: ValueKey(cat),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            final timerState = ref.read(timerProvider);
            if (timerState.isRunning) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('請先暫停或停止計時，再切換項目。')),
              );
              return;
            }
            timerNotifier.changeCategory(cat);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: chipDecoration(t, selected: isSelected).copyWith(
              color: isSelected ? catColor : t.chipBg,
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: isSelected ? t.ink.withOpacity(0.4) : Colors.grey.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    cat,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? t.chipInkSel : t.chipInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isSelected)
                  Consumer(
                    builder: (context, ref, _) {
                      final elapsed = ref.watch(timerProvider.select((s) => s.currentElapsed));
                      if (elapsed <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.surface.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t.surface.withOpacity(0.4), width: 1),
                        ),
                        child: Text(
                          '${(elapsed / 60).floor()}m',
                          style: TextStyle(fontSize: 11, color: t.chipInkSel, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildTimerCard(BuildContext context, WidgetRef ref, AppTheme t, {double scale = 1.0}) {
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

    final effectiveTimerColor = timerColor != CartoonTheme.goldenOrange ? timerColor : (t.timerInk ?? t.accent);
    final digitalStyle = GoogleFonts.getFont(
      t.fontTimer,
      fontSize: 96 * displayScale,
      fontWeight: FontWeight.w700,
      color: effectiveTimerColor,
      shadows: [
        const Shadow(color: Color(0x22000000), offset: Offset(3, 3), blurRadius: 0),
        if (timerState.isRunning && t.timerHaloOn)
          Shadow(color: t.accentSoft, blurRadius: 24),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: EdgeInsets.all(32 * scale),
      decoration: cardDecoration(t).copyWith(
        borderRadius: BorderRadius.circular(40),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (timerState.isRunning && t.timerHaloOn)
            Container(
              width: 180 * displayScale,
              height: 180 * displayScale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [t.accentSoft, Colors.transparent]),
              ),
            ),
          Text(
            timerState.isRunning ? t.runningLabel : t.timerLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.getFont(
              t.fontDisplay,
              fontSize: ResponsiveHelper.sp(context, 18) * scale,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: t.accent,
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
              color: t.ink.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.ink.withOpacity(0.12), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_rounded, size: 18, color: t.mute),
                const SizedBox(width: 8),
                Text(
                  '今天已累積',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.sp(context, 14) * scale,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(realTimeDailyTotal),
                  style: GoogleFonts.getFont(
                    t.fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: ResponsiveHelper.sp(context, 18) * scale,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, AppTheme t) {
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
                decoration: cardDecoration(t, color: t.surfaceAlt).copyWith(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.refresh_rounded, size: 26, color: t.mute),
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
                onTap: () {
                  if (!timerState.isRunning && timerState.category == '尚未選擇項目') {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('請先選擇一個項目再開始計時'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ));
                    return;
                  }
                  timerNotifier.toggleTimer();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 100, height: 100,
                  decoration: buttonDecoration(t),
                  child: Icon(
                    timerState.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 58,
                    color: t.actionInk,
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
                decoration: cardDecoration(t, color: const Color(0xFFFF5252)).copyWith(
                  borderRadius: BorderRadius.circular(18),
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
              backgroundColor: const Color(0xFFFFD60A),
              foregroundColor: const Color(0xFF1A1A2E),
              side: const BorderSide(color: Color(0xFF1A1A2E), width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('完成並儲存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ThemedSectionLabel extends StatelessWidget {
  final String text;
  final Color textColor;
  final Widget? trailing;
  const _ThemedSectionLabel({required this.text, required this.textColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: textColor),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
