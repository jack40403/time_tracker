import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/task_goal_provider.dart';
import '../providers/timer_provider.dart';

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
      unawaited(ref.read(timerProvider.notifier).syncTimerFromServer());
      
      unawaited(ref.read(sessionsProvider.notifier).forceSyncFromCloud());
      unawaited(ref.read(goalProvider.notifier).forceSyncFromCloud());
      unawaited(ref.read(taskGoalProvider.notifier).forceSyncFromCloud());
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
