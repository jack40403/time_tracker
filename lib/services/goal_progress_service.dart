import 'package:flutter/foundation.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../models/time_session.dart';

class GoalProgressService {
  static List<Goal> uniqueGoalsById(Iterable<Goal> goals) {
    final unique = <String, Goal>{};
    for (final goal in goals) {
      if (goal.id.isEmpty) continue;
      final existing = unique[goal.id];
      if (existing == null || goal.updatedAt.isAfter(existing.updatedAt)) {
        unique[goal.id] = goal;
      }
    }
    return unique.values.toList();
  }

  static String getCurrentPeriodKey(Goal goal, DateTime now) {
    final range = _periodRange(goal.period, now);
    switch (goal.period) {
      case GoalPeriod.daily:
        return _dateKey(range.start);
      case GoalPeriod.weekly:
        final week = _isoWeekNumber(range.start);
        final weekYear = _isoWeekYear(range.start);
        return '$weekYear-W${week.toString().padLeft(2, '0')}';
      case GoalPeriod.monthly:
        return '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}';
      case GoalPeriod.yearly:
        return '${range.start.year}';
    }
  }

  static int getGoalCurrentValue({
    required Goal goal,
    required DateTime now,
    required List<TimeSession> sessions,
    RunningTimerSnapshot? runningTimer,
  }) {
    if (!goal.isActive || isBeforeGoalStart(goal, now)) return 0;

    final range = _periodRange(goal.period, now);
    final goalStart = _taipeiDay(goal.startDate);
    final effectiveStart = _maxDateTime(range.start, goalStart);
    final nowTaipei = _taipeiCivil(now);
    final effectiveEnd = _minDateTime(range.endExclusive, nowTaipei);
    if (!effectiveStart.isBefore(effectiveEnd) && !_sameMoment(effectiveStart, effectiveEnd)) {
      return 0;
    }

    if (goal.type == GoalType.time) {
      var total = 0;
      for (final session in sessions) {
        final sessionDate = _taipeiCivil(session.date);
        if (session.category != goal.category) continue;
        if (sessionDate.isBefore(effectiveStart)) continue;
        if (!sessionDate.isBefore(effectiveEnd.add(const Duration(milliseconds: 1)))) continue;
        total += session.durationSeconds;
      }
      total += _runningTimerSeconds(goal, runningTimer, effectiveStart, effectiveEnd);
      return total;
    }

    var total = 0;
    for (final entry in goal.completionHistory.entries) {
      final date = _parseHistoryDate(entry.key);
      if (date == null) continue;
      if (date.isBefore(_dayStart(effectiveStart))) continue;
      if (!date.isBefore(_dayStart(range.endExclusive))) continue;
      if (date.isAfter(_dayStart(now))) continue;
      total += entry.value;
    }

    if (goal.type == GoalType.binary) return total > 0 ? 1 : 0;
    return total;
  }

  static bool isGoalCompletedForCurrentPeriod({
    required Goal goal,
    required DateTime now,
    required List<TimeSession> sessions,
    RunningTimerSnapshot? runningTimer,
  }) {
    final value = getGoalCurrentValue(
      goal: goal,
      now: now,
      sessions: sessions,
      runningTimer: runningTimer,
    );
    return value >= targetValue(goal);
  }

