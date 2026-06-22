import 'package:flutter/material.dart';

import '../pages/quick_focus_panel_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> openQuickFocusPanel() async {
  final navigator = appNavigatorKey.currentState;
  final context = appNavigatorKey.currentContext;
  if (navigator == null || context == null) return;

  await navigator.push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const QuickFocusPanelPage(),
    ),
  );
}
