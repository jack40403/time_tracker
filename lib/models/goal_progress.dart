import 'goal.dart';

class RunningTimerSnapshot {
  final bool isRunning;
  final String category;
  final DateTime? startTime;
  final int baseSeconds;
  final int currentElapsed;

  const RunningTimerSnapshot({
    required this.isRunning,
    required this.category,
    required this.startTime,
    required this.baseSeconds,
    required this.currentElapsed,
  });
}

class GoalProgress {
  final Goal goal;
  final String periodKey;
  final DateTime periodStart;
  final DateTime periodEndExclusive;
  final int currentValue;
  final int targetValue;
  final double progress;
  final bool isCompleted;
  final String valueText;
  final String remainingText;

  const GoalProgress({
    required this.goal,
    required this.periodKey,
    required this.periodStart,
    required this.periodEndExclusive,
    required this.currentValue,
    required this.targetValue,
    required this.progress,
    required this.isCompleted,
    required this.valueText,
    required this.remainingText,
  });

  double get remainingRatio => (1 - progress).clamp(0.0, 1.0);
}
