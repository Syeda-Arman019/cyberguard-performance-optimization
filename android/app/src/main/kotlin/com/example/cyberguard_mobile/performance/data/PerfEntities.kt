package com.example.cyberguard_mobile.performance.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * CyberGuard Mobile - "Performance Optimization" module.
 *
 * Local database schema, version 1.
 *
 * Design rules that later features depend on:
 *  - Every metric that can be missing (device, Android version, OEM, permission) is NULLABLE.
 *    NULL means "not measured / not available". 0 is only ever a real measured value.
 *  - Timestamps are the ACTUAL measurement time in epoch milliseconds. WorkManager may run
 *    a periodic job late, so the scheduled time is never stored.
 *  - All tables are created now, at version 1, so later feature prompts never need a migration.
 *    Any future schema change must bump [PerfDatabase.VERSION] and add an explicit
 *    [androidx.room.migration.Migration] in PerfDatabase.MIGRATIONS. Destructive
 *    fallback is intentionally NOT enabled: silent data loss is worse than a loud crash.
 *  - No R / BuildConfig references anywhere in this module (it is merged into the main app).
 */

/** State of a single measured metric on this device. */
enum class PerfCapabilityState {
    /** The metric can be read reliably right now. */
    AVAILABLE,

    /** The metric cannot be read at all (unsupported device, Android version or OEM). */
    UNAVAILABLE,

    /** The metric can be read but the value cannot be trusted on this device. */
    UNRELIABLE,

    /** The metric needs a user-granted permission (Usage Access) that is not granted. */
    PERMISSION_NEEDED,
}

/**
 * Canonical metric names used in [PerfCapabilityEntity.metricName].
 * Keep these stable: the Dart side and future screens key off them.
 */
object PerfMetric {
    const val BATTERY_LEVEL = "battery_level"
    const val BATTERY_TEMPERATURE = "battery_temperature"
    const val BATTERY_CURRENT = "battery_current_now"
    const val THERMAL_STATUS = "thermal_status"
    const val MEMORY_INFO = "memory_info"
    const val STORAGE_STATS = "storage_stats"
    const val SCREEN_STATE = "screen_state"
    const val PER_APP_STORAGE = "per_app_storage_stats"
    const val PER_APP_NETWORK = "per_app_network_stats"
    const val USAGE_EVENTS = "usage_events"
    const val USAGE_ACCESS = "usage_access"

    /** Order used by the debug screen / capability report. */
    val ALL = listOf(
        BATTERY_LEVEL,
        BATTERY_TEMPERATURE,
        BATTERY_CURRENT,
        THERMAL_STATUS,
        MEMORY_INFO,
        STORAGE_STATS,
        SCREEN_STATE,
        PER_APP_STORAGE,
        PER_APP_NETWORK,
        USAGE_EVENTS,
        USAGE_ACCESS,
    )
}

/** Values stored in [PerfSampleEntity.chargingState]. */
object PerfChargingState {
    const val CHARGING = "charging"
    const val DISCHARGING = "discharging"
    const val FULL = "full"
    const val NOT_CHARGING = "not_charging"
    const val UNKNOWN = "unknown"
}

/** Values stored in [PerfSampleEntity.pluggedType] and [PerfChargingSessionEntity.pluggedType]. */
object PerfPluggedType {
    const val NONE = "none"
    const val AC = "ac"
    const val USB = "usb"
    const val WIRELESS = "wireless"
    const val DOCK = "dock"
    const val UNKNOWN = "unknown"
}

/**
 * One point-in-time measurement of device health.
 *
 * One row per sample; the periodic sampler inserts one row every ~15 minutes and one row
 * on every app open. Missing hardware readings are NULL.
 */
