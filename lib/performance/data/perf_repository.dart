import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pure Dart data layer that mirrors the native channel interface.
/// All methods return nullable values so the UI can distinguish "unavailable" from 0.
class PerfRepository {
  /// MethodChannel reference - initialized by the host app.
  static MethodChannel? _channel;

  /// Whether the repository channel has been initialized from the host app.
  /// [PERF_TRACE] Debug flag to verify setChannel() was called before runApp().
  static bool _initialized = false;

  /// Whether the repository channel has been initialized from the host app.
  /// [PERF_TRACE] Debug flag to verify setChannel() was called before runApp().
  static bool get initialized => _initialized;

  /// Refresh by collecting a new sample then returning the latest stored sample.
  static Future<Map<String, dynamic>?> refreshAndGetLatest() async {
    debugPrint('[PERF_TRACE] repository.refreshAndGetLatest: start');
    try {
      debugPrint('[PERF_TRACE] repository.refreshAndGetLatest: collecting sample');
      final collected = await collectSampleNow();
      debugPrint(
        '[PERF_TRACE] repository.refreshAndGetLatest: collect complete; '
        'sample is ${collected == null ? 'null' : 'present'}',
      );
      final latest = await getLatestSample();
      debugPrint(
        '[PERF_TRACE] repository.refreshAndGetLatest: latest sample is '
        '${latest == null ? 'null' : 'present'}',
      );
      return latest;
    } catch (error, stackTrace) {
      debugPrint('[PERF_TRACE] repository.refreshAndGetLatest: FAILED: $error');
      debugPrint('[PERF_TRACE] repository.refreshAndGetLatest: stack trace:\n$stackTrace');
      rethrow;
    }
  }

  /// Get the most recent stored sample, or null when nothing has been sampled yet.
  static Future<Map<String, dynamic>?> getLatestSample() async {
    debugPrint('[PERF_TRACE] repository.getLatestSample: channelInitialized=${_channel != null}');
    if (_channel == null) return null;
    try {
      final rawResult = await _channel!.invokeMethod<Object?>('getLatestSample');
      final result = _asStringKeyedMap(rawResult);
      debugPrint(
        '[PERF_TRACE] repository.getLatestSample: resultType=${result.runtimeType}, '
        'timestamp=${result?['timestamp']}',
      );
      return result;
    } catch (error, stackTrace) {
      debugPrint('[PERF_TRACE] repository.getLatestSample: FAILED: $error');
      debugPrint('[PERF_TRACE] repository.getLatestSample: stack trace:\n$stackTrace');
      rethrow;
    }
  }

  /// Returns samples with timestamp >= [sinceMillis], ordered OLDEST FIRST.
  static Future<List<Map<String, dynamic>>> getSamples({int sinceMillis = 0}) async {
    debugPrint(
      '[PERF_TRACE] repository.getSamples: start; sinceMillis=$sinceMillis '
      '(${sinceMillis.runtimeType}), channelInitialized=${_channel != null}',
    );
    if (_channel == null) {
      debugPrint('[PERF_TRACE] repository.getSamples: ERROR: no MethodChannel; returning []');
      return [];
    }
    try {
      final result = await _channel!.invokeListMethod<dynamic>('getSamples', sinceMillis);
      debugPrint(
        '[PERF_TRACE] repository.getSamples: native resultType=${result.runtimeType}, '
        'count=${result?.length}',
      );
      if (result == null) {
        debugPrint('[PERF_TRACE] repository.getSamples: native result is null');
        return [];
      }

      final parsed = <Map<String, dynamic>>[];
      for (var i = 0; i < result.length; i++) {
        try {
          final map = Map<String, dynamic>.from(result[i] as Map);
          parsed.add(map);
          if (i == 0) {
            debugPrint(
              '[PERF_TRACE] repository.getSamples: first row field types='
              '${map.map((key, value) => MapEntry(key, value.runtimeType))}',
            );
          }
        } catch (error, stackTrace) {
          debugPrint('[PERF_TRACE] repository.getSamples: parse FAILED at index $i: $error');
          debugPrint('[PERF_TRACE] repository.getSamples: parse stack trace:\n$stackTrace');
          rethrow;
        }
      }
      if (parsed.isNotEmpty) {
        debugPrint(
          '[PERF_TRACE] repository.getSamples: parsed ${parsed.length}/${result.length}; '
          'first timestamp=${parsed.first['timestamp']} (${parsed.first['timestamp'].runtimeType}), '
          'last timestamp=${parsed.last['timestamp']} (${parsed.last['timestamp'].runtimeType})',
        );
      } else {
        debugPrint('[PERF_TRACE] repository.getSamples: parsed 0/${result.length} rows');
      }
      return parsed;
    } catch (error, stackTrace) {
      debugPrint('[PERF_TRACE] repository.getSamples: FAILED: $error');
      debugPrint('[PERF_TRACE] repository.getSamples: stack trace:\n$stackTrace');
      rethrow;
    }
  }

