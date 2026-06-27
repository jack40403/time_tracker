import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/task_goal_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/current_focus_goals_provider.dart';
import '../services/notification_coordinator.dart';
import '../services/notification_launch_service.dart';

class AppLifecycleManager extends ConsumerStatefulWidget {
  final Widget child;
  const AppLifecycleManager({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends ConsumerState<AppLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      debugPrint('AppLifecycleManager: App entering background, triggering safety sync...');
      unawaited(ref.read(sessionsProvider.notifier).syncNow());
      unawaited(ref.read(goalProvider.notifier).syncNow());
      unawaited(ref.read(taskGoalProvider.notifier).syncNow());
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('AppLifecycleManager: App resumed, fetching absolute truth from cloud & background...');
      unawaited(_refreshFromServer());
    }
  }

  Future<void> _refreshFromServer() async {
    await Future.wait([
      ref.read(timerProvider.notifier).syncTimerFromServer(),
      ref.read(sessionsProvider.notifier).forceSyncFromCloud(),
      ref.read(goalProvider.notifier).forceSyncFromCloud(),
      ref.read(taskGoalProvider.notifier).forceSyncFromCloud(),
    ]);
    ref.invalidate(currentFocusGoalProgressProvider);
    ref.invalidate(incompleteFocusGoalProgressProvider);
    await NotificationCoordinator.instance.requestForegroundRefresh(
      ref,
      reason: 'app-resume',
      force: true,
    );
    await NotificationLaunchService.consumePendingTarget();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
