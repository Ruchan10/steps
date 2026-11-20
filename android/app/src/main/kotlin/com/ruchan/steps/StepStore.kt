package com.ruchan.steps

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.provider.Settings
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.CopyOnWriteArraySet
import kotlin.math.roundToLong

/**
 * Persists daily step totals and the bookkeeping needed to turn the cumulative
 * TYPE_STEP_COUNTER value (steps since boot) into per-day deltas.
 */
object StepStore {
    const val DEFAULT_GOAL = 10_000

    private const val KEY_LAST_SENSOR = "last_sensor"
    private const val KEY_LAST_BOOT = "last_boot"
    private const val KEY_GOAL = "goal"
    private const val KEY_HEIGHT = "height_cm"
    private const val KEY_WEIGHT = "weight_kg"
    private const val KEY_IMPERIAL = "imperial"
    private const val KEY_DISTANCE_UNIT = "distance_unit"
    private const val KEY_ENERGY_UNIT = "energy_unit"
    private const val KEY_LANGUAGE = "language"
    private const val KEY_ONBOARDED = "onboarded"
    private const val KEY_UPDATE_PROMPT_VERSION = "update_prompt_version"
    private const val KEY_UPDATE_PROMPT_AT = "update_prompt_at"

    private val listeners = CopyOnWriteArraySet<(Int) -> Unit>()

    @Volatile
    private var helper: DbHelper? = null

    private fun db(context: Context): SQLiteDatabase {
        val h = helper ?: synchronized(this) {
            helper ?: DbHelper(context.applicationContext).also { helper = it }
        }
        return h.writableDatabase
    }

    fun dateKey(date: Date = Date()): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(date)

    fun addListener(listener: (Int) -> Unit) = listeners.add(listener)

    fun removeListener(listener: (Int) -> Unit) = listeners.remove(listener)

    fun notifyChanged(context: Context) {
        val today = getToday(context)
        listeners.forEach { it(today) }
    }

    fun getToday(context: Context): Int = getSteps(context, dateKey())

    fun getSteps(context: Context, date: String): Int =
        db(context).rawQuery("SELECT steps FROM steps WHERE date = ?", arrayOf(date)).use {
            if (it.moveToFirst()) it.getInt(0) else 0
        }

    /** Most recent [limit] recorded days, newest first. */
    fun getHistory(context: Context, limit: Int): List<Map<String, Any>> =
        db(context).rawQuery(
            "SELECT date, steps FROM steps ORDER BY date DESC LIMIT ?",
            arrayOf(limit.toString()),
        ).use { c ->
            buildList {
                while (c.moveToNext()) add(mapOf("date" to c.getString(0), "steps" to c.getInt(1)))
            }
        }

    fun getGoal(context: Context): Int = getMeta(db(context), KEY_GOAL)?.toIntOrNull() ?: DEFAULT_GOAL

    fun setGoal(context: Context, goal: Int) = setMeta(db(context), KEY_GOAL, goal.toString())

