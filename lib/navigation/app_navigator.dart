import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/quick_focus_panel_page.dart';
import '../providers/main_tab_provider.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void openTimerPage() {
  final context = appNavigatorKey.currentContext;
  if (context == null) return;
  ProviderScope.containerOf(context)
      .read(mainTabIndexProvider.notifier)
      .setIndex(0);
}

Future<void> openQuickFocusPanel() async {
  final navigator = appNavigatorKey.currentState;
  final context = appNavigatorKey.currentContext;
  if (navigator == null || context == null) return;

  ProviderScope.containerOf(context)
      .read(mainTabIndexProvider.notifier)
      .setIndex(2);

  await navigator.push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const QuickFocusPanelPage(),
    ),
  );
}
