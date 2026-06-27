package com.example.time_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

object TimerNotificationManager {
    private const val CHANNEL_ID = "timer_foreground_channel"
    private const val NOTIFICATION_ID = 888

    fun show(
        context: Context,
        title: String,
        content: String,
        timerCategory: String,
        timerStateLabel: String,
        focusSummary: String,
        focusDetail: String,
        isRunning: Boolean,
        isTimerActive: Boolean,
        timerStartedAtEpochMs: Long?
    ) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "計時器",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                enableVibration(false)
                setSound(null, null)
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val toggleAction = if (isRunning) "pause" else "resume"
        val toggleLabel = if (isRunning) "暫停" else "繼續"

        val toggleIntent = Intent(context, TimerActionReceiver::class.java).apply {
            putExtra("timer_action", toggleAction)
        }
        val togglePendingIntent = PendingIntent.getBroadcast(
            context,
            1,
            toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(context, TimerActionReceiver::class.java).apply {
            putExtra("timer_action", "stop")
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            2,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_target", "timer_page")
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val bigText = buildString {
            append(timerStateLabel)
            if (timerCategory.isNotBlank()) {
                append('\n')
                append(timerCategory)
            }
            append("\n\n點擊返回計時頁")
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSubText("計時器")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(bigText)
                    .setBigContentTitle("計時器")
                    .setSummaryText(timerCategory)
            )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSilent(true)
            .setSound(null)
            .setVibrate(null)
            .setDefaults(0)
            .setContentIntent(openPendingIntent)

        if (isTimerActive) {
            builder
                .addAction(0, toggleLabel, togglePendingIntent)
                .addAction(0, "停止", stopPendingIntent)
        }

        if (isRunning && timerStartedAtEpochMs != null) {
            builder
                .setUsesChronometer(true)
                .setChronometerCountDown(false)
                .setWhen(timerStartedAtEpochMs)
                .setShowWhen(true)
        } else {
            builder.setShowWhen(false)
        }

        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }
}
