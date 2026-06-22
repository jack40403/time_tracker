import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../models/time_session.dart';

class GoalProgressService {
  static const Duration _taipeiOffset = Duration(hours: 8);

  static bool isBeforeGoalStart(Goal goal, DateTime now) {
    return _taipeiDay(now).isBefore(_taipeiDay(goal.startDate));
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
    return value >= _targetValue(goal);
  }

  static List<GoalProgress> getVisibleReminderGoals({
    required List<Goal> goals,
    required List<TimeSession> sessions,
    required DateTime now,
    RunningTimerSnapshot? runningTimer,
  }) {
    return goals
        .map((goal) => buildProgress(
              goal: goal,
              now: now,
              sessions: sessions,
              runningTimer: runningTimer,
            ))
        .where((progress) => !progress.isCompleted)
        .toList();
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

  static Map<String, String> buildRecords({
    required Goal goal,
    required DateTime now,
    required List<TimeSession> sessions,
  }) {
    final start = _periodRange(goal.period, goal.startDate).start;
    final currentRange = _periodRange(goal.period, now);
    final currentMonthStart = DateTime.utc(
      _taipeiCivil(now).year,
      _taipeiCivil(now).month,
    );
    final currentMonthEnd = DateTime.utc(
      currentMonthStart.year,
      currentMonthStart.month + 1,
    );

    var cursor = start;
    var historicalRun = 0;
    var historicalBest = 0;
    DateTime? historicalBestEnd;
    var monthlyRun = 0;
    var monthlyBest = 0;
    DateTime? monthlyBestEnd;

    while (!cursor.isAfter(currentRange.start)) {
      final range = _periodRange(goal.period, cursor);
      final value = _valueForRange(
        goal: goal,
        range: range,
        sessions: sessions,
      );
      final completed = value >= _targetValue(goal);
      final isCurrent = range.start == currentRange.start;
      final periodEndDate = range.endExclusive.subtract(const Duration(days: 1));

      if (completed) {
        historicalRun++;
        if (historicalRun > historicalBest) {
          historicalBest = historicalRun;
          historicalBestEnd = periodEndDate;
        }
      } else if (!isCurrent) {
        historicalRun = 0;
      }

      final belongsToCurrentMonth =
          !periodEndDate.isBefore(currentMonthStart) && periodEndDate.isBefore(currentMonthEnd);
      if (belongsToCurrentMonth) {
        if (completed) {
          monthlyRun++;
          if (monthlyRun > monthlyBest) {
            monthlyBest = monthlyRun;
            monthlyBestEnd = periodEndDate;
          }
        } else if (!isCurrent) {
          monthlyRun = 0;
        }
      }

      cursor = range.endExclusive;
    }

    final unit = switch (goal.period) {
      GoalPeriod.daily => '天',
      GoalPeriod.weekly => '週',
      GoalPeriod.monthly => '月',
      GoalPeriod.yearly => '年',
    };
    return {
      'historical': '$historicalBest $unit連續',
      'historical_date': historicalBestEnd == null
          ? '尚無紀錄'
          : '最後達成：${_dateKey(historicalBestEnd)}',
      'monthly': '$monthlyBest $unit連續',
      'monthly_date': monthlyBestEnd == null
          ? '尚無紀錄'
          : '最後達成：${_dateKey(monthlyBestEnd)}',
    };
  }

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
        final start = DateTime.utc(local.year, local.month, local.day);
        return _PeriodRange(start, start.add(const Duration(days: 1)));
      case GoalPeriod.weekly:
        final startOfDay = DateTime.utc(local.year, local.month, local.day);
        final start = startOfDay.subtract(Duration(days: local.weekday - 1));
        return _PeriodRange(start, start.add(const Duration(days: 7)));
      case GoalPeriod.monthly:
        final start = DateTime.utc(local.year, local.month);
        return _PeriodRange(start, DateTime.utc(local.year, local.month + 1));
      case GoalPeriod.yearly:
        final start = DateTime.utc(local.year);
        return _PeriodRange(start, DateTime.utc(local.year + 1));
    }
  }

  static DateTime _dayStart(DateTime date) => _taipeiDay(date);

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
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
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
      return current > 0 ? '已完成' : '尚未完成';
    }
    return '$current / $target';
  }

  static String _formatRemaining(Goal goal, int remaining) {
    if (remaining <= 0) return '已完成';
    if (goal.type == GoalType.time) return '剩餘 ${_formatDuration(remaining)}';
    if (goal.type == GoalType.binary) return '尚未完成';
    return '剩餘 $remaining';
  }

  static String _formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '$hours 小時 $minutes 分';
    if (hours > 0) return '$hours 小時';
    return '$minutes 分';
  }

  static int _valueForRange({
    required Goal goal,
    required _PeriodRange range,
    required List<TimeSession> sessions,
  }) {
    final effectiveStart = _maxDateTime(range.start, _taipeiDay(goal.startDate));
    if (goal.type == GoalType.time) {
      return sessions.where((session) {
        if (session.category != goal.category) return false;
        final date = _taipeiCivil(session.date);
        return !date.isBefore(effectiveStart) && date.isBefore(range.endExclusive);
      }).fold(0, (sum, session) => sum + session.durationSeconds);
    }

    var total = 0;
    for (final entry in goal.completionHistory.entries) {
      final date = _parseHistoryDate(entry.key);
      if (date == null || date.isBefore(effectiveStart) || !date.isBefore(range.endExclusive)) {
        continue;
      }
      total += entry.value;
    }
    return goal.type == GoalType.binary ? (total > 0 ? 1 : 0) : total;
  }

  static DateTime _taipeiCivil(DateTime date) {
    final shifted = date.toUtc().add(_taipeiOffset);
    return DateTime.utc(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  static DateTime _taipeiDay(DateTime date) {
    final civil = _taipeiCivil(date);
    return DateTime.utc(civil.year, civil.month, civil.day);
  }
}

class _PeriodRange {
  final DateTime start;
  final DateTime endExclusive;

  const _PeriodRange(this.start, this.endExclusive);
}
