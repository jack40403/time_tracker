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

class _TimerNotificationSnapshot {
  const _TimerNotificationSnapshot({
    required this.serviceTitle,
    required this.serviceContent,
    required this.timerCategory,
    required this.timerStateLabel,
    required this.isRunning,
    required this.isTimerActive,
    required this.timerStartedAtEpochMs,
    required this.generationId,
  });

  final String serviceTitle;
  final String serviceContent;
  final String timerCategory;
  final String timerStateLabel;
  final bool isRunning;
  final bool isTimerActive;
  final int? timerStartedAtEpochMs;
  final String generationId;

  String get signature => [
        serviceTitle,
        serviceContent,
        timerCategory,
        timerStateLabel,
        isRunning,
        isTimerActive,
        timerStartedAtEpochMs,
        generationId,
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
    '計時器',
    description: '維持計時前景服務。',
    importance: Importance.low,
    enableVibration: false,
    playSound: false,
  );

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
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
      initialNotificationTitle: '計時器',
      initialNotificationContent: '準備啟動計時',
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
  String category = '未命名項目';
  bool isRunning = false;
  bool isTimerActive = false;
  String timerStateLabel = '計時準備中';
  int? timerStartedAtEpochMs;
  String generationId = 'background-initial';
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
      generationId = data['generationId']?.toString() ?? generationId;
    } catch (e) {
      debugPrint('TimerStateDebug source=onStart finalAction=handoff-decode-failed error=$e');
    }
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

  _TimerNotificationSnapshot buildSnapshot() {
    final content = isRunning
        ? '$category｜${formatClock(currentSeconds)}'
        : '$timerStateLabel｜${formatClock(currentSeconds)}';
    return _TimerNotificationSnapshot(
      serviceTitle: '計時器',
      serviceContent: content,
      timerCategory: category,
      timerStateLabel: timerStateLabel,
      isRunning: isRunning,
      isTimerActive: isTimerActive,
      timerStartedAtEpochMs: timerStartedAtEpochMs,
      generationId: generationId,
    );
  }

  void publish({bool force = false}) {
    if (service is! AndroidServiceInstance) return;
    final snapshot = buildSnapshot();
    if (!force && snapshot.signature == lastNotificationSignature) return;

    service.setForegroundNotificationInfo(
      title: snapshot.serviceTitle,
      content: snapshot.serviceContent,
    );
    service.invoke('updateNotification', {
      'title': snapshot.serviceTitle,
      'content': snapshot.serviceContent,
      'timerCategory': snapshot.timerCategory,
      'timerStateLabel': snapshot.timerStateLabel,
      'isRunning': snapshot.isRunning,
      'isTimerActive': snapshot.isTimerActive,
      'timerStartedAtEpochMs': snapshot.timerStartedAtEpochMs,
      'generationId': snapshot.generationId,
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
      debugPrint('TimerStateDebug source=updateWidget finalAction=failed error=$e');
    }
  }

  void emitStatus(String source) {
    service.invoke('statusChange', {
      'source': source,
      'isRunning': isRunning,
      'currentElapsed': currentSeconds,
      'generationId': generationId,
    });
  }

  void applyReset(String source, {String? nextGenerationId}) {
    currentSeconds = 0;
    isRunning = false;
    isTimerActive = false;
    timerStateLabel = '計時準備中';
    timerStartedAtEpochMs = null;
    if (nextGenerationId != null && nextGenerationId.isNotEmpty) {
      generationId = nextGenerationId;
    }
    debugPrint(
      'TimerStateDebug source=$source generationId=$generationId elapsed=$currentSeconds '
      'isRunning=$isRunning finalAction=background-reset',
    );
    publish(force: true);
    emitStatus(source);
  }

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    final currentPrefs = await SharedPreferences.getInstance();
    await currentPrefs.reload();
    final pendingAction = currentPrefs.getString('pending_timer_action');

    if (pendingAction != null) {
      await currentPrefs.remove('pending_timer_action');
      if (pendingAction == 'pause') {
        isRunning = false;
        timerStateLabel = currentSeconds > 0 ? '計時已暫停' : '計時準備中';
        timerStartedAtEpochMs = null;
        publish(force: true);
        emitStatus('notification-pause');
      } else if (pendingAction == 'resume') {
        isRunning = true;
        isTimerActive = true;
        timerStateLabel = '正在計時';
        timerStartedAtEpochMs =
            DateTime.now().millisecondsSinceEpoch - (currentSeconds * 1000);
        publish(force: true);
        emitStatus('notification-resume');
      } else if (pendingAction == 'stop') {
        service.invoke('stopFromNotification', {
          'generationId': generationId,
        });
        service.stopSelf();
        timer.cancel();
        return;
      }
    }

    if (isRunning) {
      currentSeconds++;
      updateWidget(currentSeconds, category);
    }
  });

  publish(force: true);
  updateWidget(currentSeconds, category);

  service.on('setTimerData').listen((event) {
    if (event == null) return;

    final incomingGenerationId =
        event['generationId']?.toString() ?? generationId;
    generationId = incomingGenerationId;
    currentSeconds = event['seconds'] as int? ?? currentSeconds;
    category = event['category'] as String? ?? category;
    isRunning = event['isRunning'] as bool? ?? isRunning;
    isTimerActive = event['isTimerActive'] as bool? ?? (isRunning || currentSeconds > 0);
    timerStateLabel = event['timerStateLabel'] as String? ??
        (isRunning ? '正在計時' : (currentSeconds > 0 ? '計時已暫停' : '計時準備中'));
    timerStartedAtEpochMs = event['timerStartedAtEpochMs'] as int?;

    publish(force: event['force'] as bool? ?? true);
  });

  service.on('setNotificationSnapshot').listen((event) {
    if (event == null) return;

    generationId = event['generationId']?.toString() ?? generationId;
    if (event['timerCategory'] != null) {
      category = event['timerCategory'] as String;
    }
    if (event['timerStateLabel'] != null) {
      timerStateLabel = event['timerStateLabel'] as String;
    }
    if (event['isRunning'] != null) {
      isRunning = event['isRunning'] as bool;
    }
    if (event['isTimerActive'] != null) {
      isTimerActive = event['isTimerActive'] as bool;
    }
    timerStartedAtEpochMs = event['timerStartedAtEpochMs'] as int?;
    publish(force: event['force'] as bool? ?? false);
  });

  service.on('clearNotificationSnapshot').listen((event) {
    applyReset(
      'clearNotificationSnapshot',
      nextGenerationId: event?['generationId']?.toString(),
    );
  });

  service.on('notificationAction').listen((event) {
    final action = event?['action'];
    if (action == 'pause') {
      isRunning = false;
      timerStateLabel = currentSeconds > 0 ? '計時已暫停' : '計時準備中';
      timerStartedAtEpochMs = null;
      publish(force: true);
      emitStatus('notificationAction-pause');
    } else if (action == 'resume') {
      isRunning = true;
      isTimerActive = true;
      timerStateLabel = '正在計時';
      timerStartedAtEpochMs =
          DateTime.now().millisecondsSinceEpoch - (currentSeconds * 1000);
      publish(force: true);
      emitStatus('notificationAction-resume');
    } else if (action == 'stop') {
      service.invoke('stopFromNotification', {
        'generationId': generationId,
      });
      service.stopSelf();
    }
  });

  service.on('requestSync').listen((event) {
    emitStatus('requestSync');
  });

  service.on('resetTimerState').listen((event) async {
    final nextGenerationId = event?['generationId']?.toString();
    final currentPrefs = await SharedPreferences.getInstance();
    await currentPrefs.remove('bg_handoff_state');
    await currentPrefs.remove('pending_timer_action');
    applyReset('resetTimerState', nextGenerationId: nextGenerationId);
  });

  service.on('stopService').listen((event) async {
    final currentPrefs = await SharedPreferences.getInstance();
    await currentPrefs.remove('bg_handoff_state');
    await currentPrefs.remove('pending_timer_action');
    service.stopSelf();
  });
}