  /// Returns capabilities from the native side in canonical metric order.
  static Future<List<Map<String, dynamic>>> getCapabilities() async {
    debugPrint('[PERF_TRACE] repository.getCapabilities: channelInitialized=${_channel != null}');
    if (_channel == null) return [];
    try {
      final result = await _channel!.invokeListMethod<dynamic>('getCapabilities');
      final parsed = result
            ?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList() ?? [];
      debugPrint('[PERF_TRACE] repository.getCapabilities: received ${parsed.length}');
      return parsed;
    } catch (error, stackTrace) {
      debugPrint('[PERF_TRACE] repository.getCapabilities: FAILED: $error');
      debugPrint('[PERF_TRACE] repository.getCapabilities: stack trace:\n$stackTrace');
      rethrow;
    }
  }

  /// Whether the user has enabled "Usage access" for this app.
  static Future<bool> isUsageAccessGranted() async {
    debugPrint('[PERF_TRACE] repository.isUsageAccessGranted: channelInitialized=${_channel != null}');
    if (_channel == null) return false;
    try {
      final result = await _channel!.invokeMethod<bool>('isUsageAccessGranted');
      debugPrint('[PERF_TRACE] repository.isUsageAccessGranted: result=$result');
      return result ?? false;
    } catch (error, stackTrace) {
      debugPrint('[PERF_TRACE] repository.isUsageAccessGranted: FAILED: $error');
      debugPrint('[PERF_TRACE] repository.isUsageAccessGranted: stack trace:\n$stackTrace');
      rethrow;
    }
  }

  /// Opens the system Usage Access screen. Returns false when no screen could be opened.
  static Future<bool> openUsageAccessSettings() async {
    if (_channel == null) return false;
    final result = await _channel!.invokeMethod<bool>('openUsageAccessSettings');
    return result ?? false;
  }

  /// Collects and stores one sample right now; returns what was actually stored.
  static Future<Map<String, dynamic>?> collectSampleNow() async {
    debugPrint('[PERF_TRACE] repository.collectSampleNow: channelInitialized=${_channel != null}');
    if (_channel == null) return null;
    try {
      final rawResult = await _channel!.invokeMethod<Object?>('collectSampleNow');
      final result = _asStringKeyedMap(rawResult);
      debugPrint('[PERF_TRACE] repository.collectSampleNow: resultType=${result.runtimeType}');
      return result;
    } catch (error, stackTrace) {
      debugPrint('[PERF_TRACE] repository.collectSampleNow: FAILED: $error');
      debugPrint('[PERF_TRACE] repository.collectSampleNow: stack trace:\n$stackTrace');
      rethrow;
    }
  }

  static Map<String, dynamic>? _asStringKeyedMap(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw FormatException('Expected a map response, got ${value.runtimeType}');
    }
    return Map<String, dynamic>.from(value);
  }

  /// Sets the [MethodChannel] to use for native communication.
  /// Called from the Dart host (e.g. MainScreen) after the channel is registered.
  static void setChannel(MethodChannel channel) {
    _channel = channel;
    _initialized = true;
    debugPrint('[PERF_TRACE] repository.setChannel: initialized channel=${channel.name}');
  }
}