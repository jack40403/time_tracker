import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Notification Channel constants
const String notificationChannelId = 'timer_foreground_service';
const int notificationId = 888;

@pragma('vm:entry-point')
void onNotificationActionTap(NotificationResponse response) {
  if (response.payload != null || response.actionId != null) {
    // We send a message to the running service isolate
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
    'Elite Timer Service',
    description: 'This channel is used for the ongoing timer notification.',
    importance: Importance.defaultImportance, // Upgraded for visibility of buttons
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
      initialNotificationContent: '準備計時...',
      foregroundServiceNotificationId: notificationId,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  Timer? periodicTimer;
  int currentSeconds = 0;
  String category = 'Focus';
  bool isRunning = false;
  DateTime? startTime;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  void updateNotification(int current, String cat, bool running) {
    if (service is AndroidServiceInstance) {
      final hours = current ~/ 3600;
      final minutes = (current % 3600) ~/ 60;
      final seconds = current % 60;
      final timeStr = '${hours > 0 ? '$hours:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      flutterLocalNotificationsPlugin.show(
        notificationId,
        running ? '正在計時: $cat' : '計時已暫停: $cat',
        '累計時間: $timeStr',
        NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            'Elite Timer Service',
            ongoing: true,
            icon: '@mipmap/ic_launcher',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            showWhen: running,
            usesChronometer: running,
            when: running ? DateTime.now().millisecondsSinceEpoch - (current * 1000) : null,
            styleInformation: const MediaStyleInformation(),
            actions: [
              AndroidNotificationAction(
                running ? 'pause' : 'resume',
                running ? '暫停' : '繼續',
                icon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              ),
              const AndroidNotificationAction(
                'stop',
                '停止',
                icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              ),
            ],
          ),
        ),
      );
    }
  }

  void startTimer() {
    periodicTimer?.cancel();
    periodicTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (isRunning) {
        currentSeconds++;
        // We only update the notification periodically to sync, 
        // but usesChronometer handles the smooth visual update.
        if (currentSeconds % 5 == 0) {
          updateNotification(currentSeconds, category, isRunning);
        }
        service.invoke('update', {
          'currentElapsed': currentSeconds,
          'category': category,
        });
      }
    });
  }

  void setRunning(bool running) {
    if (running && !isRunning) {
      isRunning = true;
      startTimer();
      updateNotification(currentSeconds, category, isRunning);
    } else if (!running && isRunning) {
      isRunning = false;
      periodicTimer?.cancel();
      updateNotification(currentSeconds, category, isRunning);
    }
    
    // Notify the UI
    service.invoke('statusChange', {
      'isRunning': isRunning,
      'currentElapsed': currentSeconds,
    });
  }

  service.on('setTimerData').listen((event) {
    if (event != null) {
      if (event['seconds'] != null) currentSeconds = event['seconds'];
      if (event['category'] != null) category = event['category'];
      
      bool? newIsRunning = event['isRunning'];
      if (newIsRunning != null) {
        setRunning(newIsRunning);
      } else {
        // Just data update, refresh notification
        updateNotification(currentSeconds, category, isRunning);
      }
    }
  });

  service.on('notificationAction').listen((event) {
    final action = event?['action'];
    if (action == 'pause') {
      setRunning(false);
    } else if (action == 'resume') {
      setRunning(true);
    } else if (action == 'stop') {
      periodicTimer?.cancel();
      service.invoke('stopFromNotification');
      service.stopSelf();
    }
  });

  service.on('stopService').listen((event) {
    periodicTimer?.cancel();
    service.stopSelf();
  });

  // Initial update
  updateNotification(currentSeconds, category, isRunning);
  if (isRunning) startTimer();
}
