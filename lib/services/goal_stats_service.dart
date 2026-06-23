import '../models/goal.dart';
import '../models/time_session.dart';

class GoalStatsSnapshot {
  final GoalValueStat historicalBest;
  final GoalValueStat monthlyBest;

  const GoalStatsSnapshot({
    required this.historicalBest,
    required this.monthlyBest,
  });

  Map<String, String> toLegacyMap() {
    return {
      'historical': historicalBest.displayValue,
      'monthly': monthlyBest.displayValue,
      'historical_date': historicalBest.displayDate,
      'monthly_date': monthlyBest.displayDate,
    };
  }
}

class GoalValueStat {
  final GoalType goalType;
  final int value;
  final DateTime? achievedAt;
  final bool hasData;

  const GoalValueStat({
    required this.goalType,
    required this.value,
    required this.achievedAt,
    required this.hasData,
  });

  String get displayValue {
    if (!hasData || value <= 0) {
      return '\u5c1a\u7121\u7d00\u9304';
    }
    return GoalStatsService.formatValue(value, goalType);
  }

  String get displayDate => achievedAt == null ? '' : GoalStatsService.formatDate(achievedAt!);
}

class GoalPeriodBucket {
  final DateTime start;
  final DateTime endExclusive;

  const GoalPeriodBucket({
    required this.start,
    required this.endExclusive,
  });
}

class GoalStatsService {
  static GoalStatsSnapshot buildStats(
    Goal goal, {
    required DateTime now,
    List<TimeSession> sessions = const [],
    int currentRunningSeconds = 0,
    bool isTimerRunning = false,
    String? runningCategory,
  }) {
    final history = _effectiveHistory(goal, sessions: sessions);

    final historicalBest = _bestBucket(
      goal,
      history: history,
      rangeStart: goal.startDate,
      rangeEndExclusive: now.add(const Duration(days: 1)),
      now: now,
      currentRunningSeconds: currentRunningSeconds,
      isTimerRunning: isTimerRunning,
      runningCategory: runningCategory,
      clipToCurrentMonth: false,
      overrideBucketMode: null,
    );

    final monthlyStart = DateTime(now.year, now.month, 1);
    final monthlyEnd = DateTime(now.year, now.month + 1, 1);
    final monthlyBest = goal.period == GoalPeriod.yearly
        ? _bestBucket(
            goal,
            history: history,
            rangeStart: monthlyStart,
            rangeEndExclusive: monthlyEnd,
            now: now,
            currentRunningSeconds: currentRunningSeconds,
            isTimerRunning: isTimerRunning,
            runningCategory: runningCategory,
            clipToCurrentMonth: true,
            overrideBucketMode: _BucketMode.monthlyContribution,
          )
        : _bestBucket(
            goal,
            history: history,
            rangeStart: _monthRelevantStart(goal, monthlyStart),
            rangeEndExclusive: monthlyEnd,
            now: now,
            currentRunningSeconds: currentRunningSeconds,
            isTimerRunning: isTimerRunning,
            runningCategory: runningCategory,
            clipToCurrentMonth: true,
            overrideBucketMode: _BucketMode.monthlyBest,
          );

    return GoalStatsSnapshot(
      historicalBest: historicalBest,
      monthlyBest: monthlyBest,
    );
  }

  static GoalValueStat getGoalHistoricalBest(
    Goal goal, {
    required DateTime now,
    List<TimeSession> sessions = const [],
    int currentRunningSeconds = 0,
    bool isTimerRunning = false,
    String? runningCategory,
  }) {
    return buildStats(
      goal,
      now: now,
      sessions: sessions,
      currentRunningSeconds: currentRunningSeconds,
      isTimerRunning: isTimerRunning,
      runningCategory: runningCategory,
    ).historicalBest;
  }

  static GoalValueStat getGoalMonthlyBest(
    Goal goal, {
    required DateTime now,
    List<TimeSession> sessions = const [],
    int currentRunningSeconds = 0,
    bool isTimerRunning = false,
    String? runningCategory,
  }) {
    return buildStats(
      goal,
      now: now,
      sessions: sessions,
      currentRunningSeconds: currentRunningSeconds,
      isTimerRunning: isTimerRunning,
      runningCategory: runningCategory,
    ).monthlyBest;
  }

