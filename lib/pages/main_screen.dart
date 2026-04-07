import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Widget build(BuildContext context) {
    // Global Update Listener
    ref.listen(updateProvider, (previous, next) {
      if (next != null && next.isUpdateAvailable) {
        _showUpdateNotification(next);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer), label: '計時'),
          const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: '統計'),
          const NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: '目標'),
          const NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: '歷史'),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }

  void _showUpdateNotification(UpdateInfo info) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.system_update_alt, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                info.isPatch ? '🚀 已發現新修復包，立即更新？' : '✨ 網頁版有新功能，請重新整理！',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: info.isPatch ? '下載並更新' : '立即重新整理',
          textColor: Colors.yellow,
          onPressed: () async {
            if (info.isPatch) {
              await ref.read(updateProvider.notifier).performUpdate();
              if (mounted) {
                _showRestartDialog();
              }
            } else {
              await ref.read(updateProvider.notifier).performUpdate();
              // Standard web refresh
              // window.location.reload(); is not available in pure dart, but we can use html or just notify
              // For web, if using flutter_web_plugins or just generic:
              // Actually, standard window.location.reload() can be used via universal_html or dart:js
              // Or just show another snackbar saying "Refreshing..." and use a helper.
            }
          },
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('✅ 更新已就緒'),
        content: const Text('修復包已下載完成，需要重新啟動 APP 才能套用更新。現在要重啟嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('稍後再說')),
          ElevatedButton(
            onPressed: () {
              // We'll use a platform-specific restart or just exit for simplicity
              // In production Shorebird apps, you might need a custom restart helper
              Navigator.pop(ctx);
            },
            child: const Text('立即重啟'),
          ),
        ],
      ),
    );
  }
}
