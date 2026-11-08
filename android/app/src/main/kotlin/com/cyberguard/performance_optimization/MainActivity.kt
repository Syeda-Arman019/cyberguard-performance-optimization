package com.cyberguard.performance_optimization

import com.example.cyberguard_mobile.performance.registerPerformanceChannels
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // >>> CyberGuard performance module: the ONLY integration point. <<<
        // Everything else (channels, database, sampling, capability checks) lives inside the
        // com.example.cyberguard_mobile.performance package. When this module is merged into the
        // main app, copy this one line into the main app's FlutterActivity / FlutterFragment.
        registerPerformanceChannels(flutterEngine, applicationContext)
        // >>> end CyberGuard performance module <<<
    }
}
