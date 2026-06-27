import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';
import 'notification_launch_service.dart';

class FocusNotificationService {
  FocusNotificationService._();

  static const String channelId = 'focus_goals_ongoing_v1';
  static const int notificationId = 889;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (!_isAndroid) return;
    const channel = AndroidNotificationChannel(
      channelId,
      '專注目標',
      description: '顯示目前尚未完成的專注目標。',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showOngoing(
    List<GoalProgress> progresses, {
    required int completedCount,
  }) async {
    if (!_isAndroid) return;

    final remaining = progresses.where((progress) => !progress.isCompleted).toList();
    if (remaining.isEmpty) {
      await cancel(reason: 'no-remaining-focus-goals');
      return;
    }

    final total = progresses.length;
    final summary = '剩餘 ${remaining.length} 項｜完成 $completedCount / $total';
    final detailLines = remaining.take(4).map(_buildDetailBlock).toList();
    if (remaining.length > 4) {
      detailLines.add('另有 ${remaining.length - 4} 項目標');
    }

    final bigText = detailLines.join('\n\n');

    await _notifications.show(
      notificationId,
      '專注目標',
      summary,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          '專注目標',
          channelDescription: '顯示目前尚未完成的專注目標。',
          importance: Importance.low,
          priority: Priority.low,
          category: AndroidNotificationCategory.status,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          silent: true,
          playSound: false,
          enableVibration: false,
          styleInformation: BigTextStyleInformation(
            bigText,
            contentTitle: '專注目標',
            summaryText: summary,
          ),
        ),
      ),
      payload: NotificationLaunchService.focusQuickPanelPayload,
    );

    debugPrint(
      'FocusNotificationDebug '
      'source=showOngoing '
      'focusGoalCount=${remaining.length} '
      'finalAction=show '
      'summary="$summary"',
    );
  }

  static Future<void> cancel({required String reason}) async {
    if (!_isAndroid) return;
    await _notifications.cancel(notificationId);
    debugPrint(
      'FocusNotificationDebug '
      'source=cancel '
      'focusGoalCount=0 '
      'finalAction=$reason',
    );
  }

  static String _buildDetailBlock(GoalProgress progress) {
    final title = _displayTitle(progress.goal);
    if (progress.goal.type == GoalType.binary) {
      return '☐ $title';
    }
    return '$title\n${progress.valueText}';
  }

  static String _displayTitle(Goal goal) {
    final base = goal.title.trim().isEmpty ? goal.category : goal.title.trim();
    switch (goal.period) {
      case GoalPeriod.daily:
        return base;
      case GoalPeriod.weekly:
        return '$base（每週）';
      case GoalPeriod.monthly:
        return '$base（每月）';
      case GoalPeriod.yearly:
        return '$base（每年）';
    }
  }
}