    /** Last [days] calendar days, oldest first, with 0 for days without records. */
    fun recentDays(context: Context, days: Int): List<Pair<Date, Int>> {
        val stored = getHistory(context, days).associate { it["date"] as String to it["steps"] as Int }
        return (days - 1 downTo 0).map { ago ->
            val day = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -ago) }.time
            day to (stored[dateKey(day)] ?: 0)
        }
    }

    fun getProfile(context: Context): Profile {
        val db = db(context)
        val imperial = getMeta(db, KEY_IMPERIAL)?.toBooleanStrictOrNull() ?: Profile.defaultImperial()
        return Profile(
            heightCm = getMeta(db, KEY_HEIGHT)?.toIntOrNull() ?: Profile.DEFAULT_HEIGHT_CM,
            weightKg = getMeta(db, KEY_WEIGHT)?.toIntOrNull() ?: Profile.DEFAULT_WEIGHT_KG,
            imperial = imperial,
            // Profiles saved before units were separate used miles with imperial.
            distanceUnit = DistanceUnit.fromKey(getMeta(db, KEY_DISTANCE_UNIT))
                ?: if (imperial) DistanceUnit.MI else DistanceUnit.KM,
            energyUnit = EnergyUnit.fromKey(getMeta(db, KEY_ENERGY_UNIT)) ?: EnergyUnit.KCAL,
        )
    }

    /** False until the user has entered their height and weight. */
    fun isProfileSet(context: Context): Boolean = getMeta(db(context), KEY_HEIGHT) != null

    fun setProfile(context: Context, profile: Profile) {
        val db = db(context)
        db.beginTransaction()
        try {
            setMeta(db, KEY_HEIGHT, profile.heightCm.toString())
            setMeta(db, KEY_WEIGHT, profile.weightKg.toString())
            setMeta(db, KEY_IMPERIAL, profile.imperial.toString())
            setMeta(db, KEY_DISTANCE_UNIT, profile.distanceUnit.key)
            setMeta(db, KEY_ENERGY_UNIT, profile.energyUnit.key)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    /** "en" or "ne", or null to follow the phone's language. */
    fun getLanguage(context: Context): String? = getMeta(db(context), KEY_LANGUAGE)

    fun setLanguage(context: Context, language: String?) {
        val db = db(context)
        if (language == null) db.delete("meta", "key = ?", arrayOf(KEY_LANGUAGE)) else setMeta(db, KEY_LANGUAGE, language)
    }

    fun isOnboarded(context: Context): Boolean = getMeta(db(context), KEY_ONBOARDED) == "true"

    fun setOnboarded(context: Context) = setMeta(db(context), KEY_ONBOARDED, "true")

    /** The app update the user was last offered, and when (milliseconds since the epoch). */
    fun getUpdatePrompt(context: Context): Pair<String?, Long?> {
        val db = db(context)
        return getMeta(db, KEY_UPDATE_PROMPT_VERSION) to getMeta(db, KEY_UPDATE_PROMPT_AT)?.toLongOrNull()
    }

    fun setUpdatePrompt(context: Context, version: String, at: Long) {
        val db = db(context)
        db.beginTransaction()
        try {
            setMeta(db, KEY_UPDATE_PROMPT_VERSION, version)
            setMeta(db, KEY_UPDATE_PROMPT_AT, at.toString())
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    /**
     * Records a new cumulative sensor reading and returns today's total.
     * The reading and the day total are written in one transaction so a killed
     * process never double-counts or drops steps.
     */
    @Synchronized
    fun recordSensorValue(context: Context, value: Float): Int {
        val db = db(context)
        val bootCount = currentBootCount(context)
        val today = dateKey()
        db.beginTransaction()
        try {
            val last = getMeta(db, KEY_LAST_SENSOR)?.toFloatOrNull()
            val lastBoot = getMeta(db, KEY_LAST_BOOT)?.toIntOrNull()
            val rebooted = bootCount != null && lastBoot != null && bootCount != lastBoot
            val delta = when {
                // First reading ever: the counter includes steps from before install.
                last == null -> 0L
                // Counter restarts from 0 after a reboot.
                rebooted || value < last -> value.roundToLong()
                else -> (value - last).roundToLong()
            }.coerceIn(0L, 100_000L).toInt()

            if (delta > 0) {
                val updated = db.compileStatement(
                    "UPDATE steps SET steps = steps + ? WHERE date = ?"
                ).apply {
                    bindLong(1, delta.toLong())
                    bindString(2, today)
                }.executeUpdateDelete()
                if (updated == 0) {
                    db.insert("steps", null, ContentValues().apply {
                        put("date", today)
                        put("steps", delta)
                    })
                }
            }
            setMeta(db, KEY_LAST_SENSOR, value.toString())
            if (bootCount != null) setMeta(db, KEY_LAST_BOOT, bootCount.toString())
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        val total = getSteps(context, today)
        listeners.forEach { it(total) }
        return total
    }

    private fun currentBootCount(context: Context): Int? =
        try {
            Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT)
        } catch (_: Settings.SettingNotFoundException) {
            null
        }

    private fun getMeta(db: SQLiteDatabase, key: String): String? =
        db.rawQuery("SELECT value FROM meta WHERE key = ?", arrayOf(key)).use {
            if (it.moveToFirst()) it.getString(0) else null
        }

    private fun setMeta(db: SQLiteDatabase, key: String, value: String) {
        db.insertWithOnConflict(
            "meta", null,
            ContentValues().apply {
                put("key", key)
                put("value", value)
            },
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    private class DbHelper(context: Context) : SQLiteOpenHelper(context, "steps.db", null, 1) {
        override fun onConfigure(db: SQLiteDatabase) {
            db.enableWriteAheadLogging()
        }

        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE steps (date TEXT PRIMARY KEY, steps INTEGER NOT NULL)")
            db.execSQL("CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
    }
}
