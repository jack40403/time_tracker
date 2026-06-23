import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../services/goal_progress_service.dart';
import 'category_provider.dart';
import 'goal_provider.dart';
import 'session_provider.dart';
import 'task_goal_provider.dart';
import 'timer_provider.dart';

final allFocusGoalsProvider = Provider<List<Goal>>((ref) {
  final timeGoals = ref.watch(goalProvider);
  final taskGoals = ref.watch(taskGoalProvider);
  return GoalProgressService.uniqueGoalsById([
    ...timeGoals,
    ...taskGoals,
  ]);
});

final visibleFocusGoalsProvider = Provider<List<Goal>>((ref) {
  final goals = ref.watch(allFocusGoalsProvider);
  final hiddenCategories = ref.watch(hiddenCategoriesProvider);
  final goalsHiddenCategories = ref.watch(goalsHiddenCategoriesProvider);
  final visible = GoalProgressService.getVisibleReminderGoals(
    goals: goals,
    hiddenCategories: hiddenCategories,
    goalsHiddenCategories: goalsHiddenCategories,
    now: DateTime.now(),
  );
  debugPrint(
    'FocusGoalProvider.visibleFocusGoals: raw=${goals.length}, visible=${visible.length}, '
    'hiddenGlobal=${hiddenCategories.length}, hiddenGoals=${goalsHiddenCategories.length}',
  );
  return visible;
});

final focusGoalProgressProvider = Provider<List<GoalProgress>>((ref) {
  final goals = ref.watch(visibleFocusGoalsProvider);
  final sessions = ref.watch(sessionsProvider);
  final timerState = ref.watch(timerProvider);
  final now = DateTime.now();

  final progresses = GoalProgressService.getGoalProgressForCurrentPeriod(
    goals: goals,
    sessions: sessions,
    now: now,
    runningTimer: RunningTimerSnapshot(
      isRunning: timerState.isRunning,
      category: timerState.category,
      startTime: timerState.startTime,
      baseSeconds: timerState.baseSeconds,
      currentElapsed: timerState.currentElapsed,
    ),
    debugLabel: 'focusGoalProgress',
  );

  progresses.sort((a, b) {
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }
    final progressCompare = b.progress.compareTo(a.progress);
    if (progressCompare != 0) return progressCompare;
    return a.goal.createdAt.compareTo(b.goal.createdAt);
  });
  return progresses;
});

final visibleReminderGoalsProvider = Provider<List<GoalProgress>>((ref) {
  return ref
      .watch(focusGoalProgressProvider)
      .where((progress) => !progress.isCompleted)
      .toList();
});

final completedFocusGoalCountProvider = Provider<int>((ref) {
  return ref
      .watch(focusGoalProgressProvider)
      .where((progress) => progress.isCompleted)
      .length;
});

final focusGoalActionsProvider =
    Provider<FocusGoalActions>((ref) => FocusGoalActions(ref));

class FocusGoalActions {
  final Ref _ref;

  FocusGoalActions(this._ref);

  void complete(Goal goal) {
    if (goal.type == GoalType.time) return;
    final now = DateTime.now();
    if (_isTaskBackedGoal(goal)) {
      _ref.read(taskGoalProvider.notifier).setManualValue(
            goal.id,
            now,
            GoalProgressService.targetValue(goal),
          );
      return;
    }

    _ref.read(goalProvider.notifier).setManualValue(
          goal.id,
          now,
          GoalProgressService.targetValue(goal),
        );
  }

  void increment(Goal goal) {
    _setCounterValue(goal, delta: 1);
  }

  void decrement(Goal goal) {
    _setCounterValue(goal, delta: -1);
  }

  void _setCounterValue(Goal goal, {required int delta}) {
    if (goal.type != GoalType.task) return;
    final now = DateTime.now();
    final date = delta >= 0 ? now : _latestEditableDate(goal, now);
    final dateKey = GoalProgressService.dateKey(date);
    final currentForDate = goal.completionHistory[dateKey] ?? 0;
    final next = (currentForDate + delta).clamp(0, currentForDate + 1).toInt();

    if (_isTaskBackedGoal(goal)) {
      _ref.read(taskGoalProvider.notifier).setManualValue(goal.id, date, next);
      return;
    }
    _ref.read(goalProvider.notifier).setManualValue(goal.id, date, next);
  }

  DateTime _latestEditableDate(Goal goal, DateTime now) {
    final periodStart = _periodStart(goal.period, now);
    final start = goal.startDate.isAfter(periodStart) ? goal.startDate : periodStart;
    DateTime? latest;
    for (final entry in goal.completionHistory.entries) {
      final date = DateTime.tryParse(entry.key.replaceAll('/', '-'));
      if (date == null || entry.value <= 0) continue;
      if (date.isBefore(_dayStart(start))) continue;
      if (date.isAfter(_dayStart(now))) continue;
      if (latest == null || date.isAfter(latest)) latest = date;
    }
    return latest ?? now;
  }

  DateTime _periodStart(GoalPeriod period, DateTime date) {
    final local = date.toLocal();
    switch (period) {
      case GoalPeriod.daily:
        return DateTime(local.year, local.month, local.day);
      case GoalPeriod.weekly:
        final startOfDay = DateTime(local.year, local.month, local.day);
        return startOfDay.subtract(Duration(days: local.weekday - 1));
      case GoalPeriod.monthly:
        return DateTime(local.year, local.month);
      case GoalPeriod.yearly:
        return DateTime(local.year);
    }
  }

  DateTime _dayStart(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _isTaskBackedGoal(Goal goal) {
    return _ref.read(taskGoalProvider).any((candidate) => candidate.id == goal.id);
  }
}
