import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/goal.dart';
import 'package:time_tracker/models/time_session.dart';
import 'package:time_tracker/providers/current_focus_goals_provider.dart';
import 'package:time_tracker/services/goal_progress_service.dart';

void main() {
  Goal goal({
    GoalPeriod period = GoalPeriod.daily,
    GoalType type = GoalType.task,
    int target = 1,
    required DateTime startDate,
    Map<String, int> history = const {},
  }) {
    return Goal(
      id: 'goal-1',
      title: '測試目標',
      category: '測試',
      targetSeconds: target,
      period: period,
      type: type,
      createdAt: startDate,
      startDate: startDate,
      completionHistory: history,
    );
  }

  DateTime taipei(int year, int month, int day, [int hour = 0, int minute = 0]) {
    return DateTime.utc(year, month, day, hour, minute)
        .subtract(const Duration(hours: 8));
  }

  test('台灣午夜後的 session 會算入新的一天', () {
    final target = goal(
      type: GoalType.time,
      target: 1800,
      startDate: taipei(2026, 6, 1),
    );
    final progress = GoalProgressService.buildProgress(
      goal: target,
      now: taipei(2026, 6, 2, 1),
      sessions: [
        TimeSession(
          category: '測試',
          durationSeconds: 1800,
          date: DateTime.utc(2026, 6, 1, 16, 30),
        ),
      ],
    );

    expect(progress.currentValue, 1800);
    expect(progress.isCompleted, isTrue);
    expect(progress.valueText, '30 分 / 30 分');
  });

  test('目前尚未結束的未完成週期不會中斷連續紀錄', () {
    final target = goal(
      startDate: taipei(2026, 6, 1),
      history: const {
        '2026-06-01': 1,
        '2026-06-02': 1,
        '2026-06-03': 1,
        '2026-06-05': 1,
        '2026-06-06': 1,
      },
    );
    final records = GoalProgressService.buildRecords(
      goal: target,
      now: taipei(2026, 6, 7, 12),
      sessions: const [],
    );

    expect(records['historical'], '3 天連續');
    expect(records['monthly'], '3 天連續');
  });

  test('本月最佳不會混入上個月的較長紀錄', () {
    final target = goal(
      startDate: taipei(2026, 5, 27),
      history: const {
        '2026-05-27': 1,
        '2026-05-28': 1,
        '2026-05-29': 1,
        '2026-05-30': 1,
        '2026-06-01': 1,
        '2026-06-02': 1,
      },
    );
    final records = GoalProgressService.buildRecords(
      goal: target,
      now: taipei(2026, 6, 4, 12),
      sessions: const [],
    );

    expect(records['historical'], '4 天連續');
    expect(records['monthly'], '2 天連續');
  });

  test('每年目標只按年度計算一次', () {
    final target = goal(
      period: GoalPeriod.yearly,
      target: 2,
      startDate: taipei(2025, 1, 1),
      history: const {
        '2025-02-01': 1,
        '2025-03-01': 1,
        '2026-02-01': 1,
        '2026-03-01': 1,
      },
    );
    final records = GoalProgressService.buildRecords(
      goal: target,
      now: taipei(2026, 6, 1),
      sessions: const [],
    );

    expect(records['historical'], '2 年連續');
  });

  test('startDate 以前的紀錄不納入 streak', () {
    final target = goal(
      startDate: taipei(2026, 6, 3),
      history: const {
        '2026-06-01': 1,
        '2026-06-02': 1,
        '2026-06-03': 1,
      },
    );
    final records = GoalProgressService.buildRecords(
      goal: target,
      now: taipei(2026, 6, 4, 12),
      sessions: const [],
    );

    expect(records['historical'], '1 天連續');
  });

  test('目前專注目標會套用開始日期與共用排序', () {
    final now = taipei(2026, 6, 10, 9);
    final first = goal(startDate: taipei(2026, 6, 1)).copyWith(id: 'first');
    final future = goal(startDate: taipei(2026, 6, 11)).copyWith(id: 'future');
    final task = goal(startDate: taipei(2026, 6, 1)).copyWith(
      id: 'task',
      type: GoalType.task,
    );

    final goals = getCurrentFocusGoals(
      timeGoals: [first, future],
      taskGoals: [task],
      order: const ['task', 'first'],
      now: now,
    );

    expect(goals.map((goal) => goal.id), ['task', 'first']);
  });
}