  static List<GoalProgress> getGoalProgressForCurrentPeriod({
    required List<Goal> goals,
    required List<TimeSession> sessions,
    required DateTime now,
    RunningTimerSnapshot? runningTimer,
    String? debugLabel,
  }) {
    final allGoals = uniqueGoalsById(goals.where((goal) => goal.isActive));

    final progresses = allGoals
        .map((goal) => buildProgress(
              goal: goal,
              now: now,
              sessions: sessions,
              runningTimer: runningTimer,
            ))
        .toList();

    progresses.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      final progressCompare = b.progress.compareTo(a.progress);
      if (progressCompare != 0) return progressCompare;
      return a.goal.createdAt.compareTo(b.goal.createdAt);
    });

    if (debugLabel != null) {
      debugPrint(
        'GoalProgressService.$debugLabel: '
        'input=${goals.length}, unique=${allGoals.length}, '
        'progress=${progresses.length}, completed=${progresses.where((p) => p.isCompleted).length}',
      );
    }
    return progresses;
  }

  static List<Goal> getVisibleReminderGoals({
    required List<Goal> goals,
    required Set<String> hiddenCategories,
    required Set<String> goalsHiddenCategories,
    required DateTime now,
  }) {
    final rawGoals = goals.toList();
    final uniqueGoals = uniqueGoalsById(rawGoals);
    final activeGoals = uniqueGoals.where((goal) => goal.isActive).toList();
    final visibleGoals = activeGoals.where((goal) {
      if (hiddenCategories.contains(goal.category)) return false;
      if (goalsHiddenCategories.contains(goal.category)) return false;
      return !now.isBefore(_dayStart(goal.startDate));
    }).toList();

    debugPrint(
      'GoalProgressService.getVisibleReminderGoals: '
      'raw=${rawGoals.length}, unique=${uniqueGoals.length}, '
      'active=${activeGoals.length}, visible=${visibleGoals.length}, '
      'hiddenGlobal=${hiddenCategories.length}, hiddenGoals=${goalsHiddenCategories.length}',
    );

    return visibleGoals;
  }

  static List<GoalProgress> getCurrentFocusGoals({
    required List<Goal> timeGoals,
    required List<Goal> taskGoals,
    required List<TimeSession> sessions,
    required DateTime now,
    RunningTimerSnapshot? runningTimer,
  }) {
    return getGoalProgressForCurrentPeriod(
      goals: [
        ...timeGoals,
        ...taskGoals,
      ],
      sessions: sessions,
      now: now,
      runningTimer: runningTimer,
    );
  }

  static List<GoalProgress> getVisibleReminderGoalsProgress({
    required List<Goal> goals,
    required Set<String> hiddenCategories,
    required Set<String> goalsHiddenCategories,
    required List<TimeSession> sessions,
    required DateTime now,
    RunningTimerSnapshot? runningTimer,
  }) {
    final visibleGoals = getVisibleReminderGoals(
      goals: goals,
      hiddenCategories: hiddenCategories,
      goalsHiddenCategories: goalsHiddenCategories,
      now: now,
    );
    final progresses = getGoalProgressForCurrentPeriod(
      goals: visibleGoals,
      sessions: sessions,
      now: now,
      runningTimer: runningTimer,
    ).where((progress) => !progress.isCompleted).toList();

    progresses.sort((a, b) {
      final progressCompare = b.progress.compareTo(a.progress);
      if (progressCompare != 0) return progressCompare;
      return a.goal.createdAt.compareTo(b.goal.createdAt);
    });
    return progresses;
  }

  static GoalProgress buildProgress({
    required Goal goal,
    required DateTime now,
    required List<TimeSession> sessions,
    RunningTimerSnapshot? runningTimer,
  }) {
    final range = _periodRange(goal.period, now);
    final current = getGoalCurrentValue(
      goal: goal,
      now: now,
      sessions: sessions,
      runningTimer: runningTimer,
    );
    final target = targetValue(goal);
    final progress = target <= 0 ? 1.0 : (current / target).clamp(0.0, 1.0);

    return GoalProgress(
      goal: goal,
      periodKey: getCurrentPeriodKey(goal, now),
      periodStart: range.start,
      periodEndExclusive: range.endExclusive,
      currentValue: current,
      targetValue: target,
      progress: progress,
      isCompleted: current >= target,
      valueText: _formatValue(goal, current, target),
      remainingText: _formatRemaining(goal, target - current),
    );
  }

  static Map<String, String> buildRecords({
    required Goal goal,
    required DateTime now,
    required List<TimeSession> sessions,
    RunningTimerSnapshot? runningTimer,
  }) {
    final completedPeriods = _completedPeriodKeys(
      goal: goal,
      now: now,
      sessions: sessions,
      runningTimer: runningTimer,
    );
    final historical = _longestCompletedStreak(
      goal: goal,
      now: now,
      completedKeys: completedPeriods,
    );
    final monthly = _longestCompletedStreak(
      goal: goal,
      now: now,
      completedKeys: completedPeriods,
      restrictToCurrentMonth: true,
    );

    return {
      'historical': '$historical',
      'monthly': '$monthly',
    };
  }

  static String dateKey(DateTime date) => _dateKey(date);

  static int targetValue(Goal goal) {
    if (goal.type == GoalType.binary) return 1;
    return goal.targetSeconds <= 0 ? 1 : goal.targetSeconds;
  }

  static bool isBeforeGoalStart(Goal goal, DateTime now) {
    return _taipeiCivil(now).isBefore(_taipeiDay(goal.startDate));
  }

  static String displayTitle(Goal goal) {
    final title = goal.title.trim().isEmpty ? goal.category : goal.title.trim();
    final suffix = periodTitleSuffix(goal.period);
    return suffix.isEmpty ? title : '$title$suffix';
  }

  static String periodTitleSuffix(GoalPeriod period) {
    switch (period) {
      case GoalPeriod.daily:
        return '';
      case GoalPeriod.weekly:
        return '（每週）';
      case GoalPeriod.monthly:
        return '（每月）';
      case GoalPeriod.yearly:
        return '（每年）';
    }
  }

  static String periodProgressLabel(GoalPeriod period) {
    switch (period) {
      case GoalPeriod.daily:
        return '今日';
      case GoalPeriod.weekly:
        return '本週';
      case GoalPeriod.monthly:
        return '本月';
      case GoalPeriod.yearly:
        return '本年';
    }
  }

  static int _runningTimerSeconds(
    Goal goal,
    RunningTimerSnapshot? runningTimer,
    DateTime effectiveStart,
    DateTime effectiveEnd,
  ) {
    if (runningTimer == null || !runningTimer.isRunning) return 0;
    if (runningTimer.category != goal.category) return 0;
    if (runningTimer.startTime == null) return runningTimer.currentElapsed;

    final started = _taipeiCivil(runningTimer.startTime!);
    if (!started.isBefore(effectiveEnd)) return 0;

    final liveStart = _maxDateTime(started, effectiveStart);
    final liveSeconds = effectiveEnd.difference(liveStart).inSeconds;
    if (liveSeconds <= 0) return 0;

    if (!started.isBefore(effectiveStart)) {
      return runningTimer.baseSeconds + liveSeconds;
    }
    return liveSeconds;
  }

  static _PeriodRange _periodRange(GoalPeriod period, DateTime date) {
    final local = _taipeiCivil(date);
    switch (period) {
      case GoalPeriod.daily:
        final start = _taipeiDay(local);
        return _PeriodRange(start, start.add(const Duration(days: 1)));
      case GoalPeriod.weekly:
        final startOfDay = _taipeiDay(local);
        final start = startOfDay.subtract(Duration(days: local.weekday - 1));
        return _PeriodRange(start, start.add(const Duration(days: 7)));
      case GoalPeriod.monthly:
        final start = DateTime(local.year, local.month);
        return _PeriodRange(start, DateTime(local.year, local.month + 1));
      case GoalPeriod.yearly:
        final start = DateTime(local.year);
        return _PeriodRange(start, DateTime(local.year + 1));
    }
  }

  static DateTime _dayStart(DateTime date) => _taipeiDay(date);

  static DateTime _taipeiCivil(DateTime date) => date.toLocal();

  static DateTime _taipeiDay(DateTime date) {
    final local = _taipeiCivil(date);
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _maxDateTime(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static DateTime _minDateTime(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  static bool _sameMoment(DateTime a, DateTime b) => a.isAtSameMomentAs(b);

  static String _dateKey(DateTime date) {
    final local = _taipeiCivil(date);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseHistoryDate(String key) {
    final parsed = DateTime.tryParse(key.replaceAll('/', '-'));
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 1);
    final adjustedFirstThursday =
        firstThursday.add(Duration(days: DateTime.thursday - firstThursday.weekday));
    return 1 + thursday.difference(adjustedFirstThursday).inDays ~/ 7;
  }

  static int _isoWeekYear(DateTime date) {
    return date.add(Duration(days: DateTime.thursday - date.weekday)).year;
  }

  static Set<String> _completedPeriodKeys({
    required Goal goal,
    required DateTime now,
    required List<TimeSession> sessions,
    RunningTimerSnapshot? runningTimer,
  }) {
    final totals = <String, int>{};

    if (goal.type == GoalType.time) {
      for (final session in sessions) {
        if (session.category != goal.category) continue;
        if (isBeforeGoalStart(goal, session.date)) continue;
        final key = getCurrentPeriodKey(goal, session.date);
        totals[key] = (totals[key] ?? 0) + session.durationSeconds;
      }
      if (runningTimer != null &&
          runningTimer.isRunning &&
          runningTimer.category == goal.category) {
        final key = getCurrentPeriodKey(goal, now);
        totals[key] = (totals[key] ?? 0) + runningTimer.currentElapsed;
      }
    } else {
      for (final entry in goal.completionHistory.entries) {
        final date = _parseHistoryDate(entry.key);
        if (date == null || date.isBefore(_taipeiDay(goal.startDate))) continue;
        final key = getCurrentPeriodKey(goal, date);
        totals[key] = (totals[key] ?? 0) + entry.value;
      }
    }

    final target = targetValue(goal);
    return totals.entries
        .where((entry) => entry.value >= target)
        .map((entry) => entry.key)
        .toSet();
  }

  static int _longestCompletedStreak({
    required Goal goal,
    required DateTime now,
    required Set<String> completedKeys,
    bool restrictToCurrentMonth = false,
  }) {
    final periods = <String>[];
    var cursor = _periodRange(goal.period, goal.startDate).start;
    final end = _periodRange(goal.period, now).start;

    while (!cursor.isAfter(end)) {
      if (!restrictToCurrentMonth ||
          (cursor.year == now.toLocal().year && cursor.month == now.toLocal().month)) {
        periods.add(getCurrentPeriodKey(goal, cursor));
      }
      cursor = _nextPeriodStart(goal.period, cursor);
    }

    var current = 0;
    var longest = 0;
    for (final key in periods) {
      if (completedKeys.contains(key)) {
        current += 1;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  static DateTime _nextPeriodStart(GoalPeriod period, DateTime current) {
    switch (period) {
      case GoalPeriod.daily:
        return current.add(const Duration(days: 1));
      case GoalPeriod.weekly:
        return current.add(const Duration(days: 7));
      case GoalPeriod.monthly:
        return DateTime(current.year, current.month + 1);
      case GoalPeriod.yearly:
        return DateTime(current.year + 1);
    }
  }

  static String _formatValue(Goal goal, int current, int target) {
    if (goal.type == GoalType.time) {
      final label = periodProgressLabel(goal.period);
      return '${_formatDuration(current)} / $label ${_formatDuration(target)}';
    }
    if (goal.type == GoalType.binary) {
      return current > 0 ? '已完成' : '尚未完成';
    }
    final label = periodProgressLabel(goal.period);
    return '$current 次 / $label $target 次';
  }

  static String _formatRemaining(Goal goal, int remaining) {
    if (remaining <= 0) return '已完成';
    if (goal.type == GoalType.time) return '剩餘 ${_formatDuration(remaining)}';
    if (goal.type == GoalType.binary) return '尚未完成';
    return '剩餘 $remaining 次';
  }

  static String _formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '$hours 小時 $minutes 分鐘';
    if (hours > 0) return '$hours 小時';
    return '$minutes 分鐘';
  }
}

class _PeriodRange {
  final DateTime start;
  final DateTime endExclusive;

  const _PeriodRange(this.start, this.endExclusive);
}
