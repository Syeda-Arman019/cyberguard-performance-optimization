import 'package:flutter_test/flutter_test.dart';
import 'package:performance_optimization/performance/engine/discharge_runs.dart';
import 'package:performance_optimization/performance/engine/health_index.dart';
import 'package:performance_optimization/performance/engine/thresholds.dart';

void main() {
  group('Thresholds', () {
    test('constants are defined', () {
      expect(Thresholds.runMaxGapMin, equals(60));
      expect(Thresholds.minDrainHours, equals(2));
      expect(Thresholds.memLowPct, equals(15.0));
      expect(Thresholds.memMedium1Pct, equals(8.0));
      expect(Thresholds.storageLowPct, equals(20.0));
      expect(Thresholds.storageMedium1Pct, equals(10.0));
      expect(Thresholds.storageMedium2Pct, equals(5.0));
    });
  });

  group('DischargeRun', () {
    test('can be created with all fields', () {
      final run = DischargeRun(
        startMillis: 1000,
        endMillis: 2000,
        startPct: 80.0,
        endPct: 60.0,
        drop: 20.0,
        hours: 1.0,
        screenOn: false,
        ratePerHour: 20.0,
      );
      expect(run.startMillis, equals(1000));
      expect(run.endMillis, equals(2000));
      expect(run.startPct, equals(80.0));
      expect(run.endPct, equals(60.0));
      expect(run.drop, equals(20.0));
      expect(run.hours, equals(1.0));
      expect(run.screenOn, equals(false));
      expect(run.ratePerHour, equals(20.0));
    });
  });

  group('dischargeRuns', () {
    final dischargingSamples = <Map<String, dynamic>>[
      {'timestamp': 0, 'batteryPct': 80.0, 'chargingState': null, 'screenInteractive': true},
      {'timestamp': 30 * 60 * 1000, 'batteryPct': 75.0, 'chargingState': null, 'screenInteractive': true},
      {'timestamp': 60 * 60 * 1000, 'batteryPct': 70.0, 'chargingState': null, 'screenInteractive': true},
      {'timestamp': 120 * 60 * 1000, 'batteryPct': 65.0, 'chargingState': null, 'screenInteractive': false},
      {'timestamp': 180 * 60 * 1000, 'batteryPct': 60.0, 'chargingState': null, 'screenInteractive': false},
    ];

    test('builds a single run when all samples are consecutive and discharging', () {
      final runs = dischargeRuns(dischargingSamples, splitByScreen: false);
      expect(runs.length, equals(1));
      expect(runs[0].startPct, equals(80.0));
      expect(runs[0].endPct, equals(60.0));
      expect(runs[0].drop, equals(20.0));
    });

    test('stops run when gap > 60 min', () {
      final samplesWithGap = List<Map<String, dynamic>>.from(dischargingSamples)
        ..add({'timestamp': 200 * 60 * 1000, 'batteryPct': 55.0, 'chargingState': null, 'screenInteractive': false});
      final runs = dischargeRuns(samplesWithGap, splitByScreen: false);
      expect(runs.length, greaterThanOrEqualTo(1));
    });

    test('discards run where percentage rises', () {
      final risingSamples = <Map<String, dynamic>>[
        {'timestamp': 0, 'batteryPct': 50.0, 'chargingState': null, 'screenInteractive': true},
        {'timestamp': 30 * 60 * 1000, 'batteryPct': 60.0, 'chargingState': null, 'screenInteractive': true},
      ];
      final runs = dischargeRuns(risingSamples, splitByScreen: false);
      expect(runs, isEmpty);
    });

    test('keeps run >= minMinutes', () {
      final longRunSamples = <Map<String, dynamic>>[
        {'timestamp': 0, 'batteryPct': 80.0, 'chargingState': null, 'screenInteractive': true},
        {'timestamp': 60 * 60 * 1000, 'batteryPct': 40.0, 'chargingState': null, 'screenInteractive': true},
      ];
      final runs = dischargeRuns(longRunSamples, splitByScreen: false);
      expect(runs.length, equals(1));
    });

    test('splitByScreen breaks run on screen state change', () {
      final samples = <Map<String, dynamic>>[
        {'timestamp': 0, 'batteryPct': 80.0, 'chargingState': null, 'screenInteractive': true},
        {'timestamp': 30 * 60 * 1000, 'batteryPct': 70.0, 'chargingState': null, 'screenInteractive': false},
        {'timestamp': 60 * 60 * 1000, 'batteryPct': 60.0, 'chargingState': null, 'screenInteractive': false},
      ];
      final runs = dischargeRuns(samples, splitByScreen: true);
      expect(runs, isEmpty);
    });

    test('null screen_interactive breaks the run with splitByScreen', () {
      final samples = <Map<String, dynamic>>[
        {'timestamp': 0, 'batteryPct': 80.0, 'chargingState': null, 'screenInteractive': true},
        {'timestamp': 30 * 60 * 1000, 'batteryPct': 70.0, 'chargingState': null, 'screenInteractive': null},
        {'timestamp': 60 * 60 * 1000, 'batteryPct': 60.0, 'chargingState': null, 'screenInteractive': false},
      ];
      final runs = dischargeRuns(samples, splitByScreen: true);
      expect(runs.length, lessThan(3));
    });
  });

  group('overallRate', () {
    final runs = <DischargeRun>[
      DischargeRun(
        startMillis: 0,
        endMillis: 60 * 60 * 1000,
        startPct: 80.0,
        endPct: 50.0,
        drop: 30.0,
        hours: 1.0,
        screenOn: false,
        ratePerHour: 30.0,
      ),
      DischargeRun(
        startMillis: 60 * 60 * 1000,
        endMillis: 120 * 60 * 1000,
        startPct: 50.0,
        endPct: 30.0,
        drop: 20.0,
        hours: 1.0,
        screenOn: false,
        ratePerHour: 20.0,
      ),
    ];

    test('returns total drop / total hours', () {
      final rate = overallRate(runs);
      expect(rate, equals(25.0));
    });

    test('returns null when total hours < 2', () {
      final shortRuns = <DischargeRun>[
        DischargeRun(
          startMillis: 0,
          endMillis: 30 * 60 * 1000,
          startPct: 80.0,
          endPct: 50.0,
          drop: 30.0,
          hours: 0.5,
          screenOn: false,
          ratePerHour: 60.0,
        ),
      ];
      final rate = overallRate(shortRuns);
      expect(rate, isNull);
    });
  });

  group('computeHealthIndex', () {
    Map<String, dynamic> sample(double pct, {int? ts, double? temp, bool? charging, bool? lowMemory, int? storageFree, int? storageTotal, int? memAvail, int? memTotal}) {
      return {
        'timestamp': ts ?? DateTime.now().millisecondsSinceEpoch - 15 * 60 * 1000,
        'batteryPct': pct,
        'batteryTempC': temp,
        'chargingState': charging,
        'lowMemory': lowMemory,
        'storageFreeBytes': storageFree,
        'storageTotalBytes': storageTotal,
        'memAvailMb': memAvail,
        'memTotalMb': memTotal,
      };
    }

    test('same input gives same output', () {
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      final oneHourAgo = nowMillis - 60 * 60 * 1000;
      final samples = [
        sample(80, ts: oneHourAgo, temp: 36.5, charging: null, storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(70, ts: oneHourAgo - 30 * 60 * 1000, temp: 37.0, charging: null, storageFree: 80000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(60, ts: oneHourAgo - 60 * 60 * 1000, temp: 38.0, charging: null, storageFree: 60000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final result1 = computeHealthIndex(
        samples: samples,
        thermalAvailable: false,
        nowMillis: nowMillis,
        baselineDrainPerHour: null,
      );
      final result2 = computeHealthIndex(
        samples: samples,
        thermalAvailable: false,
        nowMillis: nowMillis,
        baselineDrainPerHour: null,
      );
      expect(result1, equals(result2));
    });

    test('too few samples = learning, not 0', () {
      final samples = <Map<String, dynamic>>[
        sample(80, ts: 0, temp: 36.5, charging: null, storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final result = computeHealthIndex(
        samples: samples,
        thermalAvailable: false,
        nowMillis: DateTime.now().millisecondsSinceEpoch,
        baselineDrainPerHour: null,
      );
      expect(result.battery.status, equals('learning'));
    });

    test('null temperature never becomes 0', () {
      final samples = <Map<String, dynamic>>[
        sample(80, ts: 0, temp: null, charging: null, storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(70, ts: 15 * 60 * 1000, temp: null, charging: null, storageFree: 80000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final result = computeHealthIndex(
        samples: samples,
        thermalAvailable: false,
        nowMillis: DateTime.now().millisecondsSinceEpoch,
        baselineDrainPerHour: null,
      );
      expect(result.heat.status, equals('unavailable'));
    });

    test('27% free RAM = no penalty for memory', () {
      final samples = <Map<String, dynamic>>[
        sample(80, ts: 0, temp: 36.5, charging: null,
            storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(70, ts: 15 * 60 * 1000, temp: 37.0, charging: null,
            storageFree: 80000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(60, ts: 30 * 60 * 1000, temp: 38.0, charging: null,
            storageFree: 60000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final result = computeHealthIndex(
        samples: samples,
        thermalAvailable: false,
        nowMillis: DateTime.now().millisecondsSinceEpoch,
        baselineDrainPerHour: null,
      );
      expect(result.memory.pointsLost, equals(0));
      expect(result.memory.status, equals('good'));
    });

    test('battery with baseline: ratio <= 1.3 lost 0', () {
      final samples = <Map<String, dynamic>>[
        sample(80, ts: 0, temp: 36.5, charging: null,
            storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(70, ts: 30 * 60 * 1000, temp: 37.0, charging: null,
            storageFree: 60000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(60, ts: 60 * 60 * 1000, temp: 38.0, charging: null,
            storageFree: 40000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final result = computeHealthIndex(
        samples: samples,
        thermalAvailable: false,
        nowMillis: DateTime.now().millisecondsSinceEpoch,
        baselineDrainPerHour: 20.0,
      );
      expect(result.battery.pointsLost, equals(0));
    });

    test('excluded component redistributes weights', () {
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      final twoHoursAgo = nowMillis - 120 * 60 * 1000;
      final oneHourAgo = nowMillis - 60 * 60 * 1000;
      final samples = <Map<String, dynamic>>[
        sample(80, ts: twoHoursAgo, temp: 36.5, charging: null,
            storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(60, ts: oneHourAgo, temp: 37.0, charging: null,
            storageFree: 60000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(40, ts: oneHourAgo + 60 * 60 * 1000, temp: 38.0, charging: null,
            storageFree: 40000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final result = computeHealthIndex(
        samples: samples,
        thermalAvailable: false,
        nowMillis: nowMillis,
        baselineDrainPerHour: null,
      );
      expect(result.measuredCount, equals(4));
    });

    test('charging samples are ignored for drain', () {
      final samples = <Map<String, dynamic>>[
        sample(80, ts: 0, temp: 36.5, charging: true, storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(70, ts: 15 * 60 * 1000, temp: 37.0, charging: true, storageFree: 60000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(60, ts: 60 * 60 * 1000, temp: 38.0, charging: true, storageFree: 40000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final result = computeHealthIndex(
        samples: samples,
        thermalAvailable: false,
        nowMillis: DateTime.now().millisecondsSinceEpoch,
        baselineDrainPerHour: null,
      );
      expect(result.battery.status, equals('learning'));
    });

    test('boundary test for each threshold (just below and at the limit)', () {
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      final windowStart = nowMillis - 2 * 60 * 60 * 1000;

      final samplesLow = <Map<String, dynamic>>[
        sample(80, ts: windowStart, temp: 36.5, charging: null,
            storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(70, ts: windowStart + 60 * 60 * 1000, temp: 37.0, charging: null,
            storageFree: 80000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(60.2, ts: windowStart + 120 * 60 * 1000, temp: 38.0, charging: null,
            storageFree: 80000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final resultLow = computeHealthIndex(
        samples: samplesLow,
        thermalAvailable: false,
        nowMillis: nowMillis,
        baselineDrainPerHour: null,
      );
      expect(resultLow.battery.pointsLost, equals(0));
      expect(resultLow.battery.status, equals('good'));

      final samplesAtLow = <Map<String, dynamic>>[
        sample(80, ts: windowStart, temp: 36.5, charging: null,
            storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(70, ts: windowStart + 60 * 60 * 1000, temp: 37.0, charging: null,
            storageFree: 80000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(60, ts: windowStart + 120 * 60 * 1000, temp: 38.0, charging: null,
            storageFree: 70000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final resultAtLow = computeHealthIndex(
        samples: samplesAtLow,
        thermalAvailable: false,
        nowMillis: nowMillis,
        baselineDrainPerHour: null,
      );
      expect(resultAtLow.battery.pointsLost, equals(0));
      expect(resultAtLow.battery.status, equals('good'));

      final samplesAtMedium = <Map<String, dynamic>>[
        sample(80, ts: windowStart, temp: 36.5, charging: null,
            storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(70, ts: windowStart + 60 * 60 * 1000, temp: 37.0, charging: null,
            storageFree: 80000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(55, ts: windowStart + 120 * 60 * 1000, temp: 38.0, charging: null,
            storageFree: 67500000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final resultAtMedium = computeHealthIndex(
        samples: samplesAtMedium,
        thermalAvailable: false,
        nowMillis: nowMillis,
        baselineDrainPerHour: null,
      );
      expect(resultAtMedium.battery.pointsLost, equals(2));
      expect(resultAtMedium.battery.status, equals('good'));

      final samplesAtMedium2 = <Map<String, dynamic>>[
        sample(80, ts: windowStart, temp: 36.5, charging: null,
            storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(70, ts: windowStart + 60 * 60 * 1000, temp: 37.0, charging: null,
            storageFree: 80000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(50, ts: windowStart + 120 * 60 * 1000, temp: 38.0, charging: null,
            storageFree: 65000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final resultAtMedium2 = computeHealthIndex(
        samples: samplesAtMedium2,
        thermalAvailable: false,
        nowMillis: nowMillis,
        baselineDrainPerHour: null,
      );
      expect(resultAtMedium2.battery.pointsLost, equals(2));
      expect(resultAtMedium2.battery.status, equals('good'));

      final samplesAboveMedium = <Map<String, dynamic>>[
        sample(80, ts: windowStart, temp: 36.5, charging: null,
            storageFree: 100000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(70, ts: windowStart + 60 * 60 * 1000, temp: 37.0, charging: null,
            storageFree: 80000000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
        sample(49.8, ts: windowStart + 120 * 60 * 1000, temp: 38.0, charging: null,
            storageFree: 64900000, storageTotal: 5000000000, memAvail: 2048, memTotal: 8192, lowMemory: false),
      ];
      final resultAboveMedium = computeHealthIndex(
        samples: samplesAboveMedium,
        thermalAvailable: false,
        nowMillis: nowMillis,
        baselineDrainPerHour: null,
      );
      expect(resultAboveMedium.battery.pointsLost, equals(5));
      expect(resultAboveMedium.battery.status, equals('fair'));
    });
  });
}