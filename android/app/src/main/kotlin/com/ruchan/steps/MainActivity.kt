package com.ruchan.steps

import android.Manifest
import android.annotation.SuppressLint
import android.app.ActivityManager
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHODS = "steps/methods"
        private const val TODAY_EVENTS = "steps/today"
        private const val PERMISSION_REQUEST = 42
        private const val BATTERY_REQUEST = 43
        private const val PERMISSION_ACTIVITY = "activity"
        private const val PERMISSION_NOTIFICATIONS = "notifications"
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPermission = PERMISSION_ACTIVITY
    private var pendingBatteryResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var todayListener: ((Int) -> Unit)? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Opening the app is a good moment to make sure tracking is running
        // (e.g. after the system or the user stopped the service).
        StepCounterService.start(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(
                    mapOf(
                        "sensorAvailable" to StepCounterService.hasStepSensor(this),
                        "permissionGranted" to StepCounterService.hasActivityPermission(this),
                        "notificationsAllowed" to notificationsAllowed(),
                        "batteryUnrestricted" to isBatteryUnrestricted(),
                        "accentColor" to accentColor(),
                        "goal" to StepStore.getGoal(this),
                        "profile" to StepStore.getProfile(this).let {
                            mapOf(
                                "heightCm" to it.heightCm,
                                "weightKg" to it.weightKg,
                                "imperial" to it.imperial,
                                "distanceUnit" to it.distanceUnit.key,
                                "energyUnit" to it.energyUnit.key,
                            )
                        },
                        "profileSet" to StepStore.isProfileSet(this),
                        "onboarded" to StepStore.isOnboarded(this),
                        "language" to StepStore.getLanguage(this),
                    )
                )
                "requestPermission" -> requestPermission(call.argument<String>("permission") ?: PERMISSION_ACTIVITY, result)
                "requestBatteryUnrestricted" -> requestBatteryUnrestricted(result)
                "getAppInfo" -> result.success(appInfo())
                "getUpdateDir" -> result.success(AppUpdates.dir(this).absolutePath)
                "installUpdate" -> installUpdate(call.argument<String>("path"), call.argument<String>("sha256"), result)
                "getUpdatePrompt" -> result.success(
                    StepStore.getUpdatePrompt(this).let { (version, at) -> mapOf("version" to version, "at" to at) }
                )
                "setUpdatePrompt" -> {
                    val version = call.argument<String>("version")
                    if (version == null) {
                        result.error("bad_version", "Version is required", null)
                    } else {
                        StepStore.setUpdatePrompt(this, version, System.currentTimeMillis())
                        result.success(null)
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
                "openAppSettings" -> {
                    openAppDetails()
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                "setOnboarded" -> {
                    StepStore.setOnboarded(this)
                    result.success(null)
                }
                "setLanguage" -> {
                    val language = call.argument<String>("language")
                    if (language != null && language !in AppLocale.supported) {
                        result.error("bad_language", "Unsupported language: $language", null)
                    } else {
                        StepStore.setLanguage(this, language)
                        StepWidgets.updateAll(this)
                        StepCounterService.start(this) // re-renders the notification
                        result.success(null)
                    }
                }
                "startTracking" -> result.success(StepCounterService.start(this))
                "getToday" -> result.success(StepStore.getToday(this))
                "getHistory" -> result.success(StepStore.getHistory(this, call.argument<Int>("limit") ?: 365))
                "getGoal" -> result.success(StepStore.getGoal(this))
                "setProfile" -> {
                    val height = call.argument<Int>("heightCm")
                    val weight = call.argument<Int>("weightKg")
                    val imperial = call.argument<Boolean>("imperial")
                    val distanceUnit = DistanceUnit.fromKey(call.argument<String>("distanceUnit"))
                    val energyUnit = EnergyUnit.fromKey(call.argument<String>("energyUnit"))
                    if (height == null || weight == null || imperial == null || height <= 0 || weight <= 0 ||
                        distanceUnit == null || energyUnit == null
                    ) {
                        result.error("bad_profile", "Height and weight must be positive numbers, units km/mi and kcal/kj", null)
                    } else {
                        StepStore.setProfile(this, Profile(height, weight, imperial, distanceUnit, energyUnit))
                        StepWidgets.updateAll(this)
                        StepCounterService.start(this) // refreshes the notification
                        result.success(null)
                    }
                }
                "setGoal" -> {
                    val goal = call.argument<Int>("goal")
                    if (goal == null || goal <= 0) {
                        result.error("bad_goal", "Goal must be a positive number", null)
                    } else {
                        StepStore.setGoal(this, goal)
                        StepWidgets.updateAll(this)
                        StepCounterService.start(this) // refreshes the notification
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, TODAY_EVENTS).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val listener: (Int) -> Unit = { steps -> mainHandler.post { events.success(steps) } }
                todayListener = listener
                StepStore.addListener(listener)
                events.success(StepStore.getToday(this@MainActivity))
            }

            override fun onCancel(arguments: Any?) {
                todayListener?.let { StepStore.removeListener(it) }
                todayListener = null
            }
        })
    }

    override fun onDestroy() {
        todayListener?.let { StepStore.removeListener(it) }
        todayListener = null
        super.onDestroy()
    }

    // --- Permissions ---------------------------------------------------------

    /** The runtime permission behind [kind], or null when this Android version grants it at install. */
    private fun runtimePermission(kind: String): String? = when (kind) {
        PERMISSION_NOTIFICATIONS ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) Manifest.permission.POST_NOTIFICATIONS else null
        else ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) Manifest.permission.ACTIVITY_RECOGNITION else null
    }

    /** Replies "granted", "denied", or "blocked" (denied and the system won't ask again). */
    private fun requestPermission(kind: String, result: MethodChannel.Result) {
        val permission = runtimePermission(kind)
        if (permission == null || checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(permissionState(kind))
            return
        }
        pendingPermissionResult?.success(permissionState(pendingPermission))
        pendingPermission = kind
        pendingPermissionResult = result
        requestPermissions(arrayOf(permission), PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST) return
        val state = permissionState(pendingPermission)
        // Starts tracking, or re-posts the notification now that it may be shown.
        if (state == "granted") StepCounterService.start(this)
        pendingPermissionResult?.success(state)
        pendingPermissionResult = null
    }

    private fun permissionState(kind: String): String {
        val granted = if (kind == PERMISSION_NOTIFICATIONS) {
            notificationsAllowed()
        } else {
            StepCounterService.hasActivityPermission(this)
        }
        val permission = runtimePermission(kind)
        return when {
            granted -> "granted"
            // Notifications switched off in settings: no dialog can turn them back on.
            permission == null -> "blocked"
            // Right after a denial, no rationale means the system dialog is blocked for good.
            !shouldShowRequestPermissionRationale(permission) -> "blocked"
            else -> "denied"
        }
    }

    private fun notificationsAllowed(): Boolean =
        getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    // --- Battery -------------------------------------------------------------

    /** True when the app is exempt from battery optimisation ("Unrestricted") and not background-restricted. */
    private fun isBatteryUnrestricted(): Boolean {
        val power = getSystemService(PowerManager::class.java)
        val restricted = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            getSystemService(ActivityManager::class.java).isBackgroundRestricted
        return power.isIgnoringBatteryOptimizations(packageName) && !restricted
    }

    /**
     * Shows the system "Let app always run in background?" dialog, which sets the
     * app to Unrestricted in one tap. Falls back to the app's settings page.
     * Replies with the new state once the user comes back.
     */
    @SuppressLint("BatteryLife")
    private fun requestBatteryUnrestricted(result: MethodChannel.Result) {
        pendingBatteryResult?.success(isBatteryUnrestricted())
        pendingBatteryResult = result
        val power = getSystemService(PowerManager::class.java)
        val intent = if (!power.isIgnoringBatteryOptimizations(packageName)) {
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))
        } else {
            // Exempt but "Restricted" in app battery settings: only the user can change that.
            appDetailsIntent()
        }
        try {
            startActivityForResult(intent, BATTERY_REQUEST)
        } catch (_: ActivityNotFoundException) {
            try {
                startActivityForResult(appDetailsIntent(), BATTERY_REQUEST)
            } catch (_: ActivityNotFoundException) {
                pendingBatteryResult = null
                result.success(isBatteryUnrestricted())
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != BATTERY_REQUEST) return
        val unrestricted = isBatteryUnrestricted()
        if (unrestricted) StepCounterService.start(this)
        pendingBatteryResult?.success(unrestricted)
        pendingBatteryResult = null
    }

    // --- Updates -------------------------------------------------------------

    private fun appInfo(): Map<String, Any?> {
        val info = packageManager.getPackageInfo(packageName, 0)
        return mapOf(
            "version" to info.versionName,
            "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            },
            // Most preferred first, e.g. [arm64-v8a, armeabi-v7a, armeabi].
            "abis" to Build.SUPPORTED_ABIS.toList(),
            // "Install unknown apps" is already allowed, so Android won't ask before updating.
            "canInstallUpdates" to packageManager.canRequestPackageInstalls(),
        )
    }

    /**
     * Checks the downloaded update at [path] against the SHA-256 from update.json, then opens
     * the system installer. Replies "started", "badChecksum", "missing" or "noInstaller".
     */
    private fun installUpdate(path: String?, sha256: String?, result: MethodChannel.Result) {
        if (path == null || sha256 == null) {
            result.success("missing")
            return
        }
        val apk = File(path)
        Thread {
            val problem = try {
                when {
                    !apk.isFile -> "missing"
                    !AppUpdates.sha256(apk).equals(sha256, ignoreCase = true) -> "badChecksum"
                    else -> null
                }
            } catch (_: IOException) {
                "missing"
            }
            mainHandler.post {
                val reply = problem ?: try {
                    if (AppUpdates.install(this, apk)) "started" else "noInstaller"
                } catch (_: IllegalArgumentException) {
                    "missing" // Not in the updates folder, so the FileProvider can't share it.
                }
                result.success(reply)
            }
        }.start()
    }

    // --- Misc ----------------------------------------------------------------

    private fun appDetailsIntent() =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))

    private fun openAppDetails() {
        try {
            startActivity(appDetailsIntent())
        } catch (_: ActivityNotFoundException) {
        }
    }

    private fun openNotificationSettings() {
        try {
            startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            )
        } catch (_: ActivityNotFoundException) {
            openAppDetails()
        }
    }

    /** Wallpaper-based accent colour (Android 12+) so the app matches the widgets. */
    private fun accentColor(): Long? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getColor(android.R.color.system_accent1_500).toLong() and 0xFFFFFFFFL
        } else {
            null
        }
}
