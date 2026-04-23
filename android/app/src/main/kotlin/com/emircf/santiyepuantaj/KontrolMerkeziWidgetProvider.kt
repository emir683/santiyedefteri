package com.emircf.santiyepuantaj

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class KontrolMerkeziWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (
            intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, KontrolMerkeziWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(component)
            widgetIds.forEach { appWidgetId ->
                updateWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val teamName =
                widgetData.getString("km_team_name", "Santiye Puantaj Defteri")
                    ?: "Santiye Puantaj Defteri"
            val monthLabel = widgetData.getString("km_month_label", "Ay ozeti") ?: "Ay ozeti"
            val reportDays = readIntSafely(widgetData, "km_report_days")
            val workerCount = readIntSafely(widgetData, "km_worker_count")
            val siteCount = readIntSafely(widgetData, "km_site_count")
            val paymentTotal = widgetData.getString("km_payment_total", "Kilitli") ?: "Kilitli"
            val expenseTotal = widgetData.getString("km_expense_total", "Kilitli") ?: "Kilitli"

            val launchIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("santiyeapp://widget/quick-report"),
                context,
                MainActivity::class.java
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                20260330,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val views = RemoteViews(context.packageName, R.layout.kontrol_merkezi_widget).apply {
                setTextViewText(R.id.widgetTeamName, teamName)
                setTextViewText(R.id.widgetMonthLabel, monthLabel)
                setTextViewText(R.id.widgetReportDaysValue, reportDays.toString())
                setTextViewText(R.id.widgetWorkerCountValue, workerCount.toString())
                setTextViewText(R.id.widgetSiteCountValue, siteCount.toString())
                setTextViewText(R.id.widgetPaymentValue, paymentTotal)
                setTextViewText(R.id.widgetExpenseValue, "Masraf: $expenseTotal")
                setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)
                setOnClickPendingIntent(R.id.widgetQuickReportButton, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (_: Exception) {
            val fallback = RemoteViews(context.packageName, R.layout.kontrol_merkezi_widget).apply {
                setTextViewText(R.id.widgetTeamName, "Santiye Puantaj Defteri")
                setTextViewText(R.id.widgetMonthLabel, "Kontrol Merkezi")
                setTextViewText(R.id.widgetReportDaysValue, "0")
                setTextViewText(R.id.widgetWorkerCountValue, "0")
                setTextViewText(R.id.widgetSiteCountValue, "0")
                setTextViewText(R.id.widgetPaymentValue, "Kilitli")
                setTextViewText(R.id.widgetExpenseValue, "Masraf: Kilitli")
            }
            appWidgetManager.updateAppWidget(appWidgetId, fallback)
        }
    }

    private fun readIntSafely(widgetData: SharedPreferences, key: String): Int {
        return try {
            widgetData.all[key]?.toString()?.toIntOrNull() ?: 0
        } catch (_: Exception) {
            0
        }
    }
}
