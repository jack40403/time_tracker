import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../services/goal_progress_service.dart';
import 'goal_order_provider.dart';
import 'goal_provider.dart';
import 'session_provider.dart';
import 'task_goal_provider.dart';
import 'timer_provider.dart';

/// The single source of truth for goals shown on the focus-goals screen.
final currentFocusGoalsProvider = Provider<List<Goal>>((ref) {
  final goals = <Goal>[
    ...ref.watch(visibleTimeGoalsProvider),
    ...ref.watch(visibleTaskGoalsProvider),
  ];
  final order = ref.watch(goalOrderProvider);
  final now = DateTime.now();

  final visible = goals.where((goal) {
    return !GoalProgressService.isBeforeGoalStart(goal, now);
  }).toList();

  final byId = {for (final goal in visible) goal.id: goal};
  final sorted = <Goal>[];
  for (final id in order) {
    final goal = byId.remove(id);
    if (goal != null) sorted.add(goal);
  }
  sorted.addAll(byId.values);
  return sorted;
});

final currentFocusGoalProgressProvider = Provider<List<GoalProgress>>((ref) {
  final goals = ref.watch(currentFocusGoalsProvider);
  final sessions = ref.watch(sessionsProvider);
  final timer = ref.watch(timerProvider);
  final now = DateTime.now();
  final runningTimer = RunningTimerSnapshot(
    isRunning: timer.isRunning,
    category: timer.category,
    startTime: timer.startTime,
    baseSeconds: timer.baseSeconds,
    currentElapsed: timer.currentElapsed,
  );

  return goals
      .map((goal) => GoalProgressService.buildProgress(
            goal: goal,
            now: now,
            sessions: sessions,
            runningTimer: runningTimer,
          ))
      .toList();
});

final incompleteFocusGoalProgressProvider = Provider<List<GoalProgress>>((ref) {
  return ref
      .watch(currentFocusGoalProgressProvider)
      .where((progress) => !progress.isCompleted)
      .toList();
});
