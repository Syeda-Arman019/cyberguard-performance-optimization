import 'package:flutter/services.dart';

/// Thin wrapper around the native channel `cyberguard/performance`.
///
/// Deliberately dumb: it only forwards calls and returns the raw payloads the Kotlin side
/// sends. Every value that could not be measured arrives as null - never as 0 - so the
/// UI layer decides how to word "Unavailable".
///

/// Shapes returned by the native side:
///  capabilities: [{metricName, state, reason, checkedAt}]
///  sample:       {id, timestamp, batteryPct, batteryTempC, chargingState, pluggedType,
///                batteryCurrentUa, thermalStatus, screenInteractive, memTotalMb,
///                memAvailMb, lowMemory, storageFreeBytes, storageTotalBytes}
///  deviceInfo:   {totalRamMb, batteryCapacityMah, deviceModel, androidSdk, recordedAt}
class PerfChannel {
  PerfChannel._();

  /// Channel name; must match [PERF_CHANNEL_NAME] in PerformanceChannels.kt.
  static const MethodChannel _channel = MethodChannel('cyberguard/performance');

  /// One entry per metric the startup probe checked, in the canonical metric order.
  static Future<List<Map<String, dynamic>>> getCapabilities() async {
    final list = await _channel.invokeListMethod<dynamic>('getCapabilities');
    return _asMapList(list);
  }

  /// The most recent stored sample, or null when nothing has been sampled yet.
  static Future<Map<String, dynamic>?> getLatestSample() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('getLatestSample');
    return result;
  }

  /// Samples with an actual timestamp >= [sinceMillis], ascending by time.
  static Future<List<Map<String, dynamic>>> getSamples({int sinceMillis = 0}) async {
    final list = await _channel.invokeListMethod<dynamic>(
      'getSamples',
      sinceMillis,
    );
    return _asMapList(list);
  }

  /// Whether the user has enabled "Usage access" for this app.
  static Future<bool> isUsageAccessGranted() async {
    final granted = await _channel.invokeMethod<bool>('isUsageAccessGranted');
    return granted ?? false;
  }

  /// Opens the system Usage Access screen. Returns false when no screen could be opened.
  static Future<bool> openUsageAccessSettings() async {
    final opened = await _channel.invokeMethod<bool>('openUsageAccessSettings');
    return opened ?? false;
  }

  /// Collects and stores one sample right now; returns what was actually stored.
  static Future<Map<String, dynamic>?> collectSampleNow() async {
    return _channel.invokeMapMethod<String, dynamic>('collectSampleNow');
  }

  /// Writes every stored sample to a CSV file and returns its absolute path, or null.
  static Future<String?> exportSamplesCsv() {
    return _channel.invokeMethod<String>('exportSamplesCsv');
  }

  /// Device information captured on first run, or null if it has not been recorded yet.
  static Future<Map<String, dynamic>?> getDeviceInfo() async {
    return _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
  }

  /// Deletes every row this module owns (debug / "clear all data").
  static Future<bool> clearAllData() async {
    final cleared = await _channel.invokeMethod<bool>('clearAllData');
    return cleared ?? false;
  }

  /// Returns the live raw battery values from the sticky ACTION_BATTERY_CHANGED broadcast.
  /// Every missing extra arrives as null; never as 0, per the honesty rules.
  static Future<Map<String, dynamic>?> getLiveBatteryRaw() async {
    return _channel.invokeMapMethod<String, dynamic>('getLiveBatteryRaw');
  }

  static List<Map<String, dynamic>> _asMapList(List<dynamic>? raw) {
    if (raw == null) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
}