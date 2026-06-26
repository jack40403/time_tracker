import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String notificationChannelId = 'timer_foreground_channel';
const int notificationId = 888;
const Duration _runningNotificationRefreshInterval = Duration(seconds: 30);

class _NotificationSnapshot {
  const _NotificationSnapshot({
    required this.serviceTitle,
    required this.serviceContent,
    required this.overlayTitle,
    required this.overlayContent,
    required this.isRunning,
    required this.elapsedSeconds,
  });

  final String serviceTitle;
  final String serviceContent;
  final String overlayTitle;
  final String overlayContent;
  final bool isRunning;
  final int elapsedSeconds;

  String get signature =>
      '$serviceTitle|$serviceContent|$overlayTitle|$overlayContent|$isRunning|$elapsedSeconds';
}

@pragma('vm:entry-point')
void onNotificationActionTap(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('NotificationTap: Received action ${response.actionId}');

  if (response.actionId != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_timer_action', response.actionId!);

    FlutterBackgroundService().invoke('notificationAction', {
      'action': response.actionId,
    });
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    '計時常駐通知',
    description: '用於顯示計時中的常駐通知。',
    importance: Importance.low,
    enableVibration: false,
    playSound: false,
  );

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onNotificationActionTap,
    onDidReceiveBackgroundNotificationResponse: onNotificationActionTap,
  );

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: '計時器準備中',
      initialNotificationContent: '正在建立計時通知…',
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.specialUse],
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  int currentSeconds = 0;
  String category = 'Focus';
  bool isRunning = false;

  final prefs = await SharedPreferences.getInstance();
  final handoffRaw = prefs.getString('bg_handoff_state');
  if (handoffRaw != null) {
    try {
      final data = jsonDecode(handoffRaw) as Map<String, dynamic>;
      currentSeconds = data['seconds'] as int? ?? 0;
      category = data['category'] as String? ?? 'Focus';
      isRunning = data['isRunning'] as bool? ?? false;
      debugPrint(
        'BackgroundService: Inherited state - ${currentSeconds}s, $category, running: $isRunning',
      );
    } catch (e) {
      debugPrint('BackgroundService: Error decoding handoff state: $e');
    }
  }

  int pausedSeconds = 0;
  const autoStopTimeout = 30 * 60;
  DateTime? lastNotificationUpdateAt;
  String? lastNotificationSignature;

  String formatClock(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String formatNotificationElapsed(int seconds) {
    final totalMinutes = seconds ~/ 60;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return minutes > 0 ? '$hours 小時 $minutes 分鐘' : '$hours 小時';
    }
    return '$totalMinutes 分鐘';
  }

  _NotificationSnapshot buildNotificationSnapshot(int current, String cat, bool running) {
    final elapsedText = formatNotificationElapsed(current);
    if (running) {
      return _NotificationSnapshot(
        serviceTitle: '正在計時',
        serviceContent: '$cat｜已累積 $elapsedText',
        overlayTitle: cat,
        overlayContent: '計時中',
        isRunning: true,
        elapsedSeconds: current,
      );
    }

    return _NotificationSnapshot(
      serviceTitle: '計時已暫停',
      serviceContent: '$cat｜目前累積 $elapsedText',
      overlayTitle: cat,
      overlayContent: '已暫停｜$elapsedText',
      isRunning: false,
      elapsedSeconds: current,
    );
  }

  bool shouldUpdateNotification(
    _NotificationSnapshot snapshot, {
    required bool force,
  }) {
    if (force) return true;
    if (snapshot.signature != lastNotificationSignature) return true;
    if (!snapshot.isRunning) return false;
    if (lastNotificationUpdateAt == null) return true;
    return DateTime.now().difference(lastNotificationUpdateAt!) >=
        _runningNotificationRefreshInterval;
  }

  void updateNotification(
    int current,
    String cat,
    bool running, {
    bool force = false,
  }) {
    if (service is! AndroidServiceInstance) return;
    final snapshot = buildNotificationSnapshot(current, cat, running);
    if (!shouldUpdateNotification(snapshot, force: force)) return;

    service.setForegroundNotificationInfo(
      title: snapshot.serviceTitle,
      content: snapshot.serviceContent,
    );

    service.invoke('updateNotification', {
      'title': snapshot.overlayTitle,
      'content': snapshot.overlayContent,
      'isRunning': snapshot.isRunning,
      'elapsedSeconds': snapshot.elapsedSeconds,
    });

    lastNotificationSignature = snapshot.signature;
    lastNotificationUpdateAt = DateTime.now();
  }

  void updateWidget(int current, String cat) {
    if (kIsWeb) return;
    try {
      HomeWidget.saveWidgetData<String>('task_name', cat);
      HomeWidget.saveWidgetData<String>('timer_text', formatClock(current));
      HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.example.time_tracker.MasterWidgetProvider',
      );
    } catch (e) {
      debugPrint('BackgroundService: Widget update failed: $e');
    }
  }

  void setRunning(bool running) {
    isRunning = running;
    if (isRunning) pausedSeconds = 0;
    updateNotification(currentSeconds, category, isRunning, force: true);
    service.invoke('statusChange', {
      'isRunning': isRunning,
      'currentElapsed': currentSeconds,
    });
  }

  Timer.periodic(const Duration(seconds: 1), (t) async {
    final currentPrefs = await SharedPreferences.getInstance();
    await currentPrefs.reload();
    final pendingAction = currentPrefs.getString('pending_timer_action');

    if (pendingAction != null) {
      debugPrint('BackgroundService: Master Watchdog picked up action: $pendingAction');
      await currentPrefs.remove('pending_timer_action');
      if (pendingAction == 'pause') {
        setRunning(false);
      } else if (pendingAction == 'resume') {
        setRunning(true);
      } else if (pendingAction == 'stop') {
        service.invoke('stopFromNotification');
        service.stopSelf();
        return;
      }
    }

    if (isRunning) {
      currentSeconds++;
      pausedSeconds = 0;
      updateWidget(currentSeconds, category);
      service.invoke('update', {
        'currentElapsed': currentSeconds,
        'category': category,
      });
      updateNotification(currentSeconds, category, isRunning);
    } else {
      pausedSeconds++;
      if (pausedSeconds >= autoStopTimeout) {
        debugPrint('BackgroundService: Paused timeout reached. Stopping service...');
        service.stopSelf();
        return;
      }
      updateWidget(currentSeconds, category);
    }
  });

  updateNotification(currentSeconds, category, isRunning, force: true);
  updateWidget(currentSeconds, category);

  service.on('setTimerData').listen((event) {
    if (event == null) return;
    if (event['seconds'] != null) currentSeconds = event['seconds'] as int;
    if (event['category'] != null) category = event['category'] as String;
    final newIsRunning = event['isRunning'] as bool?;
    if (newIsRunning != null) {
      setRunning(newIsRunning);
    } else {
      updateNotification(currentSeconds, category, isRunning, force: true);
    }
  });

  service.on('notificationAction').listen((event) {
    final action = event?['action'];
    if (action == 'pause') {
      setRunning(false);
    } else if (action == 'resume') {
      setRunning(true);
    } else if (action == 'stop') {
      service.invoke('stopFromNotification');
      service.stopSelf();
    }
  });

  service.on('requestSync').listen((event) {
    service.invoke('statusChange', {
      'isRunning': isRunning,
      'currentElapsed': currentSeconds,
    });
  });

  service.on('stopService').listen((event) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('bg_handoff_state');
    service.stopSelf();
  });
}
