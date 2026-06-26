import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';
import 'current_focus_goals_provider.dart';
import 'focus_goal_provider.dart';
import '../services/goal_progress_service.dart';
import '../services/goal_action_service.dart';
import '../services/goal_reminder_notification_service.dart';
import '../services/notification_service.dart';
import 'goal_provider.dart';
import 'task_goal_provider.dart';

class GoalReminderNotifier extends Notifier<List<GoalProgress>> {
  Timer? _pendingActionPoller;
  bool _processingActions = false;
  bool _refreshQueued = false;
  DateTime? _lastNotificationRefresh;
  int _totalGoals = 0;
  String? _lastDateKey;

  @override
  List<GoalProgress> build() {
    final allGoals = ref.watch(allFocusGoalsProvider);
    final visibleGoals = ref.watch(visibleFocusGoalsProvider);
    final allProgresses = ref.watch(focusGoalProgressProvider);
    final progresses = allProgresses.where((progress) => !progress.isCompleted).toList();
    final completedCount = allProgresses.length - progresses.length;

    debugPrint(
      'GoalReminderNotifier.build: '
      'allGoals=${allGoals.length}, visibleGoals=${visibleGoals.length}, '
      'allProgresses=${allProgresses.length}, remaining=${progresses.length}, completed=$completedCount',
    );

    _cancelHiddenGoalReminders(allGoals, visibleGoals);
    _ensurePendingActionPoller();
    _schedulePendingActionProcessing();
    _scheduleNotificationRefresh(
      progresses,
      totalCount: allProgresses.length,
      completedCount: completedCount,
    );
    return progresses;
  }

  Future<void> refreshNow() async {
    final allGoals = ref.read(allFocusGoalsProvider);
    final visibleGoals = ref.read(visibleFocusGoalsProvider);
    final allProgresses = ref.read(focusGoalProgressProvider);
    final progresses = allProgresses.where((progress) => !progress.isCompleted).toList();
    debugPrint(
      'GoalReminderNotifier.refreshNow: '
      'allGoals=${allGoals.length}, visibleGoals=${visibleGoals.length}, '
      'allProgresses=${allProgresses.length}, remaining=${progresses.length}',
    );
    _cancelHiddenGoalReminders(allGoals, visibleGoals);
    await GoalReminderNotificationService.showOngoing(
      progresses,
      totalCount: allProgresses.length,
      completedCount: allProgresses.length - progresses.length,
    );
    _lastNotificationRefresh = DateTime.now();
  }

  void _ensurePendingActionPoller() {
    if (_pendingActionPoller != null) return;
    _pendingActionPoller = Timer.periodic(const Duration(seconds: 1), (_) {
      final dateKey = GoalProgressService.dateKey(DateTime.now());
      if (dateKey != _lastDateKey) {
        _lastDateKey = dateKey;
        ref.invalidate(currentFocusGoalProgressProvider);
        ref.invalidate(incompleteFocusGoalProgressProvider);
      }
      _schedulePendingActionProcessing();
      final allProgresses = ref.read(focusGoalProgressProvider);
      _scheduleNotificationRefresh(
        state,
        totalCount: allProgresses.length,
        completedCount: allProgresses.length - state.length,
      );
    });
    ref.onDispose(() {
      _pendingActionPoller?.cancel();
      _pendingActionPoller = null;
    });
  }

  void _scheduleNotificationRefresh(
    List<GoalProgress> progresses, {
    required int totalCount,
    required int completedCount,
  }) {
    if (_refreshQueued) return;
    final now = DateTime.now();
    final last = _lastNotificationRefresh;
    if (last != null && now.difference(last) < const Duration(seconds: 1)) {
      return;
    }

    _refreshQueued = true;
    Future.microtask(() async {
      try {
        await GoalReminderNotificationService.showOngoing(
          progresses,
          totalCount: totalCount,
          completedCount: completedCount,
        );
        _lastNotificationRefresh = DateTime.now();
      } finally {
        _refreshQueued = false;
      }
    });
  }

  void _schedulePendingActionProcessing() {
    if (_processingActions) return;
    _processingActions = true;
    Future.microtask(() async {
      try {
        if (await GoalActionService.takeRefreshRequest()) {
          await ref.read(taskGoalProvider.notifier).reloadFromStorage();
        }
        final actions = await GoalReminderNotificationService.takePendingActions();
        if (actions.isEmpty) return;
        for (final action in actions) {
          await _applyAction(action);
        }
      } finally {
        _processingActions = false;
      }
    });
  }

  void _cancelHiddenGoalReminders(List<Goal> allGoals, List<Goal> visibleGoals) {
    final visibleIds = visibleGoals.map((goal) => goal.id).toSet();
    for (final goal in allGoals) {
      if (!goal.isReminderEnabled || goal.reminderTime == null) {
        unawaited(NotificationService.cancelGoalReminder(goal.id));
        continue;
      }
      if (!visibleIds.contains(goal.id)) {
        unawaited(NotificationService.cancelGoalReminder(goal.id));
      }
    }
  }

  Future<void> _applyAction(GoalReminderAction action) async {
    final allGoals = ref.read(allFocusGoalsProvider);
    Goal? goal;
    for (final candidate in allGoals) {
      if (candidate.id == action.goalId) {
        goal = candidate;
        break;
      }
    }
    if (goal == null) return;
    final selectedGoal = goal;

    final now = DateTime.now();
    final todayKey = GoalProgressService.dateKey(now);
    final current = selectedGoal.completionHistory[todayKey] ?? 0;
    final notifier = _goalNotifierFor(selectedGoal);

    if (action.action == 'complete' && selectedGoal.type == GoalType.binary) {
      await Future.sync(() => notifier.setManualValue(selectedGoal.id, now, 1));
      return;
    }

    if (selectedGoal.type != GoalType.task) return;
    if (action.action == 'increment') {
      await Future.sync(() => notifier.setManualValue(selectedGoal.id, now, current + 1));
    } else if (action.action == 'decrement') {
      await Future.sync(() => notifier.setManualValue(selectedGoal.id, now, current > 0 ? current - 1 : 0));
    }
  }

  dynamic _goalNotifierFor(Goal goal) {
    final taskGoals = ref.read(taskGoalProvider);
    final taskGoal = taskGoals.any((candidate) => candidate.id == goal.id);
    if (taskGoal) {
      return ref.read(taskGoalProvider.notifier);
    }
    return ref.read(goalProvider.notifier);
  }
}

final goalReminderProvider =
    NotifierProvider<GoalReminderNotifier, List<GoalProgress>>(
  () => GoalReminderNotifier(),
);
