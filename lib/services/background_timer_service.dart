import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Notification Channel constants
const String notificationChannelId = 'timer_foreground_service_v3_silent';
const int notificationId = 888;

@pragma('vm:entry-point')
void onNotificationActionTap(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('NotificationTap: Received action ${response.actionId}');
  
  if (response.actionId != null) {
    // ATOMIC BRIDGE: Save the action to SharedPreferences so the background isolate 
    // can pick it up even if the IPC 'invoke' signal fails.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_timer_action', response.actionId!);
    
    // Also try the standard IPC as a fallback
    FlutterBackgroundService().invoke('notificationAction', {
      'action': response.actionId,
    });
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Android notification channel setup
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId, 
    'Me Time Timer (Silent)',
    description: 'This channel is used for the ongoing timer notification.',
    importance: Importance.min,
    enableVibration: false,
    playSound: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Initialize notifications to handle background actions
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  
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
      initialNotificationTitle: 'Elite Time Tracker',
      initialNotificationContent: '計時中...', 
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.specialUse],
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // --- STATE INITIALIZATION ---
  int currentSeconds = 0;
  String category = 'Focus';
  bool isRunning = false;

  final prefs = await SharedPreferences.getInstance();
  
  // HANDOFF LOGIC: Try to inherit state from the last UI session
  final handoffRaw = prefs.getString('bg_handoff_state');
  if (handoffRaw != null) {
    try {
      final Map<String, dynamic> data = jsonDecode(handoffRaw);
      currentSeconds = data['seconds'] ?? 0;
      category = data['category'] ?? 'Focus';
      isRunning = data['isRunning'] ?? false;
      debugPrint('BackgroundService: Inherited state - ${currentSeconds}s, $category, running: $isRunning');
    } catch (e) {
      debugPrint('BackgroundService: Error decoding handoff state: $e');
    }
  }

  int pausedSeconds = 0;
  const int autoStopTimeout = 30 * 60; // 30 minutes

  // Define functions FIRST to avoid declaration order issues
  void updateNotification(int current, String cat, bool running) {
    if (service is AndroidServiceInstance) {
      final hours = current ~/ 3600;
      final minutes = (current % 3600) ~/ 60;
      final seconds = current % 60;
      final timeStr = '${hours > 0 ? '$hours:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      final title = running ? '正在計時: $cat' : '計時已暫停: $cat';
      final content = '累計時間: $timeStr';

      // Fallback: always update the foreground service notification (no action buttons,
      // but guaranteed to work even when the main app is killed).
      service.setForegroundNotificationInfo(title: title, content: content);

      // Relay to main app, which calls Kotlin TimerNotificationManager to show
      // the notification with proper PendingIntent action buttons.
      service.invoke('updateNotification', {
        'title': title,
        'content': content,
        'isRunning': running,
      });
    }
  }

  
  void updateWidget(int current, String cat) {
    final hours = current ~/ 3600;
    final minutes = (current % 3600) ~/ 60;
    final seconds = current % 60;
    final timeStr = '${hours > 0 ? '$hours:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    if (kIsWeb) return; // HomeWidget is not supported on Web
    try {
      HomeWidget.saveWidgetData<String>('task_name', cat);
      HomeWidget.saveWidgetData<String>('timer_text', timeStr);
      HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.example.time_tracker.MasterWidgetProvider',
      );
    } catch (e) {
      debugPrint('BackgroundService: Widget update failed: $e');
    }
  }

  void setRunning(bool running) {
    isRunning = running;
    if (isRunning) pausedSeconds = 0; // Reset pause timer
    updateNotification(currentSeconds, category, isRunning);
    service.invoke('statusChange', {
      'isRunning': isRunning,
      'currentElapsed': currentSeconds,
    });
  }

  // --- Master Watchdog Timer (Always Online) ---
  // This timer handles BOTH counting and Atomic Prefs Bridge polling.
  Timer.periodic(const Duration(seconds: 1), (t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force re-read from disk; cross-isolate writes are not visible otherwise.
    final pendingAction = prefs.getString('pending_timer_action');
    
    if (pendingAction != null) {
      debugPrint('BackgroundService: Master Watchdog picked up action: $pendingAction');
      await prefs.remove('pending_timer_action');
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
      updateNotification(currentSeconds, category, isRunning);
      updateWidget(currentSeconds, category);
      service.invoke('update', {
        'currentElapsed': currentSeconds,
        'category': category,
      });
    } else {
      pausedSeconds++;
      // AUTO-STOP: If paused for too long, kill the service to avoid "ghost" status bar
      if (pausedSeconds >= autoStopTimeout) {
        debugPrint('BackgroundService: Paused timeout reached. Stopping service...');
        service.stopSelf();
        return;
      }
      updateNotification(currentSeconds, category, isRunning);
      updateWidget(currentSeconds, category);
    }
  });

  // INITIAL STATE
  updateNotification(currentSeconds, category, isRunning);
  updateWidget(currentSeconds, category);

  service.on('setTimerData').listen((event) {
    if (event != null) {
      if (event['seconds'] != null) currentSeconds = event['seconds'];
      if (event['category'] != null) category = event['category'];
      bool? newIsRunning = event['isRunning'];
      if (newIsRunning != null) setRunning(newIsRunning);
      else updateNotification(currentSeconds, category, isRunning);
    }
  });

  service.on('notificationAction').listen((event) {
    final action = event?['action'];
    if (action == 'pause') setRunning(false);
    else if (action == 'resume') setRunning(true);
    else if (action == 'stop') {
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
    await p.remove('bg_handoff_state'); // Clear on explicit stop
    service.stopSelf();
  });
}
