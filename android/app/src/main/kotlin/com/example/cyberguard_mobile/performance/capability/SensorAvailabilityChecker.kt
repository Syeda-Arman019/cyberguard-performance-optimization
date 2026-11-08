package com.example.cyberguard_mobile.performance.capability

import android.app.ActivityManager
import android.app.usage.NetworkStatsManager
import android.app.usage.StorageStatsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.os.StatFs
import android.os.storage.StorageManager
import android.util.Log
import com.example.cyberguard_mobile.performance.data.PerfCapabilityEntity
import com.example.cyberguard_mobile.performance.data.PerfCapabilityState
import com.example.cyberguard_mobile.performance.data.PerfDatabase
import com.example.cyberguard_mobile.performance.data.PerfMetric
import com.example.cyberguard_mobile.performance.usage.UsageAccessHelper
import java.io.IOException

/**
 * Startup capability probe.
 *
 * Runs once per app start (off the main thread) and writes one row per metric to
 * perf_capabilities. Its purpose is to tell the rest of the module - and the user - which
 * numbers can honestly be shown on THIS device, instead of showing a fabricated 0.
 *
 * Rules:
 *  - Every probe is wrapped in try/catch and always yields a state plus a human-readable reason.
 *  - Version-gated APIs report UNAVAILABLE (with the required Android version) below their API level.
 *  - Permission-gated APIs report PERMISSION_NEEDED when Usage Access is missing.
 *  - "UNRELIABLE" is used when the API answers but the answer cannot be trusted on this device.
 */
object SensorAvailabilityChecker {

    private const val TAG = "PerfCapabilities"

    /** Result of a single probe. */
    private data class Probe(val state: PerfCapabilityState, val reason: String?)

    /** Serialises probes: the current probe sleeps briefly, so it must not run concurrently. */
    @Synchronized
    fun runAll(context: Context, now: Long = System.currentTimeMillis()): List<PerfCapabilityEntity> {
        val appContext = context.applicationContext
        val usageGranted = UsageAccessHelper.isGranted(appContext)

        val probes = LinkedHashMap<String, Probe>()

        probes[PerfMetric.BATTERY_LEVEL] = probeBatteryLevel(appContext)
        probes[PerfMetric.BATTERY_TEMPERATURE] = probeBatteryTemperature(appContext)
        probes[PerfMetric.BATTERY_CURRENT] = probeBatteryCurrent(appContext)
        probes[PerfMetric.THERMAL_STATUS] = probeThermalStatus(appContext)
        probes[PerfMetric.MEMORY_INFO] = probeMemoryInfo(appContext)
        probes[PerfMetric.STORAGE_STATS] = probeStorageStats(appContext)
        probes[PerfMetric.SCREEN_STATE] = probeScreenState(appContext)
        probes[PerfMetric.PER_APP_STORAGE] = probePerAppStorage(appContext, usageGranted)
        probes[PerfMetric.PER_APP_NETWORK] = probePerAppNetwork(appContext, usageGranted)
        probes[PerfMetric.USAGE_EVENTS] = probeUsageEvents(appContext, usageGranted)
        probes[PerfMetric.USAGE_ACCESS] = if (usageGranted) {
            Probe(PerfCapabilityState.AVAILABLE, null)
        } else {
            Probe(
                PerfCapabilityState.PERMISSION_NEEDED,
                "Usage Access is not granted. Apps that used the phone recently cannot be listed.",
            )
        }

        val entities = probes.map { (metric, probe) ->
            PerfCapabilityEntity(
                metricName = metric,
                state = probe.state.name,
                reason = probe.reason,
                checkedAt = now,
            )
        }

        try {
            PerfDatabase.get(appContext).perfDao().upsertCapabilities(entities)
        } catch (t: Throwable) {
            // A failed write must not break app start; the debug screen will show stale data.
            Log.w(TAG, "Could not save capability results", t)
        }
        return entities
    }

    // -------------------------------------------------------------------------------------------
    // Battery (sticky ACTION_BATTERY_CHANGED broadcast - no receiver is registered in the manifest)
    // -------------------------------------------------------------------------------------------

    private fun batteryIntent(context: Context): Intent? = try {
        context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    } catch (t: Throwable) {
        Log.w(TAG, "Sticky battery broadcast unavailable", t)
        null
    }

    private fun probeBatteryLevel(context: Context): Probe {
        val intent = batteryIntent(context)
            ?: return Probe(
                PerfCapabilityState.UNAVAILABLE,
                "This device did not return the battery status broadcast.",
            )
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        return if (scale > 0 && level in 0..scale) {
            Probe(PerfCapabilityState.AVAILABLE, null)
        } else {
            Probe(
                PerfCapabilityState.UNAVAILABLE,
                "The battery percentage was not reported by the system.",
            )
        }
    }

