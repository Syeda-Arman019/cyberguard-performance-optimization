package com.example.cyberguard_mobile.performance.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

/**
 * Data access for every CyberGuard performance table.
 *
 * All functions are blocking; callers must be on a background thread (the sampler, the
 * WorkManager worker and the MethodChannel executor all are). The UI thread is never used.
 *
 * Inserts for tables that later prompts fill (app storage, heat/charging sessions, findings,
 * expected rules) already exist so those prompts do not need to touch this file.
 */
@Dao
interface PerfDao {

    // ---------------------------------------------------------------------------------------
    // perf_samples
    // ---------------------------------------------------------------------------------------

    @Insert
    fun insertSample(sample: PerfSampleEntity): Long

    @Query("SELECT * FROM perf_samples ORDER BY timestamp DESC, id DESC LIMIT 1")
    fun latestSample(): PerfSampleEntity?

    /** ASC order so charts / gap detection can walk forward in time. */
    @Query("SELECT * FROM perf_samples WHERE timestamp >= :sinceMillis ORDER BY timestamp ASC, id ASC")
    fun samplesSince(sinceMillis: Long): List<PerfSampleEntity>

    @Query("SELECT COUNT(*) FROM perf_samples")
    fun countSamples(): Int

    @Query("DELETE FROM perf_samples WHERE timestamp < :cutoffMillis")
    fun deleteSamplesOlderThan(cutoffMillis: Long): Int

    // ---------------------------------------------------------------------------------------
    // perf_capabilities
    // ---------------------------------------------------------------------------------------

    /** One row per metric: REPLACE keeps a single up-to-date row per metric name. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsertCapabilities(capabilities: List<PerfCapabilityEntity>)

    @Query("SELECT * FROM perf_capabilities ORDER BY metric_name ASC")
    fun capabilities(): List<PerfCapabilityEntity>

    @Query("SELECT * FROM perf_capabilities WHERE metric_name = :metricName LIMIT 1")
    fun capability(metricName: String): PerfCapabilityEntity?

    // ---------------------------------------------------------------------------------------
    // perf_device_info
    // ---------------------------------------------------------------------------------------

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insertDeviceInfo(info: PerfDeviceInfoEntity): Long

    @Query("SELECT * FROM perf_device_info ORDER BY recorded_at DESC LIMIT 1")
    fun latestDeviceInfo(): PerfDeviceInfoEntity?

    // ---------------------------------------------------------------------------------------
    // perf_app_storage
    // ---------------------------------------------------------------------------------------

    @Insert
    fun insertAppStorage(entry: PerfAppStorageEntity): Long

    /** Batch variant; distinct name because Room does not like overloaded DAO methods. */
    @Insert
    fun insertAppStorageList(entries: List<PerfAppStorageEntity>)

    @Query("SELECT * FROM perf_app_storage WHERE timestamp >= :sinceMillis ORDER BY timestamp ASC, id ASC")
    fun appStorageSince(sinceMillis: Long): List<PerfAppStorageEntity>

    @Query("DELETE FROM perf_app_storage WHERE timestamp < :cutoffMillis")
    fun deleteAppStorageOlderThan(cutoffMillis: Long): Int

    // ---------------------------------------------------------------------------------------
    // perf_heat_sessions
    // ---------------------------------------------------------------------------------------

    @Insert
    fun insertHeatSession(session: PerfHeatSessionEntity): Long

    @Query("SELECT * FROM perf_heat_sessions WHERE start_ts >= :sinceMillis ORDER BY start_ts ASC")
    fun heatSessionsSince(sinceMillis: Long): List<PerfHeatSessionEntity>

    @Query("DELETE FROM perf_heat_sessions WHERE start_ts < :cutoffMillis")
    fun deleteHeatSessionsOlderThan(cutoffMillis: Long): Int

    // ---------------------------------------------------------------------------------------
    // perf_findings
    // ---------------------------------------------------------------------------------------

    @Insert
    fun insertFinding(finding: PerfFindingEntity): Long

    @Insert
    fun insertFindings(findings: List<PerfFindingEntity>)

    @Query("SELECT * FROM perf_findings ORDER BY timestamp DESC, id DESC")
    fun findings(): List<PerfFindingEntity>

    @Query("SELECT * FROM perf_findings WHERE timestamp >= :sinceMillis ORDER BY timestamp DESC, id DESC")
    fun findingsSince(sinceMillis: Long): List<PerfFindingEntity>

    @Query("DELETE FROM perf_findings WHERE timestamp < :cutoffMillis")
    fun deleteFindingsOlderThan(cutoffMillis: Long): Int

    // ---------------------------------------------------------------------------------------
    // perf_expected (never pruned by retention)
    // ---------------------------------------------------------------------------------------

    @Insert
    fun insertExpected(expected: PerfExpectedEntity): Long

    @Query("SELECT * FROM perf_expected ORDER BY created_at DESC")
    fun expected(): List<PerfExpectedEntity>

    // ---------------------------------------------------------------------------------------
    // perf_charging_sessions
    // ---------------------------------------------------------------------------------------

    @Insert
    fun insertChargingSession(session: PerfChargingSessionEntity): Long

    @Query("SELECT * FROM perf_charging_sessions WHERE start_ts >= :sinceMillis ORDER BY start_ts ASC")
    fun chargingSessionsSince(sinceMillis: Long): List<PerfChargingSessionEntity>

    @Query("DELETE FROM perf_charging_sessions WHERE start_ts < :cutoffMillis")
    fun deleteChargingSessionsOlderThan(cutoffMillis: Long): Int

    // ---------------------------------------------------------------------------------------
    // Full wipe (debug / "clear all data")
    // ---------------------------------------------------------------------------------------

    @Query("DELETE FROM perf_samples")
    fun deleteAllSamples(): Int

    @Query("DELETE FROM perf_capabilities")
    fun deleteAllCapabilities(): Int

    @Query("DELETE FROM perf_device_info")
    fun deleteAllDeviceInfo(): Int

    @Query("DELETE FROM perf_app_storage")
    fun deleteAllAppStorage(): Int

    @Query("DELETE FROM perf_heat_sessions")
    fun deleteAllHeatSessions(): Int

    @Query("DELETE FROM perf_findings")
    fun deleteAllFindings(): Int

    @Query("DELETE FROM perf_expected")
    fun deleteAllExpected(): Int

    @Query("DELETE FROM perf_charging_sessions")
    fun deleteAllChargingSessions(): Int
}
