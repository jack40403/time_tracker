import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/update_service.dart';
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
  int _currentIndex = 0;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFFFFDE7);
    final borderColor = isDark ? const Color(0xFF48CAE4) : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(top: BorderSide(color: borderColor, width: 3)),
          boxShadow: [
            BoxShadow(color: borderColor.withOpacity(0.3), offset: const Offset(0, -3), blurRadius: 0),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer_rounded), label: '計時'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: '統計'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag_rounded), label: '目標'),
            NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: '歷史'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: '設定'),
          ],
        ),
      ),
    );
  }
}
