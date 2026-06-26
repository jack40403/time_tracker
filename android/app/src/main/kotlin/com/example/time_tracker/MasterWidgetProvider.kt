package com.example.time_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.example.time_tracker.R
import es.antonborri.home_widget.HomeWidgetProvider

class MasterWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        try {
            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.master_widget).apply {
                    // 安全獲取資料，提供明確預設值
                    val taskName = widgetData.getString("task_name", "準備開始專注") ?: "準備開始專注"
                    val timerText = widgetData.getString("timer_text", "00:00:00") ?: "00:00:00"
                    
                    setTextViewText(R.id.widget_task_name, taskName)
                    setTextViewText(R.id.widget_timer_text, timerText)
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        } catch (e: Exception) {
            android.util.Log.e("MasterWidget", "Error updating widget: ${e.message}")
        }
    }
}
