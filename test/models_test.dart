import 'package:flutter_test/flutter_test.dart';
import 'package:performance_optimization/performance/data/perf_models.dart';

void main() {
  group('PerfSample.fromMap', () {
    test('keeps missing keys as null', () {
      final map = <String, dynamic>{};
      final sample = PerfSample.fromMap(map);

      expect(sample.batteryPct, isNull);
      expect(sample.batteryTempC, isNull);
      expect(sample.chargingState, isNull);
      expect(sample.pluggedType, isNull);
      expect(sample.batteryCurrentUa, isNull);
      expect(sample.memTotalMb, isNull);
      expect(sample.memAvailMb, isNull);
      expect(sample.storageFreeBytes, isNull);
      expect(sample.storageTotalBytes, isNull);
    });

    test('reads present values', () {
      final map = <String, dynamic>{
        'batteryPct': 85.0,
        'batteryTempC': 30.5,
        'chargingState': 'charging',
        'pluggedType': 'ac',
        'batteryCurrentUa': 500.0,
        'memTotalMb': 4096,
        'memAvailMb': 2048,
        'storageFreeBytes': 1073741824,
        'storageTotalBytes': 2147483648,
      };
      final sample = PerfSample.fromMap(map);

      expect(sample.batteryPct, equals(85.0));
      expect(sample.batteryTempC, equals(30.5));
      expect(sample.chargingState, equals('charging'));
      expect(sample.pluggedType, equals('ac'));
      expect(sample.batteryCurrentUa, equals(500.0));
      expect(sample.memTotalMb, equals(4096));
      expect(sample.memAvailMb, equals(2048));
      expect(sample.storageFreeBytes, equals(1073741824));
      expect(sample.storageTotalBytes, equals(2147483648));
    });
  });

  group('PerfCapability.fromMap', () {
    test('reads all fields from map', () {
      final map = <String, dynamic>{
        'metricName': 'battery_level',
        'state': 'AVAILABLE',
        'reason': 'All good',
        'checkedAt': 1234567890,
      };
      final cap = PerfCapability.fromMap(map);

      expect(cap.metricName, equals('battery_level'));
      expect(cap.state, equals('AVAILABLE'));
      expect(cap.reason, equals('All good'));
      expect(cap.checkedAt, equals(1234567890));
    });

    test('uses defaults when map is null', () {
      final cap = PerfCapability.fromMap(null);
      // Non-nullable String fields default to empty string when map is null
      expect(cap.metricName, isEmpty);
      expect(cap.state, isEmpty);
      // Nullable fields are null when map is null
      expect(cap.reason, isNull);
      // int defaults to 0 when map is null
      expect(cap.checkedAt, equals(0));
    });
  });

  group('PerfDeviceInfo.fromMap', () {
    test('reads all fields from map', () {
      final map = <String, dynamic>{
        'totalRamMb': 8192,
        'batteryCapacityMah': 4000,
        'deviceModel': 'Pixel 7',
        'androidSdk': 33,
        'recordedAt': 1234567890,
      };
      final info = PerfDeviceInfo.fromMap(map);

      expect(info.totalRamMb, equals(8192));
      expect(info.batteryCapacityMah, equals(4000));
      expect(info.deviceModel, equals('Pixel 7'));
      expect(info.androidSdk, equals(33));
      expect(info.recordedAt, equals(1234567890));
    });

    test('uses defaults when map is null', () {
      final info = PerfDeviceInfo.fromMap(null);
      // Nullable fields are null when map is null
      expect(info.totalRamMb, isNull);
      expect(info.batteryCapacityMah, isNull);
      // Non-nullable String defaults to empty string when map is null
      expect(info.deviceModel, isEmpty);
      // int defaults to 0 when map is null
      expect(info.androidSdk, equals(0));
      // Nullable int is null when map is null
      expect(info.recordedAt, isNull);
    });
  });
}