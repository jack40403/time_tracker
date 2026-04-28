import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/goal.dart';

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

    await _notifications.initialize(initSettings);
  }

  static Future<void> scheduleGoalReminder(Goal goal) async {
    if (kIsWeb || !goal.isReminderEnabled || goal.reminderTime == null) {
      await cancelGoalReminder(goal.id);
      return;
    }

    // 將 Goal ID 轉為整數用於通知 ID (取 Hash)
    final int notifyId = goal.id.hashCode.abs();
    
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
    await _notifications.cancel(goalId.hashCode.abs());
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
