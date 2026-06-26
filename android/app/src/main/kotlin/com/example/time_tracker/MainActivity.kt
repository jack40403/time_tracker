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
                    val isRunning = call.argument<Boolean>("isRunning") ?: false
                    val elapsedSeconds = call.argument<Int>("elapsedSeconds") ?: 0
                    TimerNotificationManager.show(
                        applicationContext,
                        title,
                        content,
                        isRunning,
                        elapsedSeconds
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
