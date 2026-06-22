import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal.dart';
import '../models/goal_progress.dart';
import 'goal_action_service.dart';

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
  static const String channelName = '專注目標提醒';
  static const int notificationId = 889;
  static const String _pendingActionsKey = 'goal_reminder_pending_actions';
  static const String _snapshotKey = 'goal_reminder_notification_snapshot_v1';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (!_isAndroid) return;

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: '顯示目前週期尚未完成的專注目標。',
      importance: Importance.low,
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
    required int totalGoals,
  }) async {
    if (!_isAndroid) return;
    final rows = progresses
        .map((progress) => _GoalNotificationRow(
              goalId: progress.goal.id,
              title: progress.goal.title,
              type: progress.goal.type,
              current: progress.currentValue,
              target: progress.targetValue,
              valueText: progress.valueText,
            ))
        .toList();
    await _saveSnapshot(rows, totalGoals);
    await _showRows(rows, totalGoals: totalGoals);
  }

  static Future<void> _showRows(
    List<_GoalNotificationRow> rows, {
    required int totalGoals,
  }) async {
    if (rows.isEmpty) {
      await cancel();
      return;
    }

    final visible = rows.take(4).toList();
    final lines = visible.map((row) {
      if (row.type == GoalType.binary) {
        return '○ ${row.title}';
      }
      return '${row.title}  ${row.valueText}';
    }).join('\n');
    final hiddenCount = rows.length - visible.length;
    final expandedText = hiddenCount > 0 ? '$lines\n另有 $hiddenCount 個目標' : lines;
    final completed = (totalGoals - rows.length).clamp(0, totalGoals);
    final summary = '剩餘 ${rows.length} 個｜完成 $completed / $totalGoals';

    _GoalNotificationRow? firstActionGoal;
    for (final row in visible) {
      if (row.type == GoalType.binary || row.type == GoalType.task) {
        firstActionGoal = row;
        break;
      }
    }

    final actions = <AndroidNotificationAction>[];
    if (firstActionGoal != null) {
      final goal = firstActionGoal;
      if (goal.type == GoalType.binary) {
        actions.add(AndroidNotificationAction(
          _actionId('complete', goal.goalId),
          '完成：${goal.title}',
          showsUserInterface: false,
        ));
      } else if (goal.type == GoalType.task) {
        actions.addAll([
          AndroidNotificationAction(
            _actionId('increment', goal.goalId),
            '+1 ${goal.title}',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            _actionId('decrement', goal.goalId),
            '-1 ${goal.title}',
            showsUserInterface: false,
          ),
        ]);
      }
    }

    final details = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: '顯示目前週期尚未完成的專注目標。',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      showWhen: false,
      styleInformation: BigTextStyleInformation(
        expandedText,
        contentTitle: '今日專注目標',
        summaryText: summary,
      ),
      actions: actions,
    );

    await _notifications.show(
      notificationId,
      '今日專注目標',
      summary,
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

  static String _actionId(String action, String goalId) => 'goal_$action:$goalId';

  static Future<void> _saveSnapshot(
    List<_GoalNotificationRow> rows,
    int totalGoals,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _snapshotKey,
      jsonEncode({
        'totalGoals': totalGoals,
        'rows': rows.map((row) => row.toJson()).toList(),
      }),
    );
  }

  static Future<void> _refreshCachedNotification(GoalActionResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_snapshotKey);
    if (raw == null) return;
    try {
      final snapshot = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final totalGoals = (snapshot['totalGoals'] as num?)?.toInt() ?? 0;
      final rows = (snapshot['rows'] as List? ?? const [])
          .map((item) => _GoalNotificationRow.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
      final index = rows.indexWhere((row) => row.goalId == result.goal.id);
      if (index >= 0) {
        final old = rows[index];
        final updated = old.copyWith(
          current: result.currentValue,
          valueText: old.type == GoalType.binary
              ? '已完成'
              : '${result.currentValue} / ${old.target}',
        );
        if (result.currentValue >= old.target) {
          rows.removeAt(index);
        } else {
          rows[index] = updated;
        }
      }
      await _saveSnapshot(rows, totalGoals);
      await _showRows(rows, totalGoals: totalGoals);
    } catch (_) {
      // The foreground provider will rebuild the notification from source data.
    }
  }

  static GoalReminderAction? _parseActionId(String actionId) {
    final separator = actionId.indexOf(':');
    if (separator <= 5 || separator == actionId.length - 1) return null;
    final action = actionId.substring(5, separator);
    final goalId = actionId.substring(separator + 1);
    return GoalReminderAction(goalId: goalId, action: action);
  }
}

class _GoalNotificationRow {
  final String goalId;
  final String title;
  final GoalType type;
  final int current;
  final int target;
  final String valueText;

  const _GoalNotificationRow({
    required this.goalId,
    required this.title,
    required this.type,
    required this.current,
    required this.target,
    required this.valueText,
  });

  _GoalNotificationRow copyWith({int? current, String? valueText}) {
    return _GoalNotificationRow(
      goalId: goalId,
      title: title,
      type: type,
      current: current ?? this.current,
      target: target,
      valueText: valueText ?? this.valueText,
    );
  }

  Map<String, dynamic> toJson() => {
        'goalId': goalId,
        'title': title,
        'type': type.name,
        'current': current,
        'target': target,
        'valueText': valueText,
      };

  factory _GoalNotificationRow.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString();
    final type = GoalType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => GoalType.time,
    );
    return _GoalNotificationRow(
      goalId: json['goalId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: type,
      current: (json['current'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt() ?? 1,
      valueText: json['valueText']?.toString() ?? '',
    );
  }
}
