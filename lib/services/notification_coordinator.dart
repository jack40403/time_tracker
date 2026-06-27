import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../providers/current_focus_goals_provider.dart';
import '../providers/timer_provider.dart';
import 'background_timer_service.dart';
import 'focus_notification_service.dart';
import 'notification_service.dart';

class TimerNotificationPayload {
  const TimerNotificationPayload({
    required this.isRunning,
    required this.isTimerActive,
    required this.timerCategory,
    required this.timerStateLabel,
    required this.timerStartedAtEpochMs,
    required this.generationId,
  });

  final bool isRunning;
  final bool isTimerActive;
  final String timerCategory;
  final String timerStateLabel;
  final int? timerStartedAtEpochMs;
  final String generationId;

  String get signature => [
        isRunning,
        isTimerActive,
        timerCategory,
        timerStateLabel,
        timerStartedAtEpochMs,
        generationId,
      ].join('|');

  Map<String, dynamic> toJson() => {
        'isRunning': isRunning,
        'isTimerActive': isTimerActive,
        'timerCategory': timerCategory,
        'timerStateLabel': timerStateLabel,
        'timerStartedAtEpochMs': timerStartedAtEpochMs,
        'generationId': generationId,
      };
}

class NotificationCoordinator {
  NotificationCoordinator._();

  static final NotificationCoordinator instance = NotificationCoordinator._();

  String? _lastTimerSignature;
  String? _lastFocusSignature;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> requestForegroundRefresh(
    dynamic ref, {
    required String reason,
    bool force = false,
  }) async {
    if (!_isAndroid) return;

    final timerState = ref.read(timerProvider);
    final progresses = ref.read(currentFocusGoalProgressProvider) as List<GoalProgress>;

    await _syncTimerNotification(
      timerState: timerState,
      reason: reason,
      force: force,
    );
    await _syncFocusNotification(
      progresses: progresses,
      reason: reason,
      force: force,
    );
  }

  Future<void> requestReminderSchedule(Goal goal) {
    return NotificationService.scheduleGoalReminder(goal);
  }

  Future<void> requestReminderCancel(String goalId) {
    return NotificationService.cancelGoalReminder(goalId);
  }

  Future<void> _syncTimerNotification({
    required TimerState timerState,
    required String reason,
    required bool force,
  }) async {
    final payload = TimerNotificationPayload(
      isRunning: timerState.isRunning,
      isTimerActive: timerState.isRunning || timerState.currentElapsed > 0,
      timerCategory: timerState.category,
      timerStateLabel: timerState.isRunning ? '正在計時' : '計時已暫停',
      timerStartedAtEpochMs: timerState.isRunning
          ? (timerState.startTime ?? timerState.startedAt)?.millisecondsSinceEpoch
          : null,
      generationId: timerState.generationId,
    );

    if (!payload.isTimerActive) {
      _lastTimerSignature = null;
      FlutterBackgroundService().invoke('clearNotificationSnapshot');
      await stopBackgroundTimerService();
      return;
    }

    if (!force && payload.signature == _lastTimerSignature) {
      return;
    }

    await ensureBackgroundTimerServiceRunning();
    _lastTimerSignature = payload.signature;
    FlutterBackgroundService().invoke('setNotificationSnapshot', {
      ...payload.toJson(),
      'reason': reason,
      'force': force,
    });
  }

  Future<void> _syncFocusNotification({
    required List<GoalProgress> progresses,
    required String reason,
    required bool force,
  }) async {
    final remaining = progresses.where((progress) => !progress.isCompleted).toList();
    final signature = [
      remaining.length,
      progresses.length,
      remaining.map((progress) => '${progress.goal.id}:${progress.valueText}').join('|'),
    ].join('|');

    if (remaining.isEmpty) {
      _lastFocusSignature = null;
      await FocusNotificationService.cancel(reason: 'all-focus-goals-complete');
      return;
    }

    if (!force && signature == _lastFocusSignature) {
      return;
    }

    _lastFocusSignature = signature;
    await FocusNotificationService.showOngoing(
      progresses,
      completedCount: progresses.length - remaining.length,
    );
  }
}
