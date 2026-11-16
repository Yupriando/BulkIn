package com.naikin.naikin

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Widget layar utama BulkIn. Ada 4 ukuran, semuanya membaca data yang sama
 * (disimpan aplikasi Flutter lewat lib/home_widget_service.dart):
 *
 *  - [BulkInWidgetProvider]       3×3  lengkap: kalori, sisa, protein, berat, tombol
 *  - [BulkInWidgetSmallProvider]  2×2  kalori, persen, bar, tombol
 *  - [BulkInWidgetWideProvider]   4×1  satu baris: kalori, bar, tombol
 *  - [BulkInWidgetMiniProvider]   2×1  kalori & bar saja (ketuk untuk buka aplikasi)
 *
 * Semua layout memakai id yang sama (widget_root, widget_content, widget_signed_out, widget_kcal,
 * widget_kcal_target, widget_percent, widget_progress); sisanya diatur oleh flag di bawah.
 */
abstract class BulkInBaseWidget : HomeWidgetProvider() {
    protected abstract val layoutId: Int

    /** Layout punya baris sisa / protein / berat. */
    protected open val hasDetails = false

    /** Layout punya tombol "+ Catat makan". */
    protected open val hasAddButton = true

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, widgetData))
        }
    }

    private fun buildViews(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, layoutId)

        // Ketuk widget → buka aplikasi; tombol → buka aplikasi langsung ke form catat makan.
        views.setOnClickPendingIntent(R.id.widget_root, launch(context, "bulkin://open"))
        if (hasAddButton) views.setOnClickPendingIntent(R.id.widget_add, launch(context, "bulkin://add"))

        if (!data.getBoolean("logged_in", false)) {
            views.setViewVisibility(R.id.widget_content, View.GONE)
            views.setViewVisibility(R.id.widget_signed_out, View.VISIBLE)
            return views
        }
        views.setViewVisibility(R.id.widget_content, View.VISIBLE)
        views.setViewVisibility(R.id.widget_signed_out, View.GONE)

        views.setTextViewText(R.id.widget_kcal_target, " / ${data.getString("kcal_target", "0")} kkal")

        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val isToday = data.getString("date", null) == today
        // Data dari hari sebelumnya: jangan tampilkan angka kemarin sebagai hari ini.
        val percent = if (isToday) data.getInt("percent", 0) else 0
        views.setTextViewText(R.id.widget_kcal, if (isToday) data.getString("kcal", "0") else "0")
        views.setTextViewText(R.id.widget_percent, "$percent%")
        views.setProgressBar(R.id.widget_progress, 100, percent.coerceIn(0, 100), false)

        if (hasDetails) {
            if (isToday) {
                views.setTextViewText(R.id.widget_remaining, data.getString("remaining", ""))
                views.setTextViewText(R.id.widget_protein, "Protein ${data.getString("protein", "")}")
                val weight = data.getString("weight", "").orEmpty()
                views.setTextViewText(R.id.widget_weight, weight)
                views.setViewVisibility(R.id.widget_weight, if (weight.isEmpty()) View.GONE else View.VISIBLE)
            } else {
                views.setTextViewText(R.id.widget_remaining, "Belum ada catatan hari ini")
                views.setTextViewText(R.id.widget_protein, "Protein 0 / ${data.getString("protein_target", "0 g")}")
                views.setViewVisibility(R.id.widget_weight, View.GONE)
            }
        }
        return views
    }

    private fun launch(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
}

/** 3×3 — lengkap. */
class BulkInWidgetProvider : BulkInBaseWidget() {
    override val layoutId = R.layout.bulkin_widget
    override val hasDetails = true
}

/** 2×2 — kalori, persen, bar, tombol. */
class BulkInWidgetSmallProvider : BulkInBaseWidget() {
    override val layoutId = R.layout.bulkin_widget_small
}

/** 4×1 — satu baris memanjang. */
class BulkInWidgetWideProvider : BulkInBaseWidget() {
    override val layoutId = R.layout.bulkin_widget_wide
}

/** 2×1 — paling ringkas, tanpa tombol. */
class BulkInWidgetMiniProvider : BulkInBaseWidget() {
    override val layoutId = R.layout.bulkin_widget_mini
    override val hasAddButton = false
}