  static List<GoalPeriodBucket> getPeriodsInCurrentMonth(Goal goal, DateTime now) {
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final buckets = <GoalPeriodBucket>[];
    var cursor = _monthRelevantStart(goal, monthStart);
    while (cursor.isBefore(monthEnd)) {
      final next = _nextBucketStart(goal.period, cursor);
      if (_intersects(cursor, next, monthStart, monthEnd)) {
        buckets.add(GoalPeriodBucket(start: cursor, endExclusive: next));
      }
      cursor = next;
    }
    return buckets;
  }

  static String getCurrentPeriodKey(Goal goal, DateTime now) {
    final bucketStart = _bucketStart(goal.period, now);
    return _bucketKey(goal.period, bucketStart);
  }

  static String formatValue(int value, GoalType type) {
    switch (type) {
      case GoalType.time:
        return _formatDuration(value);
      case GoalType.binary:
        return value > 0 ? '\u5df2\u5b8c\u6210' : '\u5c1a\u7121\u7d00\u9304';
      case GoalType.task:
        return '$value \u6b21';
    }
  }

  static String formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static Map<String, int> _effectiveHistory(
    Goal goal, {
    required List<TimeSession> sessions,
  }) {
    if (goal.isActive == false) {
      return const {};
    }

    if (goal.completionHistory.isNotEmpty) {
      return Map<String, int>.from(goal.completionHistory);
    }

    if (goal.type != GoalType.time || sessions.isEmpty) {
      return Map<String, int>.from(goal.completionHistory);
    }

    final history = <String, int>{};
    final goalStart = _dayStart(goal.startDate);
    for (final session in sessions) {
      if (session.category != goal.category) continue;
      final day = _dayStart(session.date);
      if (day.isBefore(goalStart)) continue;
      final key = _dateKey(day);
      history[key] = (history[key] ?? 0) + session.durationSeconds;
    }
    return history;
  }

  static GoalValueStat _bestBucket(
    Goal goal, {
    required Map<String, int> history,
    required DateTime rangeStart,
    required DateTime rangeEndExclusive,
    required DateTime now,
    required int currentRunningSeconds,
    required bool isTimerRunning,
    required String? runningCategory,
    required bool clipToCurrentMonth,
    required _BucketMode? overrideBucketMode,
  }) {
    if (!goal.isActive) {
      return GoalValueStat(goalType: goal.type, value: 0, achievedAt: null, hasData: false);
    }

    final buckets = _bucketsForGoal(goal.period, rangeStart, rangeEndExclusive);
    if (buckets.isEmpty) {
      return GoalValueStat(goalType: goal.type, value: 0, achievedAt: null, hasData: false);
    }

    GoalValueStat? best;
    for (final bucket in buckets) {
      final value = _bucketValue(
        goal: goal,
        history: history,
        bucket: bucket,
        now: now,
        currentRunningSeconds: currentRunningSeconds,
        isTimerRunning: isTimerRunning,
        runningCategory: runningCategory,
        clipToCurrentMonth: clipToCurrentMonth,
        overrideBucketMode: overrideBucketMode,
      );

      if (best == null || value.value > best.value) {
        best = value;
      }
    }

    return best ??
        GoalValueStat(goalType: goal.type, value: 0, achievedAt: null, hasData: false);
  }