    private fun probeBatteryTemperature(context: Context): Probe {
        val intent = batteryIntent(context)
            ?: return Probe(
                PerfCapabilityState.UNAVAILABLE,
                "This device did not return the battery status broadcast.",
            )
        val raw = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
        return when {
            raw == Int.MIN_VALUE -> Probe(
                PerfCapabilityState.UNAVAILABLE,
                "This device does not report battery temperature.",
            )
            raw <= 0 || raw > 1000 -> Probe(
                PerfCapabilityState.UNRELIABLE,
                "The reported battery temperature ($raw tenths of a degree) is not physically plausible.",
            )
            else -> Probe(PerfCapabilityState.AVAILABLE, null)
        }
    }

    /**
     * Some devices always return 0 for BATTERY_PROPERTY_CURRENT_NOW, and some OEMs report
     * milliamperes although the API documents microamperes. We read a few times; if we never
     * see a plausible non-zero value the metric is UNRELIABLE (never silently 0).
     */
    private fun probeBatteryCurrent(context: Context): Probe {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            ?: return Probe(PerfCapabilityState.UNAVAILABLE, "Battery service is not available.")

        val readings = ArrayList<Int>(3)
        repeat(3) { attempt ->
            try {
                readings += batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
            } catch (t: Throwable) {
                Log.w(TAG, "Current probe read $attempt failed", t)
            }
            if (attempt < 2) {
                try {
                    Thread.sleep(200L)
                } catch (ignored: InterruptedException) {
                    Thread.currentThread().interrupt()
                }
            }
        }

        val plausible = readings.filter { it != 0 && it != Int.MIN_VALUE }
        if (plausible.isEmpty()) {
            return Probe(
                PerfCapabilityState.UNRELIABLE,
                "This device reports 0 for battery current, so current cannot be measured. " +
                    "Other metrics are unaffected.",
            )
        }
        // 20 A in microamperes is already absurd for a phone; anything larger is a unit error.
        if (plausible.any { kotlin.math.abs(it.toLong()) > 20_000_000L }) {
            return Probe(
                PerfCapabilityState.UNRELIABLE,
                "The battery current reading is too large to be microamperes, so it is not used.",
            )
        }
        return Probe(PerfCapabilityState.AVAILABLE, null)
    }

    // -------------------------------------------------------------------------------------------
    // Thermal status (Android 10 / API 29+)
    // -------------------------------------------------------------------------------------------

