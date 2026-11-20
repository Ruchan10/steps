package com.ruchan.steps

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File
import java.security.MessageDigest

/**
 * App updates downloaded by lib/update_checker.dart: where they're kept, checking them,
 * and handing them to the system installer.
 */
object AppUpdates {
    /** Under the cache dir, shared through the FileProvider (res/xml/update_paths.xml). */
    private const val DIR = "updates"
    private const val APK_TYPE = "application/vnd.android.package-archive"

    fun dir(context: Context): File = File(context.cacheDir, DIR).apply { mkdirs() }

    /** Deletes downloaded updates, e.g. once one is installed. */
    fun clear(context: Context) {
        File(context.cacheDir, DIR).deleteRecursively()
    }

    /** Lowercase hex SHA-256 of [file], as listed in the release's update.json. */
    fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    /**
     * Opens the system installer for [apk], which must be in [dir]. Returns false if
     * there's no installer. Android asks for "Install unknown apps" first if needed.
     */
    fun install(activity: Activity, apk: File): Boolean {
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", apk)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, APK_TYPE)
            // In its own task: installing closes this app's tasks, and the installer should
            // stay open to show the result ("App installed", with Open).
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            activity.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }
}
