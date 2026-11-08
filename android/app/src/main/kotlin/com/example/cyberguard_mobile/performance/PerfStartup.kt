package com.example.cyberguard_mobile.performance

import android.content.Context
import android.util.Log
import com.example.cyberguard_mobile.performance.capability.SensorAvailabilityChecker
import com.example.cyberguard_mobile.performance.data.PerfRetention
import com.example.cyberguard_mobile.performance.sampling.PerfSampleWorker
import com.example.cyberguard_mobile.performance.sampling.PerfSampler
import java.util.concurrent.Executors

/**
 * Everything the module needs to do when the app opens, off the main thread:
 *
 *  1. schedule the 15-minute periodic sample (idempotent - unique work, policy KEEP),
 *  2. record device information once (first install / first app open),
 *  3. re-run the capability probe and store the result,
 *  4. collect one sample for this app open,
 *  5. run the 30-day retention sweep.
 *
 * Each step is isolated: a failure in one (a blocked thermal API, a full disk) must never stop
 * the others or crash the app.
 */
object PerfStartup {

    private const val TAG = "PerfStartup"

    /**
     * One background thread keeps the startup steps ordered, so two capability probes can never
     * race on the same rows. The thread is a daemon: it must not keep the process alive.
     */
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "perf-startup").apply { isDaemon = true }
    }

    /** Called once per Flutter engine creation (i.e. every app open). Never blocks the caller. */
    fun initialize(context: Context) {
        val appContext = context.applicationContext
        executor.execute {
            step("schedule periodic sampling") { PerfSampleWorker.schedule(appContext) }
            step("record device info") { PerfSampler.ensureDeviceInfo(appContext) }
            step("probe capabilities") { SensorAvailabilityChecker.runAll(appContext) }
            step("collect startup sample") { PerfSampler.collectSample(appContext) }
            step("retention sweep") { PerfRetention.prune(appContext) }
        }
    }

    private fun step(name: String, block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            Log.w(TAG, "Startup step failed: $name", t)
        }
    }
}
