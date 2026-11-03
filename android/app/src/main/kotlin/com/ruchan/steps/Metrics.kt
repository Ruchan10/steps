package com.ruchan.steps

import android.content.Context
import android.content.res.Configuration
import android.icu.text.NumberFormat
import java.util.Locale
import kotlin.math.floor

enum class DistanceUnit(val key: String) {
    KM("km"), MI("mi");

    companion object {
        fun fromKey(key: String?): DistanceUnit? = entries.firstOrNull { it.key == key }
    }
}

enum class EnergyUnit(val key: String) {
    KCAL("kcal"), KJ("kj");

    companion object {
        fun fromKey(key: String?): EnergyUnit? = entries.firstOrNull { it.key == key }
    }
}

/**
 * Body details used to estimate distance and calories from steps.
 * Keep the formulas in sync with lib/metrics.dart.
 */
data class Profile(
    val heightCm: Int,
    val weightKg: Int,
    /** Height and weight are entered in feet/inches and pounds. */
    val imperial: Boolean,
    val distanceUnit: DistanceUnit,
    val energyUnit: EnergyUnit,
) {
    companion object {
        const val DEFAULT_HEIGHT_CM = 170
        const val DEFAULT_WEIGHT_KG = 70

        /** Countries that use miles and pounds day to day. */
        fun defaultImperial(): Boolean = Locale.getDefault().country in setOf("US", "LR", "MM")
    }

    /** Average walking stride is ~41.5% of body height. */
    private val strideMeters: Double get() = heightCm * 0.415 / 100.0

    fun distanceKm(steps: Int): Double = steps * strideMeters / 1000.0

    /** ~0.57 kcal per pound of body weight per mile walked (≈0.78 kcal/kg/km). */
    private fun kcal(steps: Int): Double = distanceKm(steps) * weightKg * 0.78

    /** Distance in [distanceUnit]. */
    fun distance(steps: Int): Double =
        if (distanceUnit == DistanceUnit.MI) distanceKm(steps) * 0.621371 else distanceKm(steps)

    /** Energy burned in [energyUnit]. */
    fun energy(steps: Int): Int =
        floor(if (energyUnit == EnergyUnit.KJ) kcal(steps) * 4.184 else kcal(steps)).toInt()
}

/** The language the user picked in the app, falling back to the phone's language. */
object AppLocale {
    val supported = setOf("en", "ne")

    fun of(context: Context): Locale {
        val chosen = StepStore.getLanguage(context)
        val system = context.resources.configuration.locales[0].language
        return Locale.forLanguageTag(chosen ?: system.takeIf { it in supported } ?: "en")
    }

    /** [context] with its resources (strings, number formats) in the app's language. */
    fun wrap(context: Context): Context {
        val config = Configuration(context.resources.configuration).apply { setLocale(of(context)) }
        return context.createConfigurationContext(config)
    }
}

/**
 * Formats numbers and units like the app does (lib/format.dart): Nepali uses
 * Devanagari digits and lakh grouping, e.g. १,२३,४५६.
 * [context] must come from [AppLocale.wrap].
 */
class Formatter(private val context: Context) {
    val locale: Locale = context.resources.configuration.locales[0]
    private val integer = NumberFormat.getIntegerInstance(locale)

    fun count(n: Int): String = integer.format(n.toLong())

    fun percent(fraction: Double): String = NumberFormat.getPercentInstance(locale).format(fraction)

    fun distance(profile: Profile, steps: Int): String {
        val value = profile.distance(steps)
        val digits = if (value < 100) 1 else 0
        val number = NumberFormat.getNumberInstance(locale).apply {
            minimumFractionDigits = digits
            maximumFractionDigits = digits
        }.format(value)
        val unit = if (profile.distanceUnit == DistanceUnit.MI) R.string.distance_mi else R.string.distance_km
        return context.getString(unit, number)
    }

    fun energy(profile: Profile, steps: Int): String {
        val unit = if (profile.energyUnit == EnergyUnit.KJ) R.string.energy_kj else R.string.energy_kcal
        return context.getString(unit, count(profile.energy(steps)))
    }
}
