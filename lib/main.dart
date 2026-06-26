import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/update_service.dart';
import 'services/background_timer_service.dart';
import 'services/notification_service.dart';
import 'services/goal_reminder_notification_service.dart';
import 'services/notification_coordinator.dart';
import 'providers/layout_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/current_focus_goals_provider.dart';
import 'providers/timer_provider.dart';
import 'navigation/app_navigator.dart';
import 'firebase_options.dart';
import 'widgets/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_theme_provider.dart';

// Main Entry Point
// ==========================================

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // 保留原生啟動圖，直到我們手動移除
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize App
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    await initializeService();
    await NotificationService.init();
  }

  // Listen for notification update events from background service and relay to Kotlin.
  // Kotlin (TimerNotificationManager) shows the notification with native PendingIntents
  // so action buttons reliably reach TimerActionReceiver.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    const timerNotifChannel = MethodChannel('timer_notification_channel');
    FlutterBackgroundService().on('updateNotification').listen((data) async {
      if (data != null) {
        try {
          await timerNotifChannel.invokeMethod('show', {
            'title': data['title'],
            'content': data['content'],
            'timerCategory': data['timerCategory'],
            'timerStateLabel': data['timerStateLabel'],
            'focusSummary': data['focusSummary'],
            'focusDetail': data['focusDetail'],
            'isRunning': data['isRunning'],
            'isTimerActive': data['isTimerActive'],
            'timerStartedAtEpochMs': data['timerStartedAtEpochMs'],
          });
        } catch (e) {
          debugPrint('TimerNotification relay failed: $e');
        }
      }
    });
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TimeTrackerApp(),
    ),
  );

  // 移除原生啟動圖，讓 Flutter SplashScreen 接手
  FlutterNativeSplash.remove();

  // Passive initial update check
  Future.delayed(const Duration(seconds: 1), () {
    final container = ProviderScope.containerOf(WidgetsBinding.instance.rootElement!);
    container.read(updateProvider.notifier).checkUpdates();
  });
}

class TimeTrackerApp extends ConsumerWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final appTheme = ref.watch(currentAppThemeProvider);
    ref.listen(timerProvider, (previous, next) {
      final force = previous == null ||
          previous.isRunning != next.isRunning ||
          previous.category != next.category ||
          previous.currentElapsed <= 0 != (next.currentElapsed <= 0);
      unawaited(
        NotificationCoordinator.instance.requestForegroundRefresh(
          ref,
          reason: 'timer-state',
          force: force,
        ),
      );
    });
    ref.listen(currentFocusGoalProgressProvider, (previous, next) {
      unawaited(
        NotificationCoordinator.instance.requestForegroundRefresh(
          ref,
          reason: 'focus-progress',
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        NotificationCoordinator.instance.requestForegroundRefresh(
          ref,
          reason: 'app-build',
          force: true,
        ),
      );
      GoalReminderNotificationService.openPanelAfterLaunchIfNeeded();
    });
    // 每個 AppTheme 有固定設計亮度，強制 Material theme 跟著走，避免系統亮度不符造成文字撞背景
    const darkAppThemeIds = {'dark'};
    final effectiveThemeMode = darkAppThemeIds.contains(appTheme.id) ? ThemeMode.dark : ThemeMode.light;

    final baseLightTextTheme = GoogleFonts.outfitTextTheme();
    final baseDarkTextTheme = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);

    TextTheme enlarge(TextTheme base) => base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: 36),
      displayMedium: base.displayMedium?.copyWith(fontSize: 32),
      displaySmall: base.displaySmall?.copyWith(fontSize: 28),
      headlineLarge: base.headlineLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.bold),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
      titleLarge: base.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
      titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12),
      labelLarge: base.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
      labelMedium: base.labelMedium?.copyWith(fontSize: 12),
      labelSmall: base.labelSmall?.copyWith(fontSize: 11),
    );

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Me Time',
      debugShowCheckedModeBanner: false,
      themeMode: effectiveThemeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0077B6),
          primary: const Color(0xFF0077B6),
          secondary: const Color(0xFFFFD60A),
          surface: const Color(0xFFFFFDE7),
        ),
        useMaterial3: true,
        textTheme: enlarge(baseLightTextTheme),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFDE7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF1A1A2E), width: 3),
          ),
          elevation: 0,
          margin: const EdgeInsets.all(8),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF1A1A2E), width: 2),
          ),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFFFD60A),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFFDE7),
          indicatorColor: const Color(0xFFFFD60A),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(size: 26, color: Color(0xFF1A1A2E));
            }
            return const IconThemeData(size: 26, color: Color(0xFF0077B6));
          }),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFFFDE7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF1A1A2E), width: 3),
          ),
          elevation: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1A1A2E),
          contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0077B6),
          brightness: Brightness.dark,
          surface: const Color(0xFF1A1A2E),
        ),
        useMaterial3: true,
        textTheme: enlarge(baseDarkTextTheme),
        cardTheme: CardThemeData(
          color: const Color(0xFF0D2137),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF48CAE4), width: 2.5),
          ),
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1A1A2E),
          indicatorColor: const Color(0xFFFFD60A),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(size: 26, color: Color(0xFF1A1A2E));
            }
            return const IconThemeData(size: 26, color: Color(0xFF48CAE4));
          }),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF0D2137),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF48CAE4), width: 2.5),
          ),
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
