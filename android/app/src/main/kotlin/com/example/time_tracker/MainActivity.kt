package com.example.time_tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "timer_notification_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "show") {
                    val title = call.argument<String>("title") ?: ""
                    val content = call.argument<String>("content") ?: ""
                    val timerCategory = call.argument<String>("timerCategory") ?: ""
                    val timerStateLabel = call.argument<String>("timerStateLabel") ?: ""
                    val focusSummary = call.argument<String>("focusSummary") ?: ""
                    val focusDetail = call.argument<String>("focusDetail") ?: ""
                    val isRunning = call.argument<Boolean>("isRunning") ?: false
                    val isTimerActive = call.argument<Boolean>("isTimerActive") ?: false
                    val timerStartedAtEpochMs = call.argument<Number>("timerStartedAtEpochMs")?.toLong()
                    TimerNotificationManager.show(
                        applicationContext,
                        title,
                        content,
                        timerCategory,
                        timerStateLabel,
                        focusSummary,
                        focusDetail,
                        isRunning,
                        isTimerActive,
                        timerStartedAtEpochMs
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
