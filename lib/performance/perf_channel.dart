import 'package:flutter/foundation.dart';
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
    debugPrint('[PERF_TRACE] PerfChannel.getLatestSample: invoking');
    try {
      final result = await _invokeMapMethod('getLatestSample');
      debugPrint('[PERF_TRACE] PerfChannel.getLatestSample: resultType=${result.runtimeType}');
      return result;
    } catch (error, stackTrace) {
      debugPrint('[PERF_TRACE] PerfChannel.getLatestSample: FAILED: $error');
      debugPrint('[PERF_TRACE] PerfChannel.getLatestSample: stack trace:\n$stackTrace');
      rethrow;
    }
  }

  /// Samples with an actual timestamp >= [sinceMillis], ascending by time.
  static Future<List<Map<String, dynamic>>> getSamples({int sinceMillis = 0}) async {
    debugPrint(
      '[PERF_TRACE] PerfChannel.getSamples: invoking sinceMillis=$sinceMillis '
      '(${sinceMillis.runtimeType})',
    );
    try {
      final list = await _channel.invokeListMethod<dynamic>(
        'getSamples',
        sinceMillis,
      );
      final samples = _asMapList(list);
      debugPrint(
        '[PERF_TRACE] PerfChannel.getSamples: rawType=${list.runtimeType}, '
        'rawCount=${list?.length}, parsedCount=${samples.length}',
      );
      if (samples.isNotEmpty) {
        debugPrint(
          '[PERF_TRACE] PerfChannel.getSamples: first row field types='
          '${samples.first.map((key, value) => MapEntry(key, value.runtimeType))}',
        );
      }
      return samples;
    } catch (error, stackTrace) {
      debugPrint('[PERF_TRACE] PerfChannel.getSamples: FAILED: $error');
      debugPrint('[PERF_TRACE] PerfChannel.getSamples: stack trace:\n$stackTrace');
      rethrow;
    }
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
    debugPrint('[PERF_TRACE] PerfChannel.collectSampleNow: invoking');
    try {
      final result = await _invokeMapMethod('collectSampleNow');
      debugPrint('[PERF_TRACE] PerfChannel.collectSampleNow: resultType=${result.runtimeType}');
      return result;
    } catch (error, stackTrace) {
      debugPrint('[PERF_TRACE] PerfChannel.collectSampleNow: FAILED: $error');
      debugPrint('[PERF_TRACE] PerfChannel.collectSampleNow: stack trace:\n$stackTrace');
      rethrow;
    }
  }

  /// Writes every stored sample to a CSV file and returns its absolute path, or null.
  static Future<String?> exportSamplesCsv() {
    return _channel.invokeMethod<String>('exportSamplesCsv');
  }

  /// Device information captured on first run, or null if it has not been recorded yet.
  static Future<Map<String, dynamic>?> getDeviceInfo() async {
    return _invokeMapMethod('getDeviceInfo');
  }

  /// Deletes every row this module owns (debug / "clear all data").
  static Future<bool> clearAllData() async {
    final cleared = await _channel.invokeMethod<bool>('clearAllData');
    return cleared ?? false;
  }

  /// Returns the live raw battery values from the sticky ACTION_BATTERY_CHANGED broadcast.
  /// Every missing extra arrives as null; never as 0, per the honesty rules.
  static Future<Map<String, dynamic>?> getLiveBatteryRaw() async {
    return _invokeMapMethod('getLiveBatteryRaw');
  }

  static Future<Map<String, dynamic>?> _invokeMapMethod(String method) async {
    final raw = await _channel.invokeMethod<Object?>(method);
    if (raw == null) return null;
    if (raw is! Map) {
      throw FormatException('Expected a map response from $method, got ${raw.runtimeType}');
    }
    return Map<String, dynamic>.from(raw);
  }

  static List<Map<String, dynamic>> _asMapList(List<dynamic>? raw) {
    if (raw == null) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
}