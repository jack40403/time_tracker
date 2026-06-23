import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/goal.dart';
import 'package:time_tracker/services/goal_stats_service.dart';

Goal _goal({
  required String id,
  required String title,
  required GoalPeriod period,
  required GoalType type,
  required DateTime startDate,
  required Map<String, int> history,
  bool isActive = true,
}) {
  return Goal(
    id: id,
    title: title,
    category: title,
    targetSeconds: type == GoalType.time ? 3600 : 1,
    period: period,
    type: type,
    isActive: isActive,
    createdAt: startDate,
    startDate: startDate,
    completionHistory: history,
  );
}

void main() {
  final now = DateTime(2026, 7, 15, 10);

  test('每日計數目標會分開計算歷史最高與本月最佳', () {
    final goal = _goal(
      id: 'daily-counter',
      title: '閱讀',
      period: GoalPeriod.daily,
      type: GoalType.task,
      startDate: DateTime(2026, 6, 1),
      history: {
        '2026-06-30': 8,
        '2026-07-02': 4,
        '2026-07-10': 2,
      },
    );

    final stats = GoalStatsService.buildStats(goal, now: now);

    expect(stats.historicalBest.value, 8);
    expect(stats.monthlyBest.value, 4);
    expect(stats.historicalBest.displayValue, '8 次');
    expect(stats.monthlyBest.displayValue, '4 次');
  });

  test('每週計數目標會正確裁切跨月週期', () {
    final goal = _goal(
      id: 'weekly-counter',
      title: '運動',
      period: GoalPeriod.weekly,
      type: GoalType.task,
      startDate: DateTime(2026, 6, 1),
      history: {
        '2026-06-29': 100,
        '2026-06-30': 100,
        '2026-07-01': 5,
        '2026-07-02': 5,
      },
    );

    final stats = GoalStatsService.buildStats(goal, now: now);

    expect(stats.historicalBest.value, 210);
    expect(stats.monthlyBest.value, 10);
  });

  test('每月計數目標本月最佳等於本月累積值', () {
    final goal = _goal(
      id: 'monthly-counter',
      title: '喝水',
      period: GoalPeriod.monthly,
      type: GoalType.task,
      startDate: DateTime(2026, 1, 1),
      history: {
        '2026-06-01': 10,
        '2026-06-15': 20,
        '2026-07-01': 7,
        '2026-07-20': 3,
      },
    );

    final stats = GoalStatsService.buildStats(goal, now: now);

    expect(stats.historicalBest.value, 30);
    expect(stats.monthlyBest.value, 7);
  });

  test('每年計數目標本月最佳顯示本月對年度目標的貢獻', () {
    final goal = _goal(
      id: 'yearly-counter',
      title: '番茄鐘',
      period: GoalPeriod.yearly,
      type: GoalType.task,
      startDate: DateTime(2026, 1, 1),
      history: {
        '2026-01-01': 100,
        '2026-07-01': 7,
        '2026-07-20': 3,
      },
    );

    final stats = GoalStatsService.buildStats(goal, now: now);

    expect(stats.historicalBest.value, 107);
    expect(stats.monthlyBest.value, 7);
  });

  test('每日計時目標會回傳最大單日秒數', () {
    final goal = _goal(
      id: 'daily-time',
      title: '讀書',
      period: GoalPeriod.daily,
      type: GoalType.time,
      startDate: DateTime(2026, 6, 1),
      history: {
        '2026-06-30': 7200,
        '2026-07-01': 4800,
        '2026-07-02': 3600,
      },
    );

    final stats = GoalStatsService.buildStats(goal, now: now);

    expect(stats.historicalBest.value, 7200);
    expect(stats.monthlyBest.value, 4800);
    expect(stats.historicalBest.displayValue, '2 小時');
    expect(stats.monthlyBest.displayValue, '1 小時 20 分鐘');
  });

  test('每週計時目標會正確累積跨月週期與本月值', () {
    final goal = _goal(
      id: 'weekly-time',
      title: '專注',
      period: GoalPeriod.weekly,
      type: GoalType.time,
      startDate: DateTime(2026, 6, 1),
      history: {
        '2026-06-29': 1800,
        '2026-06-30': 1800,
        '2026-07-01': 1200,
        '2026-07-02': 1200,
      },
    );

    final stats = GoalStatsService.buildStats(goal, now: now);

    expect(stats.historicalBest.value, 6000);
    expect(stats.monthlyBest.value, 2400);
  });

  test('是非目標會顯示已完成或尚無紀錄', () {
    final completedGoal = _goal(
      id: 'binary-done',
      title: '冥想',
      period: GoalPeriod.daily,
      type: GoalType.binary,
      startDate: DateTime(2026, 6, 1),
      history: {
        '2026-07-15': 1,
      },
    );
    final emptyGoal = _goal(
      id: 'binary-empty',
      title: '喝水',
      period: GoalPeriod.daily,
      type: GoalType.binary,
      startDate: DateTime(2026, 6, 1),
      history: const {},
    );

    final completedStats = GoalStatsService.buildStats(completedGoal, now: now);
    final emptyStats = GoalStatsService.buildStats(emptyGoal, now: now);

    expect(completedStats.historicalBest.displayValue, '已完成');
    expect(completedStats.monthlyBest.displayValue, '已完成');
    expect(emptyStats.historicalBest.displayValue, '尚無紀錄');
    expect(emptyStats.monthlyBest.displayValue, '尚無紀錄');
  });

  test('封存目標不應參與統計', () {
    final goal = _goal(
      id: 'archived',
      title: '封存目標',
      period: GoalPeriod.daily,
      type: GoalType.task,
      startDate: DateTime(2026, 6, 1),
      history: {
        '2026-07-10': 9,
      },
      isActive: false,
    );

    final stats = GoalStatsService.buildStats(goal, now: now);

    expect(stats.historicalBest.displayValue, '尚無紀錄');
    expect(stats.monthlyBest.displayValue, '尚無紀錄');
  });
}
