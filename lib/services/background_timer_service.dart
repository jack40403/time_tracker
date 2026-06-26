import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String notificationChannelId = 'timer_foreground_channel';
const int notificationId = 888;

bool _serviceConfigured = false;
bool _serviceStartInFlight = false;

class _NotificationSnapshot {
  const _NotificationSnapshot({
    required this.serviceTitle,
    required this.serviceContent,
    required this.timerCategory,
    required this.timerStateLabel,
    required this.focusSummary,
    required this.focusDetail,
    required this.isRunning,
    required this.isTimerActive,
    required this.timerStartedAtEpochMs,
  });

  final String serviceTitle;
  final String serviceContent;
  final String timerCategory;
  final String timerStateLabel;
  final String focusSummary;
  final String focusDetail;
  final bool isRunning;
  final bool isTimerActive;
  final int? timerStartedAtEpochMs;

  String get signature => [
        serviceTitle,
        serviceContent,
        timerCategory,
        timerStateLabel,
        focusSummary,
        focusDetail,
        isRunning,
        isTimerActive,
        timerStartedAtEpochMs,
      ].join('|');
}

@pragma('vm:entry-point')
void onNotificationActionTap(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (response.actionId == null) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('pending_timer_action', response.actionId!);

  FlutterBackgroundService().invoke('notificationAction', {
    'action': response.actionId,
  });
}

Future<void> initializeService() async {
  if (_serviceConfigured) return;

  final service = FlutterBackgroundService();
  const channel = AndroidNotificationChannel(
    notificationChannelId,
    'Me Time 專注通知',
    description: '維持計時服務並顯示目前專注目標摘要。',
    importance: Importance.low,
    enableVibration: false,
    playSound: false,
  );

  final notifications = FlutterLocalNotificationsPlugin();

  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await notifications.initialize(
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
      initialNotificationTitle: 'Me Time',
      initialNotificationContent: '準備啟動專注通知',
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.specialUse],
    ),
    iosConfiguration: IosConfiguration(),
  );

  _serviceConfigured = true;
}

Future<void> ensureBackgroundTimerServiceRunning() async {
  if (kIsWeb) return;

  await initializeService();

  if (_serviceStartInFlight) return;

  final service = FlutterBackgroundService();
  if (await service.isRunning()) return;

  _serviceStartInFlight = true;
  try {
    await service.startService();
  } finally {
    _serviceStartInFlight = false;
  }
}

