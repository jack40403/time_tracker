import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/app_navigator.dart';
import '../models/goal_progress.dart';
import 'goal_progress_service.dart';

class GoalReminderAction {
  final String goalId;
  final String action;

  const GoalReminderAction({
    required this.goalId,
    required this.action,
  });

  Map<String, dynamic> toJson() => {
        'goalId': goalId,
        'action': action,
      };

  factory GoalReminderAction.fromJson(Map<String, dynamic> json) {
    return GoalReminderAction(
      goalId: json['goalId']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
    );
  }
}

class GoalReminderNotificationService {
  static const String channelId = 'goal_reminder_ongoing_v3';
  static const String channelName = '專注目標提醒';
  static const int notificationId = 889;
  static const String _pendingActionsKey = 'goal_reminder_pending_actions';
  static const String _openPanelPayload = 'open_quick_focus_panel';
  static bool _shouldOpenPanelAfterLaunch = false;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (!_isAndroid) return;

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: '顯示目前週期尚未完成的專注目標摘要。',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showOngoing(
    List<GoalProgress> progresses, {
    required int totalCount,
    required int completedCount,
  }) async {
    if (!_isAndroid) return;
    if (totalCount == 0 || progresses.isEmpty) {
      debugPrint(
        'GoalReminderNotificationService.showOngoing: canceled because the reminder list is empty '
        '(totalCount=$totalCount, progresses=${progresses.length})',
      );
      await cancel();
      return;
    }

    final remainingCount = progresses.length;
    final summary = '剩餘 $remainingCount 項｜完成 $completedCount / $totalCount';
    final previewLines = progresses.take(6).map((progress) {
      return '${GoalProgressService.displayTitle(progress.goal)}\n${progress.valueText}';
    }).join('\n\n');
    final body = [
      summary,
      if (previewLines.isNotEmpty) '',
      if (previewLines.isNotEmpty) previewLines,
      '',
      '點擊管理全部專注目標',
    ].join('\n');

    final details = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: '顯示目前週期尚未完成的專注目標摘要。',
      importance: Importance.defaultImportance,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      showWhen: false,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: '專注目標',
        summaryText: summary,
      ),
    );

    await _notifications.show(
      notificationId,
      '專注目標',
      summary,
      NotificationDetails(android: details),
      payload: _openPanelPayload,
    );

    debugPrint(
      'GoalReminderNotificationService.showOngoing: shown '
      '(totalCount=$totalCount, remaining=$remainingCount, completed=$completedCount)',
    );
  }

  static Future<void> cancel() async {
    if (!_isAndroid) return;
    await _notifications.cancel(notificationId);
    debugPrint('GoalReminderNotificationService.cancel: notification canceled');
  }

  static Future<void> handleNotificationResponse(NotificationResponse response) async {
    if (response.payload == _openPanelPayload && response.actionId == null) {
      await openQuickFocusPanel();
      return;
    }

    final actionId = response.actionId;
    if (actionId == null || !actionId.startsWith('goal_')) {
      if (response.payload == 'open_focus_goals') {
        await requestOpenFocusGoals();
      }
      return;
    }

    final parsed = _parseActionId(actionId);
    if (parsed == null) return;

    final result = await GoalActionService.apply(
      goalId: parsed.goalId,
      action: parsed.action,
    );
    if (result != null) {
      await _refreshCachedNotification(result);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_pendingActionsKey) ?? const <String>[];
    await prefs.setStringList(
      _pendingActionsKey,
      [
        ...existing,
        jsonEncode(parsed.toJson()),
      ],
    );
  }

  static Future<List<GoalReminderAction>> takePendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pendingActionsKey) ?? const <String>[];
    if (raw.isEmpty) return const [];
    await prefs.remove(_pendingActionsKey);

    return raw
        .map((item) {
          try {
            return GoalReminderAction.fromJson(jsonDecode(item) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<GoalReminderAction>()
        .where((action) => action.goalId.isNotEmpty && action.action.isNotEmpty)
        .toList();
  }

  static GoalReminderAction? _parseActionId(String actionId) {
    final separator = actionId.indexOf(':');
    if (separator <= 5 || separator == actionId.length - 1) return null;
    final action = actionId.substring(5, separator);
    final goalId = actionId.substring(separator + 1);
    return GoalReminderAction(goalId: goalId, action: action);
  }

  static bool isOpenPanelPayload(String? payload) => payload == _openPanelPayload;

  static void markOpenPanelAfterLaunch() {
    _shouldOpenPanelAfterLaunch = true;
  }

  static Future<void> openPanelAfterLaunchIfNeeded() async {
    if (!_shouldOpenPanelAfterLaunch) return;
    _shouldOpenPanelAfterLaunch = false;
    await openQuickFocusPanel();
  }
}
