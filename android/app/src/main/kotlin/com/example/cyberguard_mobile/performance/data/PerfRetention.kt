package com.example.cyberguard_mobile.performance.data

import android.content.Context
import android.util.Log

/**
 * 30-day retention for measured history.
 *
 * Runs after every periodic sample (and once when the app opens), so the database stays small
 * without a separate cleanup job.
 *
 * perf_expected is NEVER pruned: those rows are explicit user statements ("this is normal
 * for me") and must survive forever.
 */
object PerfRetention {

    private const val TAG = "PerfRetention"

    /** Anything older than this is deleted. */
    const val RETENTION_DAYS: Long = 30L

    private const val MILLIS_PER_DAY: Long = 24L * 60L * 60L * 1000L

    /**
     * Deletes rows older than [RETENTION_DAYS] days from every measured-history table.
     *
     * @param now current time, overridable for tests.
     * @return total number of deleted rows, or -1 when the sweep failed.
     */
    fun prune(context: Context, now: Long = System.currentTimeMillis()): Int {
        val cutoff = now - RETENTION_DAYS * MILLIS_PER_DAY
        return try {
            val dao = PerfDatabase.get(context).perfDao()
            val deleted = dao.deleteSamplesOlderThan(cutoff) +
                dao.deleteAppStorageOlderThan(cutoff) +
                dao.deleteHeatSessionsOlderThan(cutoff) +
                dao.deleteFindingsOlderThan(cutoff) +
                dao.deleteChargingSessionsOlderThan(cutoff)
            if (deleted > 0) {
                Log.i(TAG, "Retention sweep removed $deleted rows older than $RETENTION_DAYS days")
            }
            deleted
        } catch (t: Throwable) {
            // Retention is housekeeping: never let it break sampling or the UI.
            Log.w(TAG, "Retention sweep failed", t)
            -1
        }
    }
}
