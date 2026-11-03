package com.ruchan.steps

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.graphics.Typeface
import android.icu.text.SimpleDateFormat
import android.os.Build
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import java.util.Date
import kotlin.math.max
import kotlin.math.min

/** Today's steps as a big number. Taller sizes add a goal bar and a 7-day chart. */
class StepsWidgetSmall : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        StepWidgets.update(context, manager, ids, WidgetStyle.NUMBER)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        StepWidgets.update(context, manager, intArrayOf(id), WidgetStyle.NUMBER)
}

/** Ring towards the daily goal. Wider sizes add stats beside it, taller ones a 7-day chart. */
class StepsWidgetProgress : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        StepWidgets.update(context, manager, ids, WidgetStyle.RING)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        StepWidgets.update(context, manager, intArrayOf(id), WidgetStyle.RING)
}

enum class WidgetStyle { NUMBER, RING }

object StepWidgets {
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        update(context, manager, idsFor(context, manager, StepsWidgetSmall::class.java), WidgetStyle.NUMBER)
        update(context, manager, idsFor(context, manager, StepsWidgetProgress::class.java), WidgetStyle.RING)
    }

    private fun idsFor(context: Context, manager: AppWidgetManager, cls: Class<*>): IntArray =
        manager.getAppWidgetIds(ComponentName(context, cls))

    fun update(context: Context, manager: AppWidgetManager, ids: IntArray, style: WidgetStyle) {
        if (ids.isEmpty()) return
        val renderer = WidgetRenderer(context, style)
        for (id in ids) {
            val sizes = sizesOf(manager.getAppWidgetOptions(id))
            val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && sizes.size > 1) {
                // One layout per orientation; the launcher shows the matching one.
                RemoteViews(sizes.associateWith(renderer::render))
            } else {
                renderer.render(sizes.first())
            }
            manager.updateAppWidget(id, views)
        }
    }

    /** The widget's size in dp: portrait and landscape on Android 12+, portrait before. */
    private fun sizesOf(options: Bundle): List<SizeF> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val sizes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                options.getParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES, SizeF::class.java)
            } else {
                @Suppress("DEPRECATION")
                options.getParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            }
            if (!sizes.isNullOrEmpty()) return sizes
        }
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        // Not reported yet: assume one row.
        return listOf(if (width > 0 && height > 0) SizeF(width.toFloat(), height.toFloat()) else SizeF(180f, 70f))
    }
}

private val BAR_IDS = intArrayOf(
    R.id.widget_bar_0, R.id.widget_bar_1, R.id.widget_bar_2, R.id.widget_bar_3,
    R.id.widget_bar_4, R.id.widget_bar_5, R.id.widget_bar_6,
)
private val DAY_IDS = intArrayOf(
    R.id.widget_day_0, R.id.widget_day_1, R.id.widget_day_2, R.id.widget_day_3,
    R.id.widget_day_4, R.id.widget_day_5, R.id.widget_day_6,
)

/** What the widgets show. The last 7 days are only read when a widget is tall enough for the chart. */
private class WidgetData(val steps: Int, val goal: Int, val profile: Profile, loadWeek: () -> List<Pair<Date, Int>>) {
    val week by lazy(loadWeek)

    companion object {
        fun load(context: Context) = WidgetData(
            steps = StepStore.getToday(context),
            goal = StepStore.getGoal(context),
            profile = StepStore.getProfile(context),
        ) { StepStore.recentDays(context, 7) }
    }
}

/**
 * Builds the layout for a widget size (in dp) so the content fills it: the
 * layout is picked by shape, then text and the ring are sized to the space.
 * Text is in the app's language.
 */
