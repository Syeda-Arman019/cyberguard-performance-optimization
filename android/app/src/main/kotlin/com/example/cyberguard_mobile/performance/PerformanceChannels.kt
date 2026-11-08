package com.example.cyberguard_mobile.performance

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.cyberguard_mobile.performance.data.PerfAppStorageEntity
import com.example.cyberguard_mobile.performance.data.PerfCapabilityEntity
import com.example.cyberguard_mobile.performance.data.PerfDatabase
import com.example.cyberguard_mobile.performance.data.PerfDeviceInfoEntity
import com.example.cyberguard_mobile.performance.data.PerfMetric
import com.example.cyberguard_mobile.performance.data.PerfSampleEntity
import com.example.cyberguard_mobile.performance.sampling.PerfSampler
import com.example.cyberguard_mobile.performance.usage.UsageAccessHelper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/** Channel name; every CyberGuard performance channel starts with this prefix. */
const val PERF_CHANNEL_NAME: String = "cyberguard/performance"

/**
 * Registers the module's MethodChannel. This is the ONE line MainActivity adds.
 *
 * All channel code lives here so the merge into the main app only has to call this function.
 * Method handlers do their database / file work on a single background thread and always
 * answer on the platform (main) thread.
 */
fun registerPerformanceChannels(flutterEngine: FlutterEngine, context: Context) {
    val appContext = context.applicationContext
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERF_CHANNEL_NAME)
        .setMethodCallHandler(PerfMethodHandler(appContext))

    // One sample per app open, device info on first run, capability probe, worker scheduling.
    PerfStartup.initialize(appContext)
}

/**
 * MethodChannel handler for "cyberguard/performance".
 *
 * Methods:
 *  - getCapabilities            -> List<Map> {metricName, state, reason?, checkedAt}
 *  - getLatestSample            -> Map? (null when nothing has been sampled yet)
 *  - getSamples(sinceMillis)    -> List<Map> in ascending time order
 *  - isUsageAccessGranted       -> Boolean
 *  - openUsageAccessSettings    -> Boolean (true when a settings screen was opened)
 *  - collectSampleNow           -> Map? of the newly stored sample
 *  - exportSamplesCsv           -> String? absolute path of the written CSV file
 *  - getDeviceInfo              -> Map?
 *  - clearAllData               -> Boolean
 *
 * Unavailable values cross the channel as Kotlin null, which arrives in Dart as null -
 * never as 0.
 */
