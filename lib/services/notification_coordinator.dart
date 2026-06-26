import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../providers/current_focus_goals_provider.dart';
import '../providers/timer_provider.dart';
import 'notification_service.dart';

class ForegroundNotificationPayload {
  const ForegroundNotificationPayload({
    required this.isTimerActive,
    required this.isRunning,
    required this.timerCategory,
    required this.timerStateLabel,
    required this.timerStartedAtEpochMs,
    required this.focusSummary,
    required this.focusDetail,
    required this.remainingGoals,
    required this.completedGoals,
    required this.totalGoals,
  });

  final bool isTimerActive;
  final bool isRunning;
  final String timerCategory;
  final String timerStateLabel;
  final int? timerStartedAtEpochMs;
  final String focusSummary;
  final String focusDetail;
  final int remainingGoals;
  final int completedGoals;
  final int totalGoals;

  String get signature => [
        isTimerActive,
        isRunning,
        timerCategory,
        timerStateLabel,
        focusSummary,
        focusDetail,
        remainingGoals,
        completedGoals,
        totalGoals,
      ].join('|');

  Map<String, dynamic> toJson() => {
        'isTimerActive': isTimerActive,
        'isRunning': isRunning,
        'timerCategory': timerCategory,
        'timerStateLabel': timerStateLabel,
        'timerStartedAtEpochMs': timerStartedAtEpochMs,
        'focusSummary': focusSummary,
        'focusDetail': focusDetail,
        'remainingGoals': remainingGoals,
        'completedGoals': completedGoals,
        'totalGoals': totalGoals,
      };
}

class NotificationCoordinator {
  NotificationCoordinator._();

  static final NotificationCoordinator instance = NotificationCoordinator._();

  String? _lastForegroundSignature;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> requestForegroundRefresh(
    WidgetRef ref, {
    required String reason,
    bool force = false,
  }) async {
    if (!_isAndroid) return;

    final payload = _buildForegroundPayload(
      timerState: ref.read(timerProvider),
      progresses: ref.read(currentFocusGoalProgressProvider),
    );

    if (!payload.isTimerActive) {
      _lastForegroundSignature = null;
      FlutterBackgroundService().invoke('clearNotificationSnapshot');
      return;
    }

    if (!force && payload.signature == _lastForegroundSignature) {
      return;
    }

    _lastForegroundSignature = payload.signature;
    FlutterBackgroundService().invoke('setNotificationSnapshot', {
      ...payload.toJson(),
      'reason': reason,
      'force': force,
    });
  }

  Future<void> requestReminderSchedule(Goal goal) {
    return NotificationService.scheduleGoalReminder(goal);
  }

  Future<void> requestReminderCancel(String goalId) {
    return NotificationService.cancelGoalReminder(goalId);
  }

  ForegroundNotificationPayload _buildForegroundPayload({
    required TimerState timerState,
    required List<GoalProgress> progresses,
  }) {
    final totalGoals = progresses.length;
    final completedGoals = progresses.where((progress) => progress.isCompleted).length;
    final remainingGoals = totalGoals - completedGoals;
    final focusSummary = totalGoals <= 0
        ? '目前沒有專注目標'
        : '剩餘 $remainingGoals 項｜完成 $completedGoals / $totalGoals';

    final remainingTitles = progresses
        .where((progress) => !progress.isCompleted)
        .take(3)
        .map((progress) => progress.goal.title.trim().isEmpty ? progress.goal.category : progress.goal.title.trim())
        .toList();

    final focusDetail = remainingTitles.isEmpty
        ? '目前所有專注目標都已完成'
        : remainingTitles.join('、');

    final isTimerActive = timerState.isRunning || timerState.currentElapsed > 0;
    final timerStateLabel = timerState.isRunning ? '正在計時' : '計時已暫停';

    return ForegroundNotificationPayload(
      isTimerActive: isTimerActive,
      isRunning: timerState.isRunning,
      timerCategory: timerState.category,
      timerStateLabel: timerStateLabel,
      timerStartedAtEpochMs: timerState.isRunning
          ? (timerState.startTime ?? timerState.startedAt)?.millisecondsSinceEpoch
          : null,
      focusSummary: focusSummary,
      focusDetail: focusDetail,
      remainingGoals: remainingGoals < 0 ? 0 : remainingGoals,
      completedGoals: completedGoals,
      totalGoals: totalGoals,
    );
  }
}
