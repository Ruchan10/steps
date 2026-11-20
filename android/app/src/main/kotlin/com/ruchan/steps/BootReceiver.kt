package com.ruchan.steps

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restarts step tracking after a reboot or an app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // Just updated: the downloaded APK (if the update came from the app) is installed now.
                if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) AppUpdates.clear(context)
                StepCounterService.start(context)
                StepWidgets.updateAll(context)
            }
        }
    }
}
