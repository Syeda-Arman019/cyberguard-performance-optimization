package com.example.cyberguard_mobile.performance.sampling

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.StatFs
import android.util.Log
import com.example.cyberguard_mobile.performance.data.PerfChargingState
import com.example.cyberguard_mobile.performance.data.PerfDatabase
import com.example.cyberguard_mobile.performance.data.PerfDeviceInfoEntity
import com.example.cyberguard_mobile.performance.data.PerfPluggedType
import com.example.cyberguard_mobile.performance.data.PerfSampleEntity

/**
 * Collects one health sample from real Android APIs and stores it.
 *
 * Honesty rules implemented here:
 *  - The stored timestamp is the ACTUAL collection time (WorkManager may run the periodic
 *    job late, so the scheduled time is never stored).
 *  - A metric the device does not report is stored as NULL, never as 0.
 *  - Battery temperature and PowerManager thermal status are independent fields.
 *  - If a value that the schema requires (memory, storage) cannot be read, no row is written
 *    at all rather than a row full of zeros.
 *
 * Threading: all functions block on the database and MUST be called off the main thread
 * (the WorkManager worker, the channel executor and the startup executor all qualify).
 */
object PerfSampler {

    private const val TAG = "PerfSampler"

    private const val BYTES_PER_MB = 1024L * 1024L

    /** Values read from the sticky battery broadcast; every field can be missing. */
    private data class BatterySnapshot(
        val percent: Int?,
        val tempC: Double?,
        val chargingState: String,
        val pluggedType: String,
        val currentUa: Long?,
    )

    /**
     * Reads and stores one sample.
     *
     * @return the new row id, or null when the sample could not be collected (nothing is stored).
     */
    fun collectSample(context: Context): Long? {
        val appContext = context.applicationContext

        // Actual measurement time, taken before any (possibly slow) API calls.
        val timestamp = System.currentTimeMillis()

        val memory = readMemoryInfo(appContext)
        if (memory == null) {
            Log.w(TAG, "Skipping sample: memory information is unavailable on this device")
            return null
        }

        val storage = readStorage(appContext)
        if (storage == null) {
            Log.w(TAG, "Skipping sample: storage information is unavailable on this device")
            return null
        }

        val battery = readBattery(appContext)
        val sample = PerfSampleEntity(
            timestamp = timestamp,
            batteryPct = battery?.percent,
            batteryTempC = battery?.tempC,
            chargingState = battery?.chargingState ?: PerfChargingState.UNKNOWN,
            pluggedType = battery?.pluggedType ?: PerfPluggedType.UNKNOWN,
            batteryCurrentUa = battery?.currentUa,
            thermalStatus = readThermalStatus(appContext),
            screenInteractive = readScreenInteractive(appContext),
            memTotalMb = memory.totalMb,
            memAvailMb = memory.availMb,
            lowMemory = memory.lowMemory,
            storageFreeBytes = storage.first,
            storageTotalBytes = storage.second,
        )

        return try {
            PerfDatabase.get(appContext).perfDao().insertSample(sample)
        } catch (t: Throwable) {
            Log.w(TAG, "Could not insert sample", t)
            null
        }
    }

    /**
     * Stores the device information row exactly once (first install / first app open).
     *
     * battery_capacity_mah is left NULL: Android has no public API for design capacity, and
     * estimating it from the charge counter would be a guess, not a measurement.
     *
     * @return true when a new row was written.
     */
    fun ensureDeviceInfo(context: Context): Boolean {
        val appContext = context.applicationContext
        return try {
            val dao = PerfDatabase.get(appContext).perfDao()
            if (dao.latestDeviceInfo() != null) {
                return false
            }
            val memory = readMemoryInfo(appContext) ?: return false
            dao.insertDeviceInfo(
                PerfDeviceInfoEntity(
                    recordedAt = System.currentTimeMillis(),
                    totalRamMb = memory.totalMb,
                    batteryCapacityMah = null,
                    deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
                    androidSdk = Build.VERSION.SDK_INT,
                ),
            )
            true
        } catch (t: Throwable) {
            Log.w(TAG, "Could not record device information", t)
            false
        }
    }

    // -------------------------------------------------------------------------------------------
    // Battery
    // -------------------------------------------------------------------------------------------

