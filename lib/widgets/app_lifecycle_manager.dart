import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
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
    // 當 App 進入背景 (paused) 或失去焦點 (inactive) 時觸發同步
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      debugPrint('AppLifecycleManager: App entering background, triggering safety sync...');
      
      // 觸發計時紀錄同步
      ref.read(sessionsProvider.notifier).syncNow();
      
      // 觸發任務型目標同步
      ref.read(taskGoalProvider.notifier).syncNow();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('AppLifecycleManager: App resumed, fetching absolute truth from background...');
      ref.read(timerProvider.notifier).requestBackgroundSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