Future<void> stopBackgroundTimerService() async {
  if (kIsWeb) return;
  FlutterBackgroundService().invoke('stopService');
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  int currentSeconds = 0;
  String category = '專注計時';
  bool isRunning = false;
  bool isTimerActive = false;
  String timerStateLabel = '計時準備中';
  String focusSummary = '沒有未完成的專注目標';
  String focusDetail = '目前沒有需要顯示的專注目標';
  int? timerStartedAtEpochMs;
  int pausedSeconds = 0;
  const autoStopTimeout = 30 * 60;
  String? lastNotificationSignature;

  final prefs = await SharedPreferences.getInstance();
  final handoffRaw = prefs.getString('bg_handoff_state');
  if (handoffRaw != null) {
    try {
      final data = jsonDecode(handoffRaw) as Map<String, dynamic>;
      currentSeconds = data['seconds'] as int? ?? 0;
      category = data['category'] as String? ?? category;
      isRunning = data['isRunning'] as bool? ?? false;
      isTimerActive = data['isTimerActive'] as bool? ?? (isRunning || currentSeconds > 0);
      timerStateLabel = data['timerStateLabel'] as String? ??
          (isRunning ? '正在計時' : (currentSeconds > 0 ? '計時已暫停' : '計時準備中'));
      timerStartedAtEpochMs = data['timerStartedAtEpochMs'] as int?;
    } catch (e) {
      debugPrint('BackgroundService: Error decoding handoff state: $e');
    }
  } else {
    isTimerActive = isRunning || currentSeconds > 0;
    timerStateLabel = isRunning ? '正在計時' : (currentSeconds > 0 ? '計時已暫停' : '計時準備中');
  }

  String formatClock(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final secs = safeSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  _NotificationSnapshot buildNotificationSnapshot() {
    final serviceContent = isTimerActive
        ? '$timerStateLabel｜$focusSummary'
        : focusSummary;
    return _NotificationSnapshot(
      serviceTitle: 'Me Time',
      serviceContent: serviceContent,
      timerCategory: category,
      timerStateLabel: timerStateLabel,
      focusSummary: focusSummary,
      focusDetail: focusDetail,
      isRunning: isRunning,
      isTimerActive: isTimerActive,
      timerStartedAtEpochMs: timerStartedAtEpochMs,
    );
  }

  bool shouldUpdateNotification(_NotificationSnapshot snapshot, {required bool force}) {
    if (force) return true;
    return snapshot.signature != lastNotificationSignature;
  }

  void publishNotification({bool force = false}) {
    if (service is! AndroidServiceInstance) return;

    final snapshot = buildNotificationSnapshot();
    if (!shouldUpdateNotification(snapshot, force: force)) return;

    service.setForegroundNotificationInfo(
      title: snapshot.serviceTitle,
      content: snapshot.serviceContent,
    );

    service.invoke('updateNotification', {
      'title': snapshot.serviceTitle,
      'content': snapshot.serviceContent,
      'timerCategory': snapshot.timerCategory,
      'timerStateLabel': snapshot.timerStateLabel,
      'focusSummary': snapshot.focusSummary,
      'focusDetail': snapshot.focusDetail,
      'isRunning': snapshot.isRunning,
      'isTimerActive': snapshot.isTimerActive,
      'timerStartedAtEpochMs': snapshot.timerStartedAtEpochMs,
    });

    lastNotificationSignature = snapshot.signature;
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
    isTimerActive = running || currentSeconds > 0;
    timerStateLabel = running ? '正在計時' : (currentSeconds > 0 ? '計時已暫停' : '計時準備中');
    timerStartedAtEpochMs = running
        ? DateTime.now().millisecondsSinceEpoch - (currentSeconds * 1000)
        : null;
    if (isRunning) pausedSeconds = 0;

    publishNotification(force: true);
    service.invoke('statusChange', {
      'isRunning': isRunning,
      'currentElapsed': currentSeconds,
    });
  }

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    final currentPrefs = await SharedPreferences.getInstance();
    await currentPrefs.reload();
    final pendingAction = currentPrefs.getString('pending_timer_action');

    if (pendingAction != null) {
      await currentPrefs.remove('pending_timer_action');
      if (pendingAction == 'pause') {
        setRunning(false);
      } else if (pendingAction == 'resume') {
        setRunning(true);
      } else if (pendingAction == 'stop') {
        service.invoke('stopFromNotification');
        service.stopSelf();
        timer.cancel();
        return;
      }
    }

    if (isRunning) {
      currentSeconds++;
      pausedSeconds = 0;
      updateWidget(currentSeconds, category);
    } else {
      pausedSeconds++;
      if (pausedSeconds >= autoStopTimeout) {
        service.stopSelf();
        timer.cancel();
        return;
      }
      updateWidget(currentSeconds, category);
    }
  });

  publishNotification(force: true);
  updateWidget(currentSeconds, category);

  service.on('setTimerData').listen((event) {
    if (event == null) return;

    if (event['seconds'] != null) currentSeconds = event['seconds'] as int;
    if (event['category'] != null) category = event['category'] as String;
    if (event['isTimerActive'] != null) {
      isTimerActive = event['isTimerActive'] as bool;
    }
    if (event['timerStateLabel'] != null) {
      timerStateLabel = event['timerStateLabel'] as String;
    }
    if (event['timerStartedAtEpochMs'] != null) {
      timerStartedAtEpochMs = event['timerStartedAtEpochMs'] as int?;
    }

    final newIsRunning = event['isRunning'] as bool?;
    if (newIsRunning != null) {
      setRunning(newIsRunning);
      return;
    }

    publishNotification(force: true);
  });

  service.on('setNotificationSnapshot').listen((event) {
    if (event == null) return;

    focusSummary = event['focusSummary'] as String? ?? focusSummary;
    focusDetail = event['focusDetail'] as String? ?? focusDetail;
    if (event['timerCategory'] != null) category = event['timerCategory'] as String;
    if (event['timerStateLabel'] != null) {
      timerStateLabel = event['timerStateLabel'] as String;
    }
    if (event['isTimerActive'] != null) {
      isTimerActive = event['isTimerActive'] as bool;
    }
    if (event['timerStartedAtEpochMs'] != null) {
      timerStartedAtEpochMs = event['timerStartedAtEpochMs'] as int?;
    }

    publishNotification(force: event['force'] as bool? ?? false);
  });

  service.on('clearNotificationSnapshot').listen((event) {
    focusSummary = '沒有未完成的專注目標';
    focusDetail = '目前沒有需要顯示的專注目標';
    isTimerActive = isRunning || currentSeconds > 0;
    timerStateLabel = isRunning ? '正在計時' : (currentSeconds > 0 ? '計時已暫停' : '計時準備中');
    timerStartedAtEpochMs = isRunning
        ? DateTime.now().millisecondsSinceEpoch - (currentSeconds * 1000)
        : null;
    publishNotification(force: true);
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
    final currentPrefs = await SharedPreferences.getInstance();
    await currentPrefs.remove('bg_handoff_state');
    service.stopSelf();
  });
}
