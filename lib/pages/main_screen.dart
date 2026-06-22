import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/update_service.dart';
import '../providers/app_theme_provider.dart';
import '../providers/main_tab_provider.dart';
import 'home_page.dart';
import 'statistics_page.dart';
import 'history_page.dart';
import 'goals_page.dart';
import 'settings_page.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});
  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _pages = [
    const HomePage(),
    const StatisticsPage(),
    const GoalsPage(),
    const HistoryPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 啟動時檢查更新
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. 檢查更新
      final info = await UpdateService.checkUpdate();
      if (info != null && mounted) {
        UpdateService.showUpdateDialog(context, info);
      }

      // 2. 請求 Android 13+ 通知權限 (必要用於持久化通知欄)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(currentAppThemeProvider);
    final currentIndex = ref.watch(mainTabIndexProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: IndexedStack(index: currentIndex, children: _pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: t.navBg,
          border: Border(top: BorderSide(color: t.navBorder, width: 3)),
          boxShadow: [
            BoxShadow(color: t.navBorder.withOpacity(0.3), offset: const Offset(0, -3), blurRadius: 0),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(size: 26, color: t.actionInk);
              }
              return IconThemeData(size: 26, color: t.navInk);
            }),
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => ref.read(mainTabIndexProvider.notifier).setIndex(index),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            indicatorColor: t.active,
            labelTextStyle: WidgetStateProperty.all(
              TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.navInk),
            ),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer_rounded), label: '計時'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: '統計'),
              NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag_rounded), label: '目標'),
              NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: '歷史'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: '設定'),
            ],
          ),
        ),
      ),
    );
  }
}
