import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../models/time_session.dart';

class GoalProgressService {
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
    if (!goal.isActive || now.isBefore(_dayStart(goal.startDate))) return 0;

    final range = _periodRange(goal.period, now);
    final effectiveStart = _maxDateTime(range.start, goal.startDate);
    final effectiveEnd = _minDateTime(range.endExclusive, now);
    if (!effectiveStart.isBefore(effectiveEnd) && !_sameMoment(effectiveStart, effectiveEnd)) {
      return 0;
    }

    if (goal.type == GoalType.time) {
      var total = 0;
      for (final session in sessions) {
        final sessionDate = session.date.toLocal();
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
    return value >= _targetValue(goal);
  }

  static List<GoalProgress> getVisibleReminderGoals({
    required List<Goal> timeGoals,
    required List<Goal> taskGoals,
    required List<TimeSession> sessions,
    required DateTime now,
    RunningTimerSnapshot? runningTimer,
  }) {
    final allGoals = <Goal>[
      ...timeGoals.where((g) => g.isActive),
      ...taskGoals.where((g) => g.isActive),
    ];

    final progresses = allGoals
        .map((goal) => buildProgress(
              goal: goal,
              now: now,
              sessions: sessions,
              runningTimer: runningTimer,
            ))
        .where((progress) => !progress.isCompleted)
        .toList();

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
    final target = _targetValue(goal);
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

  static String dateKey(DateTime date) => _dateKey(date);

  static int _targetValue(Goal goal) {
    if (goal.type == GoalType.binary) return 1;
    return goal.targetSeconds <= 0 ? 1 : goal.targetSeconds;
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

    final started = runningTimer.startTime!.toLocal();
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
    final local = date.toLocal();
    switch (period) {
      case GoalPeriod.daily:
        final start = DateTime(local.year, local.month, local.day);
        return _PeriodRange(start, start.add(const Duration(days: 1)));
      case GoalPeriod.weekly:
        final startOfDay = DateTime(local.year, local.month, local.day);
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

  static DateTime _dayStart(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _maxDateTime(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static DateTime _minDateTime(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  static bool _sameMoment(DateTime a, DateTime b) => a.isAtSameMomentAs(b);

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseHistoryDate(String key) {
    return DateTime.tryParse(key.replaceAll('/', '-'));
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

  static String _formatValue(Goal goal, int current, int target) {
    if (goal.type == GoalType.time) {
      return '${_formatDuration(current)} / ${_formatDuration(target)}';
    }
    if (goal.type == GoalType.binary) {
      return current > 0 ? 'Done' : 'Not done';
    }
    return '$current / $target';
  }

  static String _formatRemaining(Goal goal, int remaining) {
    if (remaining <= 0) return 'Complete';
    if (goal.type == GoalType.time) return '${_formatDuration(remaining)} left';
    if (goal.type == GoalType.binary) return 'Not done';
    return '$remaining left';
  }

  static String _formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '${hours}h${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }
}

class _PeriodRange {
  final DateTime start;
  final DateTime endExclusive;

  const _PeriodRange(this.start, this.endExclusive);
}