    /**
     * Reads the sticky ACTION_BATTERY_CHANGED broadcast.
     * No receiver is registered (and none is declared in the manifest): passing a null
     * receiver returns the last sticky broadcast immediately.
     */
    private fun readBattery(context: Context): BatterySnapshot? {
        val intent: Intent = try {
            context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                ?: return null
        } catch (t: Throwable) {
            Log.w(TAG, "Battery broadcast unavailable", t)
            return null
        }

        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val percent = if (scale > 0 && level in 0..scale) {
            Math.round(level * 100f / scale)
        } else {
            null
        }

        // EXTRA_TEMPERATURE is in tenths of a degree Celsius. 0 or negative means "not reported";
        // anything above 100 C is not a real phone battery reading.
        val tempTenths = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
        val tempC = if (tempTenths in 1..1000) tempTenths / 10.0 else null

        val chargingState = when (intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)) {
            BatteryManager.BATTERY_STATUS_CHARGING -> PerfChargingState.CHARGING
            BatteryManager.BATTERY_STATUS_DISCHARGING -> PerfChargingState.DISCHARGING
            BatteryManager.BATTERY_STATUS_FULL -> PerfChargingState.FULL
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> PerfChargingState.NOT_CHARGING
            else -> PerfChargingState.UNKNOWN
        }

        val pluggedType = when (intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)) {
            0 -> PerfPluggedType.NONE
            BatteryManager.BATTERY_PLUGGED_AC -> PerfPluggedType.AC
            BatteryManager.BATTERY_PLUGGED_USB -> PerfPluggedType.USB
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> PerfPluggedType.WIRELESS
            // BATTERY_PLUGGED_DOCK exists from API 33; the raw value is used so older devices
            // simply fall through to "unknown" instead of needing an API check.
            8 -> PerfPluggedType.DOCK
            else -> PerfPluggedType.UNKNOWN
        }

        return BatterySnapshot(
            percent = percent,
            tempC = tempC,
            chargingState = chargingState,
            pluggedType = pluggedType,
            currentUa = readBatteryCurrent(context),
        )
    }

    /**
     * BatteryManager.BATTERY_PROPERTY_CURRENT_NOW.
     *
     * The documented unit is microamperes, but several OEMs report milliamperes, so the raw
     * value is stored and an implausible reading (> 20 A in microamperes) is dropped rather
     * than normalised. Devices that always answer 0 yield NULL: "not measured", not "0 A".
     */
    private fun readBatteryCurrent(context: Context): Long? {
        return try {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                ?: return null
            val raw = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
            if (raw == 0 || raw == Int.MIN_VALUE) {
                null
            } else if (kotlin.math.abs(raw.toLong()) > 20_000_000L) {
                Log.i(TAG, "Dropping implausible battery current reading: $raw")
                null
            } else {
                raw.toLong()
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Battery current unavailable", t)
            null
        }
    }

    // -------------------------------------------------------------------------------------------
    // Thermal status (separate from battery temperature)
    // -------------------------------------------------------------------------------------------

    /** PowerManager.currentThermalStatus on API 29+; NULL below that (the API does not exist). */
    private fun readThermalStatus(context: Context): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return null
        }
        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.currentThermalStatus
        } catch (t: Throwable) {
            Log.w(TAG, "Thermal status unavailable", t)
            null
        }
    }

    // -------------------------------------------------------------------------------------------
    // Memory
    // -------------------------------------------------------------------------------------------

    private data class MemorySnapshot(val totalMb: Long, val availMb: Long, val lowMemory: Boolean)

    /** ActivityManager.getMemoryInfo is available on every supported Android version. */
    private fun readMemoryInfo(context: Context): MemorySnapshot? {
        return try {
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: return null
            val info = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(info)
            if (info.totalMem <= 0L) {
                return null
            }
            MemorySnapshot(
                totalMb = info.totalMem / BYTES_PER_MB,
                availMb = info.availMem / BYTES_PER_MB,
                lowMemory = info.lowMemory,
            )
        } catch (t: Throwable) {
            Log.w(TAG, "Memory info unavailable", t)
            null
        }
    }

    // -------------------------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------------------------

    /** Free / total bytes of the app data partition via StatFs. */
    private fun readStorage(context: Context): Pair<Long, Long>? {
        return try {
            val stat = StatFs(context.filesDir.absolutePath)
            val total = stat.totalBytes
            val free = stat.availableBytes
            if (total <= 0L || free < 0L) null else Pair(free, total)
        } catch (t: Throwable) {
            Log.w(TAG, "Storage info unavailable", t)
            null
        }
    }

    // -------------------------------------------------------------------------------------------
    // Screen
    // -------------------------------------------------------------------------------------------

    /** PowerManager.isInteractive: true when the screen is on and unlocked. */
    private fun readScreenInteractive(context: Context): Boolean? {
        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.isInteractive
        } catch (t: Throwable) {
            Log.w(TAG, "Screen state unavailable", t)
            null
        }
    }
}
