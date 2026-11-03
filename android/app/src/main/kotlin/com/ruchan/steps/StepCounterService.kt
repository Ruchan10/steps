package com.ruchan.steps

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log

/**
 * Foreground service that keeps listening to the hardware step counter so steps
 * are recorded while the app is closed. Also keeps the notification and home
 * screen widgets up to date.
 */
class StepCounterService : Service(), SensorEventListener {

    companion object {
        private const val TAG = "StepCounterService"
        private const val CHANNEL_ID = "step_tracking"
        private const val NOTIFICATION_ID = 1
        private const val UI_REFRESH_MS = 3_000L

        fun hasActivityPermission(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
                PackageManager.PERMISSION_GRANTED

        fun hasStepSensor(context: Context): Boolean =
            (context.getSystemService(SENSOR_SERVICE) as SensorManager)
                .getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null

        /** Starts tracking if possible. Returns false when permission or sensor is missing. */
        fun start(context: Context): Boolean {
            if (!hasActivityPermission(context) || !hasStepSensor(context)) return false
            return try {
                context.startForegroundService(Intent(context, StepCounterService::class.java))
                true
            } catch (e: Exception) {
                Log.w(TAG, "Could not start step service", e)
                false
            }
        }
    }

    private lateinit var sensorManager: SensorManager
    private val handler = Handler(Looper.getMainLooper())
    private var lastUiRefresh = 0L
    private var refreshPending = false
    private var running = false

    private val refreshRunnable = Runnable {
        refreshPending = false
        refreshUi()
    }

    // Day rollover / clock changes: today's count resets to 0 without any new sensor event.
    // Locale changes: the notification and widgets may follow the phone's language.
    private val dateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            StepStore.notifyChanged(context)
            refreshUi()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        try {
            val notification = buildNotification(StepStore.getToday(this))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.w(TAG, "startForeground failed", e)
            stopSelf()
            return
        }

        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null) {
            stopSelf()
            return
        }
        sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
        running = true

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_DATE_CHANGED)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
            addAction(Intent.ACTION_LOCALE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(dateReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(dateReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Repeated start requests (e.g. after the goal or language changes) just refresh the UI.
        if (running) {
            createChannel()
            refreshUi()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        if (running) {
            sensorManager.unregisterListener(this)
            try {
                unregisterReceiver(dateReceiver)
            } catch (_: IllegalArgumentException) {
            }
        }
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER) return
        StepStore.recordSensorValue(this, event.values[0])
        scheduleUiRefresh()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    /** Throttles notification + widget updates; walking produces ~2 events per second. */
    private fun scheduleUiRefresh() {
        if (refreshPending) return
        val wait = UI_REFRESH_MS - (SystemClock.elapsedRealtime() - lastUiRefresh)
        if (wait <= 0) {
            refreshUi()
        } else {
            refreshPending = true
            handler.postDelayed(refreshRunnable, wait)
        }
    }

    private fun refreshUi() {
        lastUiRefresh = SystemClock.elapsedRealtime()
        val today = StepStore.getToday(this)
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(today))
        StepWidgets.updateAll(this)
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            AppLocale.wrap(this).getString(R.string.notification_channel),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(steps: Int): Notification {
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val goal = StepStore.getGoal(this)
        val profile = StepStore.getProfile(this)
        val localized = AppLocale.wrap(this)
        val fmt = Formatter(localized)
        val builder = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_steps)
            .setContentTitle(localized.getString(R.string.notification_title, fmt.count(steps)))
            .setContentText(
                localized.getString(
                    R.string.notification_text,
                    fmt.distance(profile, steps),
                    fmt.energy(profile, steps),
                    fmt.count(goal),
                )
            )
            .setProgress(goal, steps.coerceAtMost(goal), false)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }
}
