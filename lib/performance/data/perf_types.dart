library perf_types;

export 'perf_sample.dart' show PerfSample;

typedef PerfSample = performance_optimization.PerfSample;

class PerfChargingState {
  static const String charging = 'charging';
  static const String discharging = 'discharging';
  static const String full = 'full';
  static const String notCharging = 'not_charging';
  static const String unknown = 'unknown';
}

class PerfPluggedType {
  static const String none = 'none';
  static const String ac = 'ac';
  static const String usb = 'usb';
  static const String wireless = 'wireless';
  static const String dock = 'dock';
  static const String unknown = 'unknown';
}


class PerfCapabilityState {
  static const String available = 'AVAILABLE';
  static const String unavailable = 'UNAVAILABLE';
  static const String unreliable = 'UNRELIABLE';
  static const String permissionNeeded = 'PERMISSION_NEEDED';
}

class PerfMetric {
  static const String batteryLevel = 'battery_level';
  static const String batteryTemperature = 'battery_temperature';
  static const String batteryCurrent = 'battery_current_now';
  static const String thermalStatus = 'thermal_status';
  static const String memoryInfo = 'memory_info';
  static const String storageStats = 'storage_stats';
  static const String screenState = 'screen_state';
  static const String perAppStorage = 'per_app_storage_stats';
  static const String perAppNetwork = 'per_app_network_stats';
  static const String usageEvents = 'usage_events';
  static const String usageAccess = 'usage_access';
}
