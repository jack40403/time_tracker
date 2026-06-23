import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../providers/focus_goal_provider.dart';
import '../providers/main_tab_provider.dart';
import '../services/goal_progress_service.dart';

class QuickFocusPanelPage extends ConsumerWidget {
  const QuickFocusPanelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(visibleReminderGoalsProvider);
    final completedCount = ref.watch(completedFocusGoalCountProvider);
    final totalCount = goals.length + completedCount;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('專注目標'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: (goals.isEmpty && completedCount == 0)
            ? const _EmptyState(
                title: '目前沒有可顯示的專注目標',
                message: '已封存、已停用或尚未啟用提醒的目標不會出現在這裡。',
              )
            : goals.isEmpty
                ? const _EmptyState(
                    title: '太棒了，全部完成',
                    message: '目前週期內的有效專注目標都已完成。',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _SummaryCard(
                        remainingCount: goals.length,
                        completedCount: completedCount,
                        totalCount: totalCount,
                      ),
                      const SizedBox(height: 12),
                      ...goals.map((progress) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _GoalActionCard(progress: progress),
                          )),
                    ],
                  ),
      ),
      backgroundColor: colorScheme.surface,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int remainingCount;
  final int completedCount;
  final int totalCount;

  const _SummaryCard({
    required this.remainingCount,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '專注目標',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '剩餘 $remainingCount 項｜完成 $completedCount / $totalCount',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalActionCard extends ConsumerWidget {
  final GoalProgress progress;

  const _GoalActionCard({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = progress.goal;
    final actions = ref.read(focusGoalActionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  goal.type == GoalType.binary
                      ? Icons.check_box_outline_blank_rounded
                      : goal.type == GoalType.task
                          ? Icons.add_task_rounded
                          : Icons.timer_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    GoalProgressService.displayTitle(goal),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              progress.valueText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 14),
            _buildActions(context, ref, actions, goal),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    FocusGoalActions actions,
    Goal goal,
  ) {
    switch (goal.type) {
      case GoalType.binary:
        return FilledButton.icon(
          onPressed: () => actions.complete(goal),
          icon: const Icon(Icons.check_rounded),
          label: const Text('完成'),
        );
      case GoalType.task:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => actions.decrement(goal),
                icon: const Icon(Icons.remove_rounded),
                label: const Text('-1'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => actions.increment(goal),
                icon: const Icon(Icons.add_rounded),
                label: const Text('+1'),
              ),
            ),
          ],
        );
      case GoalType.time:
        return FilledButton.icon(
          onPressed: () {
            ref.read(mainTabIndexProvider.notifier).setIndex(0);
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.timer_rounded),
          label: const Text('前往計時'),
        );
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_circle_rounded, size: 72, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
