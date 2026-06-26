import 'package:flutter/services.dart';

import '../navigation/app_navigator.dart';

class NotificationLaunchService {
  NotificationLaunchService._();

  static const MethodChannel _channel =
      MethodChannel('notification_launch_channel');

  static bool _handling = false;

  static Future<void> consumePendingTarget() async {
    if (_handling) return;
    _handling = true;
    try {
      final target =
          await _channel.invokeMethod<String>('consumeLaunchTarget');
      if (target == null || target.isEmpty) return;

      if (target == 'quick_focus_panel') {
        await openQuickFocusPanel();
      }
    } finally {
      _handling = false;
    }
  }
}
