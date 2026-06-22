import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';

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
  static const String channelId = 'goal_reminder_ongoing_v1';
  static const String channelName = 'Goal reminders';
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
      description: 'Persistent reminder for unfinished goals in the current period.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showOngoing(List<GoalProgress> progresses) async {
    if (!_isAndroid) return;
    if (progresses.isEmpty) {
      await cancel();
      return;
    }

    final visible = progresses.take(4).toList();
    final averageProgress = progresses.isEmpty
        ? 1.0
        : progresses.fold<double>(0, (sum, p) => sum + p.progress) / progresses.length;

    final lines = visible.map((progress) {
      return '${progress.goal.title}: ${progress.valueText}';
    }).join('\n');

    GoalProgress? firstActionGoal;
    for (final progress in visible) {
      if (progress.goal.type == GoalType.binary || progress.goal.type == GoalType.task) {
        firstActionGoal = progress;
        break;
      }
    }

    final actions = <AndroidNotificationAction>[];
    if (firstActionGoal != null) {
      final goal = firstActionGoal.goal;
      if (goal.type == GoalType.binary) {
        actions.add(AndroidNotificationAction(
          _actionId('complete', goal.id),
          'Done',
          showsUserInterface: false,
        ));
      } else if (goal.type == GoalType.task) {
        actions.addAll([
          AndroidNotificationAction(
            _actionId('increment', goal.id),
            '+1',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            _actionId('decrement', goal.id),
            '-1',
            showsUserInterface: false,
          ),
        ]);
      }
    }

    final details = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Persistent reminder for unfinished goals in the current period.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      showWhen: false,
      styleInformation: BigTextStyleInformation(
        lines,
        contentTitle: 'Goals left: ${progresses.length}',
        summaryText: 'Total progress ${(averageProgress * 100).round()}%',
      ),
      actions: actions,
    );

    await _notifications.show(
      notificationId,
      'Goals left: ${progresses.length}',
      visible.first.valueText,
      NotificationDetails(android: details),
    );
  }

  static Future<void> cancel() async {
    if (!_isAndroid) return;
    await _notifications.cancel(notificationId);
  }

  static Future<void> handleNotificationResponse(NotificationResponse response) async {
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
            return GoalReminderAction.fromJson(jsonDecode(item) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<GoalReminderAction>()
        .where((action) => action.goalId.isNotEmpty && action.action.isNotEmpty)
        .toList();
  }

  static String _actionId(String action, String goalId) => 'goal_$action:$goalId';

  static GoalReminderAction? _parseActionId(String actionId) {
    final separator = actionId.indexOf(':');
    if (separator <= 5 || separator == actionId.length - 1) return null;
    final action = actionId.substring(5, separator);
    final goalId = actionId.substring(separator + 1);
    return GoalReminderAction(goalId: goalId, action: action);
  }
}
