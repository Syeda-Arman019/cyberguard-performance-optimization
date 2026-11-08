package com.example.cyberguard_mobile.performance.sampling

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.example.cyberguard_mobile.performance.data.PerfRetention
import java.util.concurrent.TimeUnit

/**
 * Periodic background sampler.
 *
 * - Periodic work only (15 minutes, the platform minimum). No foreground service, no
 *   battery-optimisation exemption request: if the system delays or skips a run, the next
 *   sample simply carries its own real timestamp, so the data never lies about timing.
 * - The unique work name "performance_sample" keeps exactly one schedule alive no matter how
 *   often the app opens.
 * - WorkManager runs this on a background dispatcher, which is why the blocking DAO calls in
 *   [PerfSampler] and [PerfRetention] are safe here.
 */
class PerfSampleWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            PerfSampler.collectSample(applicationContext)
            // Housekeeping: bounded, cheap and never allowed to fail the sample.
            PerfRetention.prune(applicationContext)
            Result.success()
        } catch (t: Throwable) {
            // Periodic work has no user waiting on it; the next run is 15 minutes away.
            // Retrying immediately would only burn battery.
            Log.w(TAG, "Periodic sample failed; waiting for the next run", t)
            Result.success()
        }
    }

    companion object {
        private const val TAG = "PerfSampleWorker"

        /** Unique work name; also the name used to inspect/cancel the schedule. */
        const val UNIQUE_WORK_NAME: String = "performance_sample"

        /** The platform minimum for periodic work. */
        private const val INTERVAL_MINUTES: Long = 15L

        /**
         * Schedules the 15-minute periodic sample.
         *
         * ExistingPeriodicWorkPolicy.KEEP means an already scheduled job (and its interval /
         * timestamps) is preserved, so calling this on every app start is harmless.
         */
        fun schedule(context: Context) {
            try {
                val request = PeriodicWorkRequestBuilder<PerfSampleWorker>(
                    INTERVAL_MINUTES,
                    TimeUnit.MINUTES,
                ).build()

                WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
                    UNIQUE_WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request,
                )
            } catch (t: Throwable) {
                // WorkManager can be unavailable in restricted environments; sampling on app
                // open still works, so this is logged rather than crashing the app.
                Log.w(TAG, "Could not schedule periodic sampling", t)
            }
        }
    }
}