private class WidgetRenderer(
    context: Context,
    private val style: WidgetStyle,
    data: WidgetData = WidgetData.load(context),
) {
    private val packageName = context.packageName
    private val res = AppLocale.wrap(context)
    private val fmt = Formatter(res)
    private val steps = data.steps
    private val goal = data.goal
    private val profile = data.profile
    private val week by lazy { data.week }
    private val openApp = PendingIntent.getActivity(
        context, 0,
        Intent(context, MainActivity::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private val progress = if (goal > 0) steps.toDouble() / goal else 0.0
    private val stepsText = fmt.count(steps)
    private val unitText = res.getString(R.string.widget_steps_unit)
    private val distanceText = fmt.distance(profile, steps)
    private val energyText = fmt.energy(profile, steps)
    private val textPaint = Paint().apply { typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL) }

    fun render(size: SizeF): RemoteViews {
        val w = size.width
        val h = size.height
        val views = when {
            h < 110 -> strip(w, h)
            style == WidgetStyle.NUMBER -> stack(w, h)
            w >= 250 -> ringWide(w, h)
            else -> ring(w, h)
        }
        views.setOnClickPendingIntent(R.id.widget_root, openApp)
        views.setContentDescription(
            R.id.widget_root,
            res.getString(R.string.widget_description, stepsText, fmt.percent(progress)),
        )
        return views
    }

    /** One row: ring (or badge), steps and a details line. Wide strips move the details into columns. */
    private fun strip(w: Float, h: Float) = RemoteViews(packageName, R.layout.widget_strip).apply {
        val inner = h - 16
        val ring = style == WidgetStyle.RING
        // Narrow strips keep room for the details line.
        val icon = min(if (ring) inner else inner * 0.8f, w * 0.22f).coerceIn(28f, if (ring) 52f else 44f)
        setImageViewResource(R.id.widget_ring, if (ring) R.drawable.widget_ring_icon else R.drawable.widget_icon_badge)
        setInt(R.id.widget_ring, "setImageLevel", ringLevel())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setViewLayoutWidth(R.id.widget_ring, icon, TypedValue.COMPLEX_UNIT_DIP)
            setViewLayoutHeight(R.id.widget_ring, icon, TypedValue.COMPLEX_UNIT_DIP)
        }

        var textWidth = w - 32 - icon - 12
        if (w >= 280) {
            setViewVisibility(R.id.widget_side_stats, View.VISIBLE)
            setStats(this)
            setStatLabels(this)
            setTextViewText(R.id.widget_details, goalProgress())
            textWidth -= 28 +
                max(18 + width(distanceText, 15f), width(res.getString(R.string.widget_distance), 11f)) +
                max(18 + width(energyText, 15f), width(res.getString(R.string.widget_calories), 11f))
        } else {
            setTextViewText(R.id.widget_details, "$distanceText · $energyText")
        }
        setTextViewText(R.id.widget_unit, unitText)
        setNumber(this, preferred = (inner * 0.5f).coerceIn(18f, 32f), width = textWidth - 4 - width(unitText, 12f))
    }

    /** Number style, two rows or taller: header, big number, goal bar, distance and calories. */
    private fun stack(w: Float, h: Float) = RemoteViews(packageName, R.layout.widget_stack).apply {
        setTextViewText(R.id.widget_title, res.getString(R.string.widget_today))
        setTextViewText(R.id.widget_percent, fmt.percent(progress))
        setProgressBar(R.id.widget_progress, 1000, (progress.coerceIn(0.0, 1.0) * 1000).toInt(), false)
        setStats(this)
        // Height left for the number after padding, header, bar and stats row.
        val free = h - 32 - 20 - 8 - 30 - chart(this, w, h)
        val unitSize = (free * 0.2f).coerceIn(13f, 18f)
        setTextViewText(R.id.widget_unit, unitText)
        setTextViewTextSize(R.id.widget_unit, TypedValue.COMPLEX_UNIT_DIP, unitSize)
        setNumber(this, preferred = (free * 0.6f).coerceIn(28f, 64f), width = w - 32 - 6 - width(unitText, unitSize))
    }

    /** Ring style, narrow: ring with the count inside, distance and calories below. */
    private fun ring(w: Float, h: Float) = RemoteViews(packageName, R.layout.widget_ring).apply {
        setInt(R.id.widget_ring, "setImageLevel", ringLevel())
        setStats(this)
        val chart = chart(this, w, h)
        ringText(this, diameter = min(w - 24, h - 24 - 26 - chart))
    }

    /** Ring style, wide: ring on the left; goal, distance and calories on the right. */
    private fun ringWide(w: Float, h: Float) = RemoteViews(packageName, R.layout.widget_ring_wide).apply {
        setInt(R.id.widget_ring, "setImageLevel", ringLevel())
        setTextViewText(R.id.widget_percent, fmt.percent(progress))
        setTextViewText(R.id.widget_goal, res.getString(R.string.widget_goal, fmt.count(goal)))
        setStats(this)
        setStatLabels(this)
        val main = h - 32 - chart(this, w, h)
        val diameter = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            min(main, (w - 52) / 2).also { setViewLayoutWidth(R.id.widget_ring_box, it, TypedValue.COMPLEX_UNIT_DIP) }
        } else {
            min(main, 100f) // the box wraps the ring drawable's own 100dp
        }
        ringText(this, diameter)
        val statSize = (main * 0.12f).coerceIn(14f, 20f)
        for (id in intArrayOf(R.id.widget_percent, R.id.widget_distance, R.id.widget_calories)) {
            setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_DIP, statSize)
        }
    }

    /** Count and unit inside a ring of [diameter] dp, clear of the stroke. */
    private fun ringText(views: RemoteViews, diameter: Float) {
        val unitSize = (diameter * 0.1f).coerceIn(10f, 16f)
        views.setTextViewText(R.id.widget_unit, unitText)
        views.setTextViewTextSize(R.id.widget_unit, TypedValue.COMPLEX_UNIT_DIP, unitSize)
        setNumber(views, preferred = diameter * 0.24f, width = diameter * 0.66f)
    }

    /** Shows the last 7 days if the widget is tall enough. Returns the height it takes, in dp. */
    private fun chart(views: RemoteViews, w: Float, h: Float): Float {
        if (h < 230) return 0f
        views.setViewVisibility(R.id.widget_chart, View.VISIBLE)
        val column = (w - 32) / 7
        var height = 88f // as in widget_chart.xml
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            height = ((h - 32) * 0.4f).coerceIn(72f, 150f)
            views.setViewLayoutHeight(R.id.widget_chart, height, TypedValue.COMPLEX_UNIT_DIP)
            val bar = (column * 0.4f).coerceIn(8f, 20f)
            for (id in BAR_IDS) views.setViewLayoutWidth(id, bar, TypedValue.COMPLEX_UNIT_DIP)
        }
        val days = week
        val top = max(goal, days.maxOf { it.second }).coerceAtLeast(1)
        // Single letters when "Mon" wouldn't fit.
        val dayFormat = SimpleDateFormat(if (column < 36) "EEEEE" else "EEE", fmt.locale)
        days.forEachIndexed { i, (date, count) ->
            views.setImageViewResource(BAR_IDS[i], if (count >= goal) R.drawable.widget_bar else R.drawable.widget_bar_muted)
            // Small counts still show as a sliver.
            val level = if (count <= 0) 0 else (count * 10_000L / top).toInt().coerceIn(400, 10_000)
            views.setInt(BAR_IDS[i], "setImageLevel", level)
            val label = dayFormat.format(date)
            views.setTextViewText(DAY_IDS[i], if (i == days.lastIndex) bold(label) else label)
        }
        return height + 12 // plus its top margin
    }

    /** Sets the step count as large as [preferred] dp while fitting [width] dp. */
    private fun setNumber(views: RemoteViews, preferred: Float, width: Float) {
        // Sized for at least four digits so it doesn't jump around as the count grows.
        val sample = if (steps < 1000) fmt.count(8888) else stepsText
        val size = min(preferred, width * 100 / width(sample, 100f)).coerceAtLeast(14f)
        views.setTextViewText(R.id.widget_steps, stepsText)
        views.setTextViewTextSize(R.id.widget_steps, TypedValue.COMPLEX_UNIT_DIP, size)
    }

    private fun setStats(views: RemoteViews) {
        views.setTextViewText(R.id.widget_distance, distanceText)
        views.setTextViewText(R.id.widget_calories, energyText)
    }

    private fun setStatLabels(views: RemoteViews) {
        views.setTextViewText(R.id.widget_distance_label, res.getString(R.string.widget_distance))
        views.setTextViewText(R.id.widget_calories_label, res.getString(R.string.widget_calories))
    }

    /** Approximate width in dp of [text] at [size] dp. */
    private fun width(text: String, size: Float): Float = textPaint.apply { textSize = size }.measureText(text)

    private fun ringLevel(): Int = (progress.coerceIn(0.0, 1.0) * 10_000).toInt()

    private fun goalProgress(): String =
        res.getString(R.string.widget_goal_progress, fmt.percent(progress), fmt.count(goal))

    private fun bold(text: String) = SpannableString(text).apply {
        setSpan(StyleSpan(Typeface.BOLD), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
}
