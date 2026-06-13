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
    // ??App ?脣? (paused) ?仃?餌暺?(inactive) ?孛?澆?甇?    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      debugPrint('AppLifecycleManager: App entering background, triggering safety sync...');
      
      // 閫貊閮?蝝??甇?      ref.read(sessionsProvider.notifier).syncNow();
      
      // 閫貊隞餃??璅?甇?      ref.read(taskGoalProvider.notifier).syncNow();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('AppLifecycleManager: App resumed, fetching absolute truth from cloud & background...');
      unawaited(ref.read(timerProvider.notifier).syncTimerFromServer());
      
      // 2. 銝餃?敺蝡舀????唳??(蝜??砍敹怠?)
      ref.read(sessionsProvider.notifier).forceSyncFromCloud();
      ref.read(goalProvider.notifier).forceSyncFromCloud();
      ref.read(taskGoalProvider.notifier).forceSyncFromCloud();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
