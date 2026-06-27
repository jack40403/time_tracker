import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../navigation/app_navigator.dart';

class NotificationLaunchService {
  NotificationLaunchService._();

  static const String focusQuickPanelPayload = 'focus_goals_quick_panel';
  static const String timerPagePayload = 'timer_page';

  static const MethodChannel _channel =
      MethodChannel('notification_launch_channel');

  static bool _handling = false;
  static String? _pendingRoute;

  static void setPendingRoute(String? route) {
    if (route == null || route.isEmpty) return;
    _pendingRoute = route;
    _log(
      sourceMethod: 'setPendingRoute',
      targetRoute: route,
      finalAction: 'stored-pending-route',
    );
  }

  static Future<void> handleNotificationPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    setPendingRoute(payload);
    await consumePendingTarget();
  }

  static Future<void> consumePendingTarget() async {
    if (_handling) return;
    _handling = true;
    try {
      final nativeTarget =
          await _channel.invokeMethod<String>('consumeLaunchTarget');
      final target = nativeTarget ?? _pendingRoute;
      if (target == null || target.isEmpty) return;

      _pendingRoute = null;
      if (target == focusQuickPanelPayload ||
          target == 'quick_focus_panel') {
        _log(
          sourceMethod: 'consumePendingTarget',
          targetRoute: focusQuickPanelPayload,
          finalAction: 'open-quick-focus-panel',
        );
        await openQuickFocusPanel();
        return;
      }

      if (target == timerPagePayload || target == 'timer_page') {
        _log(
          sourceMethod: 'consumePendingTarget',
          targetRoute: timerPagePayload,
          finalAction: 'open-timer-page',
        );
        openTimerPage();
      }
    } finally {
      _handling = false;
    }
  }

  static void _log({
    required String sourceMethod,
    required String targetRoute,
    required String finalAction,
  }) {
    debugPrint(
      'NotificationRouteDebug '
      'source=$sourceMethod '
      'targetRoute=$targetRoute '
      'finalAction=$finalAction',
    );
  }
}
