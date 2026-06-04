import '../models/goal.dart';

class GoalCalendarUtils {
  static String dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static DateTime startOfWeek(DateTime date) {
    final d = dateOnly(date);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static DateTime endOfWeek(DateTime date) => startOfWeek(date).add(const Duration(days: 6));

  static bool isWeeklyGoalAchievedOnDate(Goal goal, DateTime date) {
    if (goal.period != GoalPeriod.weekly) return false;
    return _isPeriodGoalAchieved(goal, startOfWeek(date), endOfWeek(date));
  }

  static bool isMonthlyGoalAchievedOnDate(Goal goal, DateTime date) {
    if (goal.period != GoalPeriod.monthly) return false;
    final monthStart = DateTime(date.year, date.month, 1);
    final monthEnd = DateTime(date.year, date.month + 1, 0);
    return _isPeriodGoalAchieved(goal, monthStart, monthEnd);
  }

  static bool isYearlyGoalAchievedOnDate(Goal goal, DateTime date) {
    if (goal.period != GoalPeriod.yearly) return false;
    final yearStart = DateTime(date.year, 1, 1);
    final yearEnd = DateTime(date.year + 1, 1, 0);
    return _isPeriodGoalAchieved(goal, yearStart, yearEnd);
  }

  static bool isPeriodGoalAchievedOnDate(Goal goal, DateTime date) {
    switch (goal.period) {
      case GoalPeriod.weekly:
        return isWeeklyGoalAchievedOnDate(goal, date);
      case GoalPeriod.monthly:
        return isMonthlyGoalAchievedOnDate(goal, date);
      case GoalPeriod.yearly:
        return isYearlyGoalAchievedOnDate(goal, date);
      case GoalPeriod.daily:
        return false;
    }
  }

  static bool isDailyCellSuccessful(Goal goal, DateTime date) {
    final key = dateKey(date);
    final value = goal.completionHistory[key] ?? 0;

    if (goal.period != GoalPeriod.daily) {
      return isPeriodGoalAchievedOnDate(goal, date);
    }

    if (goal.type == GoalType.binary) {
      return value > 0;
    }

    return value >= goal.targetSeconds && value > 0;
  }

  static bool hasDailyEntry(Goal goal, DateTime date) {
    return (goal.completionHistory[dateKey(date)] ?? 0) > 0;
  }

  static bool _isPeriodGoalAchieved(Goal goal, DateTime periodStart, DateTime periodEnd) {
    final goalStart = dateOnly(goal.startDate);
    int total = 0;

    for (final entry in goal.completionHistory.entries) {
      final parsed = DateTime.tryParse(entry.key.replaceAll('/', '-'));
      if (parsed == null) continue;

      final day = dateOnly(parsed);
      if (day.isBefore(goalStart)) continue;
      if (day.isBefore(periodStart) || day.isAfter(periodEnd)) continue;

      total += entry.value;
    }

    return total >= goal.targetSeconds && total > 0;
  }
}