@Entity(
    tableName = "perf_samples",
    indices = [Index(value = ["timestamp"])],
)
data class PerfSampleEntity(
    @PrimaryKey(autoGenerate = true)
    @ColumnInfo(name = "id")
    val id: Long = 0L,

    /** Actual measurement time, epoch milliseconds. */
    @ColumnInfo(name = "timestamp")
    val timestamp: Long,

    /** Battery percentage 0..100; NULL when the sticky battery broadcast is unavailable. */
    @ColumnInfo(name = "battery_pct")
    val batteryPct: Int? = null,

    /** Battery temperature in degrees Celsius; NULL when the device does not report it. */
    @ColumnInfo(name = "battery_temp_c")
    val batteryTempC: Double? = null,

    /** See [PerfChargingState]; "unknown" when the device does not report a status. */
    @ColumnInfo(name = "charging_state")
    val chargingState: String,

    /** See [PerfPluggedType]; "unknown" when the device does not report a plugged type. */
    @ColumnInfo(name = "plugged_type")
    val pluggedType: String,

    /**
     * Raw BatteryManager.BATTERY_PROPERTY_CURRENT_NOW value.
     * The Android API documents microamperes, but some OEMs report milliamperes, so a value
     * that is implausible is dropped (NULL) instead of being normalised or guessed.
     */
    @ColumnInfo(name = "battery_current_ua")
    val batteryCurrentUa: Long? = null,

    /**
     * PowerManager thermal status (0 = none ... 6 = shutdown). NULL below Android 10 (API 29)
     * where the API does not exist, and separate from [batteryTempC] - they are different signals.
     */
    @ColumnInfo(name = "thermal_status")
    val thermalStatus: Int? = null,

    /** PowerManager.isInteractive at sample time; NULL if it could not be read. */
    @ColumnInfo(name = "screen_interactive")
    val screenInteractive: Boolean? = null,

    /** ActivityManager.MemoryInfo.totalMem in MB (always available on Android). */
    @ColumnInfo(name = "mem_total_mb")
    val memTotalMb: Long,

    /** ActivityManager.MemoryInfo.availMem in MB. */
    @ColumnInfo(name = "mem_avail_mb")
    val memAvailMb: Long,

    /** ActivityManager.MemoryInfo.lowMemory (system-level low memory flag). */
    @ColumnInfo(name = "low_memory")
    val lowMemory: Boolean,

    /** StatFs.availableBytes of the app data partition. */
    @ColumnInfo(name = "storage_free_bytes")
    val storageFreeBytes: Long,

    /** StatFs.totalBytes of the app data partition. */
    @ColumnInfo(name = "storage_total_bytes")
    val storageTotalBytes: Long,
)

/**
 * Result of the startup capability probe for one metric.
 * One row per metric; re-probed on every app start and overwritten in place.
 */
@Entity(tableName = "perf_capabilities")
data class PerfCapabilityEntity(
    @PrimaryKey
    @ColumnInfo(name = "metric_name")
    val metricName: String,

    /** One of [PerfCapabilityState] names, e.g. "PERMISSION_NEEDED". */
    @ColumnInfo(name = "state")
    val state: String,

    /** Human-readable explanation shown to the user; never null when a metric is not AVAILABLE. */
    @ColumnInfo(name = "reason")
    val reason: String? = null,

    /** When this probe ran, epoch milliseconds. */
    @ColumnInfo(name = "checked_at")
    val checkedAt: Long,
)

/**
 * Static-ish device information, captured once (first install / first app open).
 * Recorded again only if the table is empty (a re-install creates a new database).
 */
@Entity(tableName = "perf_device_info")
data class PerfDeviceInfoEntity(
    /** Natural key: the capture time. Avoids inventing an extra id column. */
    @PrimaryKey
    @ColumnInfo(name = "recorded_at")
    val recordedAt: Long,

    /** ActivityManager.MemoryInfo.totalMem in MB. */
    @ColumnInfo(name = "total_ram_mb")
    val totalRamMb: Long,

    /**
     * Design battery capacity in mAh, or NULL.
     * Android has no public API for design capacity, so this stays NULL unless a future
     * prompt adds a trustworthy source. It is never estimated from a percentage.
     */
    @ColumnInfo(name = "battery_capacity_mah")
    val batteryCapacityMah: Int? = null,

    /** Build.MANUFACTURER + " " + Build.MODEL. */
    @ColumnInfo(name = "device_model")
    val deviceModel: String,

    /** Build.VERSION.SDK_INT. */
    @ColumnInfo(name = "android_sdk")
    val androidSdk: Int,
)

