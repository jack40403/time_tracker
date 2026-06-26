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
                "Me Time 專注通知",
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
            putExtra("notification_target", "quick_focus_panel")
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val detailLines = focusDetail
            .split("\n")
            .map { it.trimEnd() }
            .filter { it.isNotBlank() }

        val inboxStyle = NotificationCompat.InboxStyle()
            .setBigContentTitle("專注目標")
            .setSummaryText(focusSummary)

        val timerHeadline = if (isTimerActive) {
            buildString {
                append(timerStateLabel)
                if (timerCategory.isNotBlank()) {
                    append("｜")
                    append(timerCategory)
                }
            }
        } else {
            "目前沒有進行中的計時"
        }
        inboxStyle.addLine(timerHeadline)
        inboxStyle.addLine("────────────")
        inboxStyle.addLine(focusSummary)
        detailLines.forEach { inboxStyle.addLine(it) }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSubText("專注目標")
            .setStyle(inboxStyle)
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
