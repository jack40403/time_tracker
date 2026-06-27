import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoalReminderAction {
  const GoalReminderAction({
    required this.goalId,
    required this.action,
  });

  final String goalId;
  final String action;

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
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (!_isAndroid) return;

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: '用於排程式提醒，非 ongoing notification。',
      importance: Importance.defaultImportance,
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
    List<dynamic> progresses, {
    required int totalCount,
    required int completedCount,
  }) async {
    debugPrint(
      'GoalReminderNotificationService.showOngoing: ignored because ongoing notifications are now owned by NotificationCoordinator.',
    );
  }

  static Future<void> cancel() async {
    debugPrint(
      'GoalReminderNotificationService.cancel: ignored because ongoing notifications are now owned by NotificationCoordinator.',
    );
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final actionId = response.actionId;
    if (actionId == null || !actionId.startsWith('goal_')) return;

    final parsed = _parseActionId(actionId);
    if (parsed == null) return;

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
            return GoalReminderAction.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            );
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

  static bool isOpenPanelPayload(String? payload) => false;

  static void markOpenPanelAfterLaunch() {}

  static Future<void> openPanelAfterLaunchIfNeeded() async {}
}
