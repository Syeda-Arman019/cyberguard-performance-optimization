package com.example.cyberguard_mobile.performance.usage

import android.app.AppOpsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log

/**
 * The ONLY place in the module that knows about Usage Access.
 *
 * Usage Access ("apps with usage access") is a special app-op, not a runtime permission:
 * it cannot be requested with a dialog, only by sending the user to a system settings page.
 * When it is missing, every feature that needs it degrades gracefully instead of crashing.
 */
object UsageAccessHelper {

    private const val TAG = "PerfUsageAccess"

    private const val OPSTR_GET_USAGE_STATS = AppOpsManager.OPSTR_GET_USAGE_STATS

    /**
     * True when this app currently holds Usage Access.
     *
     * API 29+ uses [AppOpsManager.unsafeCheckOpNoThrow] (checkOpNoThrow is deprecated and
     * throws on some OEM builds when called from the background); older versions use
     * [AppOpsManager.checkOpNoThrow]. MODE_DEFAULT is treated as granted only if the
     * platform also reports the manifest permission as granted (some OEMs do this).
     *
     * Never throws: any failure is reported as "not granted".
     */
    fun isGranted(context: Context): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
                ?: return false
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
            }

            when (mode) {
                AppOpsManager.MODE_ALLOWED -> true
                AppOpsManager.MODE_DEFAULT -> context.checkSelfPermission(
                    android.Manifest.permission.PACKAGE_USAGE_STATS,
                ) == PackageManager.PERMISSION_GRANTED
                else -> false
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Usage Access check failed; treating as not granted", t)
            false
        }
    }

    /**
     * Opens the system "Apps with usage access" list so the user can grant access.
     *
     * Tries the per-app page first (the app-specific variant is not guaranteed on every OEM),
     * then the generic list. Returns false when no settings activity could be opened.
     */
    fun openSettings(context: Context): Boolean {
        // 1) App-specific page. Not supported by all OEMs; harmless when it fails.
        if (tryStart(context, Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, appUri(context)))) {
            return true
        }
        // 2) Generic "Usage access" list.
        return tryStart(context, Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    private fun appUri(context: Context): Uri = Uri.fromParts("package", context.packageName, null)

    private fun tryStart(context: Context, intent: Intent): Boolean {
        return try {
            // Started from a non-Activity context (the plugin channel), so NEW_TASK is required.
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            Log.i(TAG, "No activity for $intent", e)
            false
        } catch (t: Throwable) {
            Log.w(TAG, "Could not open Usage Access settings", t)
            false
        }
    }
}