    private fun probeThermalStatus(context: Context): Probe {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return Probe(
                PerfCapabilityState.UNAVAILABLE,
                "Thermal status needs Android 10 (API 29) or newer. This phone runs Android " +
                    "${Build.VERSION.SDK_INT}. Battery temperature is still shown when available.",
            )
        }
        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                ?: return Probe(PerfCapabilityState.UNAVAILABLE, "Power service is not available.")
            val status = powerManager.currentThermalStatus
            if (status in PowerManager.THERMAL_STATUS_NONE..PowerManager.THERMAL_STATUS_SHUTDOWN) {
                Probe(PerfCapabilityState.AVAILABLE, null)
            } else {
                Probe(
                    PerfCapabilityState.UNRELIABLE,
                    "The system returned an unknown thermal status value ($status).",
                )
            }
        } catch (t: Throwable) {
            Probe(
                PerfCapabilityState.UNAVAILABLE,
                "This device does not expose thermal status (some manufacturers block it).",
            )
        }
    }

    // -------------------------------------------------------------------------------------------
    // Memory
    // -------------------------------------------------------------------------------------------

    private fun probeMemoryInfo(context: Context): Probe {
        return try {
            val activityManager =
                context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    ?: return Probe(
                        PerfCapabilityState.UNAVAILABLE,
                        "Activity service is not available.",
                    )
            val info = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(info)
            if (info.totalMem > 0L) {
                Probe(PerfCapabilityState.AVAILABLE, null)
            } else {
                Probe(PerfCapabilityState.UNAVAILABLE, "The system did not report total memory.")
            }
        } catch (t: Throwable) {
            Probe(PerfCapabilityState.UNAVAILABLE, "Memory information could not be read.")
        }
    }

    // -------------------------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------------------------

    private fun probeStorageStats(context: Context): Probe {
        return try {
            val stat = StatFs(context.filesDir.absolutePath)
            if (stat.totalBytes > 0L && stat.availableBytes >= 0L) {
                Probe(PerfCapabilityState.AVAILABLE, null)
            } else {
                Probe(
                    PerfCapabilityState.UNAVAILABLE,
                    "The system did not report free or total storage.",
                )
            }
        } catch (t: Throwable) {
            Probe(PerfCapabilityState.UNAVAILABLE, "Storage space could not be read.")
        }
    }

    // -------------------------------------------------------------------------------------------
    // Screen state
    // -------------------------------------------------------------------------------------------

    private fun probeScreenState(context: Context): Probe {
        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                ?: return Probe(PerfCapabilityState.UNAVAILABLE, "Power service is not available.")
            // Reading isInteractive is the probe itself: on unsupported builds it throws.
            @Suppress("UNUSED_VARIABLE")
            val interactive = powerManager.isInteractive
            Probe(PerfCapabilityState.AVAILABLE, null)
        } catch (t: Throwable) {
            Probe(PerfCapabilityState.UNAVAILABLE, "Screen state could not be read.")
        }
    }

    // -------------------------------------------------------------------------------------------
    // Per-app storage (Android 8.0 / API 26+, needs Usage Access for other apps)
    // -------------------------------------------------------------------------------------------

    private fun probePerAppStorage(context: Context, usageGranted: Boolean): Probe {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return Probe(
                PerfCapabilityState.UNAVAILABLE,
                "Per-app storage needs Android 8.0 (API 26) or newer. This phone runs Android " +
                    "${Build.VERSION.SDK_INT}.",
            )
        }
        if (!usageGranted) {
            return Probe(
                PerfCapabilityState.PERMISSION_NEEDED,
                "Usage Access is needed to see how much space other apps use.",
            )
        }
        return try {
            val storageStatsManager =
                context.getSystemService(Context.STORAGE_STATS_SERVICE) as? StorageStatsManager
                    ?: return Probe(
                        PerfCapabilityState.UNAVAILABLE,
                        "Storage statistics are not available on this device.",
                    )
            // Probing our own uid just verifies the API answers; other apps need the same access.
            storageStatsManager.queryStatsForUid(StorageManager.UUID_DEFAULT, Process.myUid())
            Probe(PerfCapabilityState.AVAILABLE, null)
        } catch (e: SecurityException) {
            Probe(
                PerfCapabilityState.PERMISSION_NEEDED,
                "The system blocked per-app storage readings (Usage Access may have been revoked).",
            )
        } catch (e: IOException) {
            Probe(PerfCapabilityState.UNAVAILABLE, "Per-app storage readings failed on this device.")
        } catch (t: Throwable) {
            Probe(PerfCapabilityState.UNAVAILABLE, "Per-app storage readings failed on this device.")
        }
    }

    // -------------------------------------------------------------------------------------------
    // Per-app network (API 23+, needs Usage Access)
    // -------------------------------------------------------------------------------------------

    private fun probePerAppNetwork(context: Context, usageGranted: Boolean): Probe {
        if (!usageGranted) {
            return Probe(
                PerfCapabilityState.PERMISSION_NEEDED,
                "Usage Access is needed to see how much data apps used in the background.",
            )
        }
        return try {
            val networkStatsManager =
                context.getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager
                    ?: return Probe(
                        PerfCapabilityState.UNAVAILABLE,
                        "Network statistics are not available on this device.",
                    )
            val end = System.currentTimeMillis()
            // A short window is enough to prove the API answers; no data is stored here.
            networkStatsManager.querySummaryForDevice(
                ConnectivityManager.TYPE_WIFI,
                null,
                end - 60_000L,
                end,
            )
            Probe(PerfCapabilityState.AVAILABLE, null)
        } catch (e: SecurityException) {
            Probe(
                PerfCapabilityState.PERMISSION_NEEDED,
                "The system blocked network statistics (Usage Access may have been revoked).",
            )
        } catch (t: Throwable) {
            Probe(
                PerfCapabilityState.UNAVAILABLE,
                "This device does not allow network usage statistics to be read.",
            )
        }
    }

    // -------------------------------------------------------------------------------------------
    // Usage events (needs Usage Access)
    // -------------------------------------------------------------------------------------------

    private fun probeUsageEvents(context: Context, usageGranted: Boolean): Probe {
        if (!usageGranted) {
            return Probe(
                PerfCapabilityState.PERMISSION_NEEDED,
                "Usage Access is needed to know which apps were open and for how long.",
            )
        }
        return try {
            val usageStatsManager =
                context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
                    ?: return Probe(
                        PerfCapabilityState.UNAVAILABLE,
                        "Usage events are not available on this device.",
                    )
            val end = System.currentTimeMillis()
            // An empty result is a valid answer (nothing moved in the last minute), not a failure.
            usageStatsManager.queryEvents(end - 60_000L, end)
            Probe(PerfCapabilityState.AVAILABLE, null)
        } catch (e: SecurityException) {
            Probe(
                PerfCapabilityState.PERMISSION_NEEDED,
                "The system blocked app usage history (Usage Access may have been revoked).",
            )
        } catch (t: Throwable) {
            Probe(PerfCapabilityState.UNAVAILABLE, "App usage history could not be read.")
        }
    }
}
