import 'package:flutter/services.dart';

/// Pure Dart data layer that mirrors the native channel interface.
/// All methods return nullable values so the UI can distinguish "unavailable" from 0.
class PerfRepository {
  /// MethodChannel reference - initialized by the host app.
  static MethodChannel? _channel;

  /// Refresh by collecting a new sample then returning the latest stored sample.
  static Future<Map<String, dynamic>?> refreshAndGetLatest() async {
    await collectSampleNow();
    return getLatestSample();
  }

  /// Get the most recent stored sample, or null when nothing has been sampled yet.
  static Future<Map<String, dynamic>?> getLatestSample() async {
    if (_channel == null) return null;
    final result = await _channel!.invokeMethod<Map<String, dynamic>?>('getLatestSample');
    return result;
  }

  /// Returns samples with timestamp >= [sinceMillis], ordered OLDEST FIRST.
  static Future<List<Map<String, dynamic>>> getSamples({int sinceMillis = 0}) async {
    if (_channel == null) return [];
    final result = await _channel!.invokeListMethod('getSamples', sinceMillis);
    return result
            ?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
  }

  /// Returns capabilities from the native side in canonical metric order.
  static Future<List<Map<String, dynamic>>> getCapabilities() async {
    if (_channel == null) return [];
    final result = await _channel!.invokeListMethod('getCapabilities');
    return result
            ?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
  }

  /// Whether the user has enabled "Usage access" for this app.
  static Future<bool> isUsageAccessGranted() async {
    if (_channel == null) return false;
    final result = await _channel!.invokeMethod<bool>('isUsageAccessGranted');
    return result ?? false;
  }

  /// Opens the system Usage Access screen. Returns false when no screen could be opened.
  static Future<bool> openUsageAccessSettings() async {
    if (_channel == null) return false;
    final result = await _channel!.invokeMethod<bool>('openUsageAccessSettings');
    return result ?? false;
  }

  /// Collects and stores one sample right now; returns what was actually stored.
  static Future<Map<String, dynamic>?> collectSampleNow() async {
    if (_channel == null) return null;
    final result = await _channel!.invokeMethod<Map<String, dynamic>?>('collectSampleNow');
    return result;
  }

  /// Sets the [MethodChannel] to use for native communication.
  /// Called from the Dart host (e.g. MainScreen) after the channel is registered.
  static void setChannel(MethodChannel channel) {
    _channel = channel;
  }
}