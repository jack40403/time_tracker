import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../services/goal_progress_service.dart';
import '../services/goal_reminder_notification_service.dart';
import '../services/goal_action_service.dart';
import 'current_focus_goals_provider.dart';
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
    final allProgresses = ref.watch(currentFocusGoalProgressProvider);
    final progresses = ref.watch(incompleteFocusGoalProgressProvider);
    _totalGoals = allProgresses.length;
    _lastDateKey ??= GoalProgressService.dateKey(DateTime.now());

    _ensurePendingActionPoller();

    _schedulePendingActionProcessing();
    _scheduleNotificationRefresh(progresses);
    return progresses;
  }

  Future<void> refreshNow() async {
    final progresses = state;
    await GoalReminderNotificationService.showOngoing(
      progresses,
      totalGoals: _totalGoals,
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
      _scheduleNotificationRefresh(state);
    });
    ref.onDispose(() {
      _pendingActionPoller?.cancel();
      _pendingActionPoller = null;
    });
  }

  void _scheduleNotificationRefresh(List<GoalProgress> progresses) {
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
          totalGoals: _totalGoals,
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

  Future<void> _applyAction(GoalReminderAction action) async {
    final taskGoals = ref.read(taskGoalProvider);
    Goal? goal;
    for (final candidate in taskGoals) {
      if (candidate.id == action.goalId) {
        goal = candidate;
        break;
      }
    }
    if (goal == null) return;

    final now = DateTime.now();
    final todayKey = GoalProgressService.dateKey(now);
    final current = goal.completionHistory[todayKey] ?? 0;
    final notifier = ref.read(taskGoalProvider.notifier);

    if (action.action == 'complete' && goal.type == GoalType.binary) {
      await notifier.setManualValue(goal.id, now, 1);
      return;
    }

    if (goal.type != GoalType.task) return;
    if (action.action == 'increment') {
      await notifier.setManualValue(goal.id, now, current + 1);
    } else if (action.action == 'decrement') {
      await notifier.setManualValue(goal.id, now, current > 0 ? current - 1 : 0);
    }
  }
}

final goalReminderProvider =
    NotifierProvider<GoalReminderNotifier, List<GoalProgress>>(
  () => GoalReminderNotifier(),
);
