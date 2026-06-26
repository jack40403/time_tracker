import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/goal.dart';
import 'goal_reminder_notification_service.dart';

@pragma('vm:entry-point')
void onNotificationResponse(NotificationResponse response) {
  unawaited(NotificationService.handleNotificationResponse(response));
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();
    final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (GoalReminderNotificationService.isOpenPanelPayload(
      launchDetails?.notificationResponse?.payload,
    )) {
      GoalReminderNotificationService.markOpenPanelAfterLaunch();
    }

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onNotificationResponse,
    );

    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final permissionGranted = await androidImplementation?.requestNotificationsPermission();
    debugPrint('NotificationService.init: Android notifications permission = $permissionGranted');

    await GoalReminderNotificationService.initialize();
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {
    await GoalReminderNotificationService.handleNotificationResponse(response);
  }

  static Future<void> scheduleGoalReminder(Goal goal) async {
    if (kIsWeb || !goal.isActive || !goal.isReminderEnabled || goal.reminderTime == null) {
      await cancelGoalReminder(goal.id);
      return;
    }

    // 將 Goal ID (UUID) 轉為通知 ID：取前 7 個 hex 字元解析為 int，避免 hashCode 碰撞
    final String hex = goal.id.replaceAll('-', '').substring(0, 7);
    final int notifyId = int.parse(hex, radix: 16);
    
    final timeParts = goal.reminderTime!.split(':');
    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);

    final scheduledDate = _nextInstanceOfTime(hour, minute);

    DateTimeComponents? recurrence;
    switch (goal.period) {
      case GoalPeriod.daily:
        recurrence = DateTimeComponents.time;
        break;
      case GoalPeriod.weekly:
        recurrence = DateTimeComponents.dayOfWeekAndTime;
        break;
      case GoalPeriod.monthly:
        recurrence = DateTimeComponents.dayOfMonthAndTime;
        break;
      default:
        recurrence = DateTimeComponents.time;
    }

    await _notifications.zonedSchedule(
      notifyId,
      '目標提醒：${goal.title}',
      '別忘了完成您的 ${goal.period == GoalPeriod.daily ? "每日" : (goal.period == GoalPeriod.weekly ? "每週" : "每月")} 目標！',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_reminders',
          '目標達成提醒',
          channelDescription: '用於提醒使用者完成設定的目標',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: recurrence,
    );
  }

  static Future<void> cancelGoalReminder(String goalId) async {
    if (kIsWeb) return;
    final String hex = goalId.replaceAll('-', '').substring(0, 7);
    await _notifications.cancel(int.parse(hex, radix: 16));
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
