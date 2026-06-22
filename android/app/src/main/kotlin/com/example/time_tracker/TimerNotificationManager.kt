package com.example.time_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

object TimerNotificationManager {
    private const val CHANNEL_ID = "timer_foreground_service_v3_silent"
    private const val NOTIFICATION_ID = 888

    fun show(context: Context, title: String, content: String, isRunning: Boolean) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Me Time 計時器",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                enableVibration(false)
                setSound(null, null)
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }

        val toggleAction = if (isRunning) "pause" else "resume"
        val toggleLabel = if (isRunning) "暫停" else "繼續"

        val toggleIntent = Intent(context, TimerActionReceiver::class.java).apply {
            putExtra("timer_action", toggleAction)
        }
        val togglePending = PendingIntent.getBroadcast(
            context, 1, toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(context, TimerActionReceiver::class.java).apply {
            putExtra("timer_action", "stop")
        }
        val stopPending = PendingIntent.getBroadcast(
            context, 2, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPending = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(isRunning)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSilent(true)
            .setSound(null)
            .setVibrate(null)
            .setDefaults(0)
            .setContentIntent(openPending)
            .addAction(0, toggleLabel, togglePending)
            .addAction(0, "停止", stopPending)
            .build()

        nm.notify(NOTIFICATION_ID, notification)
    }
}