/**
 * Per-app storage usage snapshot (StorageStatsManager, API 26+).
 * Requires Usage Access for other packages; this app's own row needs no permission.
 */
@Entity(
    tableName = "perf_app_storage",
    indices = [Index(value = ["timestamp"]), Index(value = ["package_name"])],
)
data class PerfAppStorageEntity(
    @PrimaryKey(autoGenerate = true)
    @ColumnInfo(name = "id")
    val id: Long = 0L,

    /** Actual measurement time, epoch milliseconds. */
    @ColumnInfo(name = "timestamp")
    val timestamp: Long,

    @ColumnInfo(name = "package_name")
    val packageName: String,

    /** User-visible app name, or the package name if the label could not be resolved. */
    @ColumnInfo(name = "app_label")
    val appLabel: String,

    /** App code size in bytes; NULL when StorageStats could not be read for this package. */
    @ColumnInfo(name = "app_bytes")
    val appBytes: Long? = null,

    /** App data size in bytes; NULL when unavailable. */
    @ColumnInfo(name = "data_bytes")
    val dataBytes: Long? = null,

    /** App cache size in bytes; NULL when unavailable. */
    @ColumnInfo(name = "cache_bytes")
    val cacheBytes: Long? = null,
)

/**
 * One heat episode (a period where battery temperature / thermal status stayed elevated).
 * Written by the analysis layer in a later prompt; the table exists now so no migration is needed.
 */
@Entity(
    tableName = "perf_heat_sessions",
    indices = [Index(value = ["start_ts"])],
)
data class PerfHeatSessionEntity(
    @PrimaryKey(autoGenerate = true)
    @ColumnInfo(name = "id")
    val id: Long = 0L,

    @ColumnInfo(name = "start_ts")
    val startTs: Long,

    /** NULL while a session is still open. */
    @ColumnInfo(name = "end_ts")
    val endTs: Long? = null,

    /** Highest battery temperature seen during the session, degrees Celsius. */
    @ColumnInfo(name = "peak_temp_c")
    val peakTempC: Double? = null,

    /** Highest PowerManager thermal status seen during the session; NULL below API 29. */
    @ColumnInfo(name = "peak_thermal_status")
    val peakThermalStatus: Int? = null,

    /** Whether the device was charging at any point during the session. */
    @ColumnInfo(name = "charging_during")
    val chargingDuring: Boolean,

    /** Foreground package observed during the session, or NULL when unknown. */
    @ColumnInfo(name = "foreground_package")
    val foregroundPackage: String? = null,

    /** Minutes until the session cooled down, or NULL when it did not cool within the window. */
    @ColumnInfo(name = "recovery_minutes")
    val recoveryMinutes: Int? = null,

    /** Number of samples that fell inside the session. */
    @ColumnInfo(name = "sample_count")
    val sampleCount: Int,

    /** Largest gap between two samples inside the session, in minutes (data-quality hint). */
    @ColumnInfo(name = "max_sample_gap_min")
    val maxSampleGapMin: Int,
)

/**
 * A user-facing finding produced by the rule engine.
 * Wording rule: "possible contributing factor", never certainty.
 */
