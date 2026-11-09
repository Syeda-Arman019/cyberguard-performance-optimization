library performance_optimization;

/// Pure Dart types for performance data.
/// These mirror the native channel payload shapes but keep null as null.

/// One point-in-time measurement of device health.
class PerfSample {
  final int? id;
  final int? timestamp;
  final double? batteryPct;
  final double? batteryTempC;
  final String? chargingState;
  final String? pluggedType;
  final double? batteryCurrentUa;
  final int? thermalStatus;
  final bool? screenInteractive;
  final int? memTotalMb;
  final int? memAvailMb;
  final bool? lowMemory;
  final int? storageFreeBytes;
  final int? storageTotalBytes;

  PerfSample.fromMap(Map<String, dynamic>? map)
      : id = map?['id'],
        timestamp = map?['timestamp'],
        batteryPct = map?['batteryPct'],
        batteryTempC = map?['batteryTempC'],
        chargingState = map?['chargingState'],
        pluggedType = map?['pluggedType'],
        batteryCurrentUa = map?['batteryCurrentUa'],
        thermalStatus = map?['thermalStatus'],
        screenInteractive = map?['screenInteractive'],
        memTotalMb = map?['memTotalMb'],
        memAvailMb = map?['memAvailMb'],
        lowMemory = map?['lowMemory'],
        storageFreeBytes = map?['storageFreeBytes'],
        storageTotalBytes = map?['storageTotalBytes'];
}

/// Result of the startup capability probe for one metric.
class PerfCapability {
  final String metricName;
  final String state;
  final String? reason;
  final int checkedAt;

  PerfCapability.fromMap(Map<String, dynamic>? map)
      : metricName = map?['metricName'] ?? '',
        state = map?['state'] ?? '',
        reason = map?['reason'],
        checkedAt = map?['checkedAt'] ?? 0;
}

/// Static-ish device information, captured once (first install / first app open).
class PerfDeviceInfo {
  final int? totalRamMb;
  final int? batteryCapacityMah;
  final String deviceModel;
  final int androidSdk;
  final int? recordedAt;

  PerfDeviceInfo.fromMap(Map<String, dynamic>? map)
      : totalRamMb = map?['totalRamMb'],
        batteryCapacityMah = map?['batteryCapacityMah'],
        deviceModel = map?['deviceModel'] ?? '',
        androidSdk = map?['androidSdk'] ?? 0,
        recordedAt = map?['recordedAt'];
}