private class PerfMethodHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "PerfChannels"

        /** CSV column order; matches the perf_samples table. */
        private val CSV_COLUMNS = listOf(
            "id",
            "timestamp",
            "battery_pct",
            "battery_temp_c",
            "charging_state",
            "plugged_type",
            "battery_current_ua",
            "thermal_status",
            "screen_interactive",
            "mem_total_mb",
            "mem_avail_mb",
            "low_memory",
            "storage_free_bytes",
            "storage_total_bytes",
        )

        private val EXPORT_FILE_DATE = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)

        /**
         * One thread for all channel work: the database is a single writer, and serialising
         * keeps "collect now" from racing "export CSV".
         */
        private val executor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "perf-channel").apply { isDaemon = true }
        }

        /** MethodChannel results must be delivered on the platform thread. */
        private val mainHandler = Handler(Looper.getMainLooper())
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCapabilities" -> io(result) { capabilitiesPayload() }

            "getLatestSample" -> io(result) {
                PerfDatabase.get(context).perfDao().latestSample()?.let { sampleToMap(it) }
            }

            "getSamples" -> {
                val since = (call.arguments as? Number)?.toLong() ?: 0L
                io(result) {
                    PerfDatabase.get(context).perfDao().samplesSince(since).map { sampleToMap(it) }
                }
            }

            "isUsageAccessGranted" -> io(result) { UsageAccessHelper.isGranted(context) }

            "openUsageAccessSettings" -> io(result) { UsageAccessHelper.openSettings(context) }

            "collectSampleNow" -> io(result) {
                PerfSampler.collectSample(context)
                // Re-read so the UI shows exactly what the database holds (including nulls).
                PerfDatabase.get(context).perfDao().latestSample()?.let { sampleToMap(it) }
            }

            "exportSamplesCsv" -> io(result) { exportSamplesCsv() }

            "getDeviceInfo" -> io(result) {
                PerfDatabase.get(context).perfDao().latestDeviceInfo()?.let { deviceInfoToMap(it) }
            }

            "clearAllData" -> io(result) { clearAllData() }

            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------------------------
    // Work helpers
    // -------------------------------------------------------------------------------------------

    /** Runs [block] on the background executor and reports success/error on the main thread. */
    private fun io(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            val outcome = try {
                Result.success(block())
            } catch (t: Throwable) {
                Log.w(TAG, "Channel call failed", t)
                Result.failure(t)
            }
            mainHandler.post {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = {
                        result.error(
                            "perf_error",
                            it.message ?: it.javaClass.simpleName,
                            null,
                        )
                    },
                )
            }
        }
    }

    // -------------------------------------------------------------------------------------------
    // Payload builders
    // -------------------------------------------------------------------------------------------

    /** Capabilities in the canonical metric order (PerfMetric.ALL), so the UI is stable. */
    private fun capabilitiesPayload(): List<Map<String, Any?>> {
        val stored = PerfDatabase.get(context).perfDao().capabilities().associateBy { it.metricName }
        val order = PerfMetric.ALL
        val sorted = stored.values.sortedBy { entity ->
            val index = order.indexOf(entity.metricName)
            if (index >= 0) index else Int.MAX_VALUE
        }
        return sorted.map { capabilityToMap(it) }
    }

    private fun capabilityToMap(entity: PerfCapabilityEntity): Map<String, Any?> = mapOf(
        "metricName" to entity.metricName,
        "state" to entity.state,
        "reason" to entity.reason,
        "checkedAt" to entity.checkedAt,
    )

    private fun sampleToMap(entity: PerfSampleEntity): Map<String, Any?> = mapOf(
        "id" to entity.id,
        "timestamp" to entity.timestamp,
        "batteryPct" to entity.batteryPct,
        "batteryTempC" to entity.batteryTempC,
        "chargingState" to entity.chargingState,
        "pluggedType" to entity.pluggedType,
        "batteryCurrentUa" to entity.batteryCurrentUa,
        "thermalStatus" to entity.thermalStatus,
        "screenInteractive" to entity.screenInteractive,
        "memTotalMb" to entity.memTotalMb,
        "memAvailMb" to entity.memAvailMb,
        "lowMemory" to entity.lowMemory,
        "storageFreeBytes" to entity.storageFreeBytes,
        "storageTotalBytes" to entity.storageTotalBytes,
    )

    private fun deviceInfoToMap(entity: PerfDeviceInfoEntity): Map<String, Any?> = mapOf(
        "totalRamMb" to entity.totalRamMb,
        "batteryCapacityMah" to entity.batteryCapacityMah,
        "deviceModel" to entity.deviceModel,
        "androidSdk" to entity.androidSdk,
        "recordedAt" to entity.recordedAt,
    )

    /** Kept for the app-storage table so the shape is already defined for later prompts. */
    @Suppress("unused")
    private fun appStorageToMap(entity: PerfAppStorageEntity): Map<String, Any?> = mapOf(
        "id" to entity.id,
        "timestamp" to entity.timestamp,
        "packageName" to entity.packageName,
        "appLabel" to entity.appLabel,
        "appBytes" to entity.appBytes,
        "dataBytes" to entity.dataBytes,
        "cacheBytes" to entity.cacheBytes,
    )

    // -------------------------------------------------------------------------------------------
    // CSV export
    // -------------------------------------------------------------------------------------------

    /**
     * Writes every stored sample to a CSV file in the app's external files directory
     * (app-specific storage: no permission needed, removed with the app) and returns its path.
     *
     * A missing value is written as an EMPTY cell, never as 0.
     */
    private fun exportSamplesCsv(): String? {
        val dao = PerfDatabase.get(context).perfDao()
        val samples = dao.samplesSince(0L)

        val directory = context.getExternalFilesDir(null) ?: File(context.filesDir, "perf_exports")
        if (!directory.exists() && !directory.mkdirs()) {
            Log.w(TAG, "Could not create export directory $directory")
            return null
        }
        val file = File(directory, "perf_samples_${EXPORT_FILE_DATE.format(Date())}.csv")

        val builder = StringBuilder()
        builder.append(CSV_COLUMNS.joinToString(",")).append('\n')
        samples.forEach { sample ->
            val row = listOf(
                sample.id,
                sample.timestamp,
                sample.batteryPct,
                sample.batteryTempC,
                sample.chargingState,
                sample.pluggedType,
                sample.batteryCurrentUa,
                sample.thermalStatus,
                sample.screenInteractive,
                sample.memTotalMb,
                sample.memAvailMb,
                sample.lowMemory,
                sample.storageFreeBytes,
                sample.storageTotalBytes,
            )
            builder.append(row.joinToString(",") { csvCell(it) }).append('\n')
        }

        file.writeText(builder.toString())
        return file.absolutePath
    }

    /** Empty string for null (an honest "no value"), quoted when the value contains a comma. */
    private fun csvCell(value: Any?): String {
        if (value == null) return ""
        val text = value.toString()
        return if (text.contains(',') || text.contains('"')) {
            "\"${text.replace("\"", "\"\"")}\""
        } else {
            text
        }
    }

    // -------------------------------------------------------------------------------------------
    // Wipe
    // -------------------------------------------------------------------------------------------

    /**
     * Deletes all rows from every module table (debug / "clear all data").
     * The device-info row is recreated on the next app open by PerfStartup.
     */
    private fun clearAllData(): Boolean {
        val dao = PerfDatabase.get(context).perfDao()
        dao.deleteAllSamples()
        dao.deleteAllAppStorage()
        dao.deleteAllHeatSessions()
        dao.deleteAllFindings()
        dao.deleteAllExpected()
        dao.deleteAllChargingSessions()
        dao.deleteAllDeviceInfo()
        // Capabilities are re-probed at startup, so removing them is safe and honest.
        dao.deleteAllCapabilities()
        return true
    }
}