  static GoalValueStat _bucketValue({
    required Goal goal,
    required Map<String, int> history,
    required GoalPeriodBucket bucket,
    required DateTime now,
    required int currentRunningSeconds,
    required bool isTimerRunning,
    required String? runningCategory,
    required bool clipToCurrentMonth,
    required _BucketMode? overrideBucketMode,
  }) {
    final bucketStart = _dayStart(bucket.start);
    final bucketEnd = _dayStart(bucket.endExclusive.subtract(const Duration(seconds: 1))).add(const Duration(days: 1));
    final effectiveStart = _maxDate(_maxDate(bucketStart, _dayStart(goal.startDate)), _dayStart(goal.startDate));
    final effectiveEnd = _minDate(_minDate(bucketEnd, _dayStart(now).add(const Duration(days: 1))), bucketEnd);

    if (!effectiveStart.isBefore(effectiveEnd)) {
      return GoalValueStat(goalType: goal.type, value: 0, achievedAt: null, hasData: false);
    }

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final rangeStart = clipToCurrentMonth ? _maxDate(effectiveStart, monthStart) : effectiveStart;
    final rangeEnd = clipToCurrentMonth ? _minDate(effectiveEnd, monthEnd) : effectiveEnd;

    if (!rangeStart.isBefore(rangeEnd)) {
      return GoalValueStat(goalType: goal.type, value: 0, achievedAt: null, hasData: false);
    }

    var total = 0;
    var hasData = false;
    var cursor = _dayStart(rangeStart);
    final lastDay = _dayStart(rangeEnd.subtract(const Duration(seconds: 1)));

    while (!cursor.isAfter(lastDay)) {
      final key = _dateKey(cursor);
      final value = history[key];
      if (value != null) {
        total += value;
        hasData = true;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    if (goal.type == GoalType.time && isTimerRunning && runningCategory == goal.category) {
      final today = _dayStart(now);
      if (!today.isBefore(rangeStart) && !today.isAfter(lastDay)) {
        total += currentRunningSeconds;
        hasData = true;
      }
    }

    if (goal.type == GoalType.binary) {
      final completed = total > 0;
      return GoalValueStat(
        goalType: goal.type,
        value: completed ? 1 : 0,
        achievedAt: completed ? bucket.endExclusive.subtract(const Duration(seconds: 1)) : null,
        hasData: hasData || completed,
      );
    }

    return GoalValueStat(
      goalType: goal.type,
      value: total,
      achievedAt: hasData ? bucket.endExclusive.subtract(const Duration(seconds: 1)) : null,
      hasData: hasData,
    );
  }

  static List<GoalPeriodBucket> _bucketsForGoal(
    GoalPeriod period,
    DateTime start,
    DateTime endExclusive,
  ) {
    final buckets = <GoalPeriodBucket>[];
    var cursor = _bucketStart(period, start);
    while (cursor.isBefore(endExclusive)) {
      final next = _nextBucketStart(period, cursor);
      buckets.add(GoalPeriodBucket(start: cursor, endExclusive: next));
      cursor = next;
    }
    return buckets;
  }

  static DateTime _bucketStart(GoalPeriod period, DateTime date) {
    final local = date.toLocal();
    switch (period) {
      case GoalPeriod.daily:
        return DateTime(local.year, local.month, local.day);
      case GoalPeriod.weekly:
        final day = DateTime(local.year, local.month, local.day);
        return day.subtract(Duration(days: local.weekday - 1));
      case GoalPeriod.monthly:
        return DateTime(local.year, local.month, 1);
      case GoalPeriod.yearly:
        return DateTime(local.year, 1, 1);
    }
  }

  static DateTime _nextBucketStart(GoalPeriod period, DateTime start) {
    final local = start.toLocal();
    switch (period) {
      case GoalPeriod.daily:
        return DateTime(local.year, local.month, local.day + 1);
      case GoalPeriod.weekly:
        return DateTime(local.year, local.month, local.day + 7);
      case GoalPeriod.monthly:
        return DateTime(local.year, local.month + 1, 1);
      case GoalPeriod.yearly:
        return DateTime(local.year + 1, 1, 1);
    }
  }

  static DateTime _monthRelevantStart(Goal goal, DateTime monthStart) {
    if (goal.period == GoalPeriod.yearly) {
      return monthStart;
    }
    return _bucketStart(goal.period, monthStart);
  }

  static bool _intersects(DateTime startA, DateTime endA, DateTime startB, DateTime endB) {
    return startA.isBefore(endB) && startB.isBefore(endA);
  }

  static DateTime _dayStart(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static String _bucketKey(GoalPeriod period, DateTime bucketStart) {
    final local = bucketStart.toLocal();
    switch (period) {
      case GoalPeriod.daily:
        return _dateKey(local);
      case GoalPeriod.weekly:
        return '${local.year}-W${_isoWeekNumber(local).toString().padLeft(2, '0')}';
      case GoalPeriod.monthly:
        return '${local.year}-${local.month.toString().padLeft(2, '0')}';
      case GoalPeriod.yearly:
        return '${local.year}';
    }
  }

  static int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 1);
    final adjustedFirstThursday =
        firstThursday.add(Duration(days: DateTime.thursday - firstThursday.weekday));
    return 1 + thursday.difference(adjustedFirstThursday).inDays ~/ 7;
  }

  static String _formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    if (safe == 0) {
      return '0 \u5206\u9418';
    }
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final secs = safe % 60;
    final parts = <String>[];
    if (hours > 0) parts.add('$hours \u5c0f\u6642');
    if (minutes > 0) parts.add('$minutes \u5206\u9418');
    if (parts.isEmpty) {
      parts.add('$secs \u79d2');
    } else if (secs > 0 && hours == 0) {
      parts.add('$secs \u79d2');
    }
    return parts.join(' ');
  }
}

enum _BucketMode {
  monthlyBest,
  monthlyContribution,
}