@Entity(
    tableName = "perf_findings",
    indices = [Index(value = ["timestamp"]), Index(value = ["rule_id"])],
)
data class PerfFindingEntity(
    @PrimaryKey(autoGenerate = true)
    @ColumnInfo(name = "id")
    val id: Long = 0L,

    /** Actual time the finding was created, epoch milliseconds. */
    @ColumnInfo(name = "timestamp")
    val timestamp: Long,

    /** Stable rule identifier, e.g. "battery.temp.high_while_charging". */
    @ColumnInfo(name = "rule_id")
    val ruleId: String,

    @ColumnInfo(name = "title")
    val title: String,

    /** LOW / MEDIUM / HIGH. */
    @ColumnInfo(name = "severity")
    val severity: String,

    /** LOW / MEDIUM / HIGH - how sure the evidence makes us. */
    @ColumnInfo(name = "confidence")
    val confidence: String,

    /** WHAT: what we measured. */
    @ColumnInfo(name = "what")
    val what: String,

    /** WHY IT MATTERS: plain-language consequence. */
    @ColumnInfo(name = "why")
    val why: String,

    /** IMPACT: how much it affects this phone, with the numbers. */
    @ColumnInfo(name = "impact")
    val impact: String,

    /** SOLUTION shape; the fix buttons only ever open an Android Settings page. */
    @ColumnInfo(name = "solution_kind")
    val solutionKind: String,

    /** Package the solution refers to, when the finding is app-specific. */
    @ColumnInfo(name = "solution_package")
    val solutionPackage: String? = null,

    /** Machine-readable evidence (sample counts, values, gaps) as a JSON object string. */
    @ColumnInfo(name = "evidence_json")
    val evidenceJson: String,

    /** Where the numbers came from, e.g. "BatteryManager sticky broadcast". */
    @ColumnInfo(name = "data_source")
    val dataSource: String,

    /** Analysis window start, epoch milliseconds. */
    @ColumnInfo(name = "window_start")
    val windowStart: Long,

    /** Analysis window end, epoch milliseconds. */
    @ColumnInfo(name = "window_end")
    val windowEnd: Long,

    /** True when the user dismissed/acknowledged this finding. */
    @ColumnInfo(name = "suppressed")
    val suppressed: Boolean,
)

/**
 * "Expected behaviour" entries: a user saying "this is normal for me".
 * NEVER deleted by the 30-day retention sweep.
 */
@Entity(
    tableName = "perf_expected",
    indices = [Index(value = ["rule_id"])],
)
data class PerfExpectedEntity(
    @PrimaryKey(autoGenerate = true)
    @ColumnInfo(name = "id")
    val id: Long = 0L,

    @ColumnInfo(name = "rule_id")
    val ruleId: String,

    /** NULL means "this rule is expected for the whole device, not one app". */
    @ColumnInfo(name = "package_name")
    val packageName: String? = null,

    @ColumnInfo(name = "created_at")
    val createdAt: Long,
)

/** One charging episode, used by the Battery Drain Finder. */
@Entity(
    tableName = "perf_charging_sessions",
    indices = [Index(value = ["start_ts"])],
)
data class PerfChargingSessionEntity(
    @PrimaryKey(autoGenerate = true)
    @ColumnInfo(name = "id")
    val id: Long = 0L,

    @ColumnInfo(name = "start_ts")
    val startTs: Long,

    /** NULL while charging is still in progress. */
    @ColumnInfo(name = "end_ts")
    val endTs: Long? = null,

    /** Battery percentage when charging started; NULL when not measured. */
    @ColumnInfo(name = "start_pct")
    val startPct: Int? = null,

    /** Battery percentage when charging ended; NULL when not measured. */
    @ColumnInfo(name = "end_pct")
    val endPct: Int? = null,

    /** Highest battery temperature during the session, degrees Celsius. */
    @ColumnInfo(name = "peak_temp_c")
    val peakTempC: Double? = null,

    /** True when the session was classified as a heat event. */
    @ColumnInfo(name = "heat_event")
    val heatEvent: Boolean,

    /** See [PerfPluggedType]. */
    @ColumnInfo(name = "plugged_type")
    val pluggedType: String,

    /** Number of samples that fell inside the session. */
    @ColumnInfo(name = "sample_count")
    val sampleCount: Int,
)
