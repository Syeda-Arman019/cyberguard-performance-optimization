import 'dart:math';

import 'discharge_runs.dart';
import 'thresholds.dart';

/// Status of a single health component.
class ComponentResult {
  /// Component status: good, fair, attention, learning or unavailable.
  final String status;
  /// Points lost for this component (0-25).
  final int pointsLost;
  /// One short plain sentence about the component.
  final String sentence;
  /// List of detail strings providing extra context.
  final List<String> details;

  ComponentResult({
    required this.status,
    required this.pointsLost,
    required this.sentence,
    required this.details,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComponentResult) return false;
    return status == other.status &&
        pointsLost == other.pointsLost &&
        sentence == other.sentence &&
        _listEquals(details, other.details);
  }

  @override
  int get hashCode => Object.hash(status, pointsLost, sentence, details.toString());

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Result of the health index computation.
class HealthResult {
  /// Headline text based on the final score.
  final String headline;
  /// Battery component result.
  final ComponentResult battery;
  /// Heat component result.
  final ComponentResult heat;
  /// Memory component result.
  final ComponentResult memory;
  /// Storage component result.
  final ComponentResult storage;
  /// Number of components that contribute to the final score (unavailable/learning excluded).
  final int measuredCount;
  /// Total number of samples considered.
  final int sampleCount;
  /// Number of gaps > 60 minutes between consecutive samples.
  final int gapsCount;

  HealthResult({
    required this.headline,
    required this.battery,
    required this.heat,
    required this.memory,
    required this.storage,
    required this.measuredCount,
    required this.sampleCount,
    required this.gapsCount,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HealthResult) return false;
    return headline == other.headline &&
        battery == other.battery &&
        heat == other.heat &&
        memory == other.memory &&
        storage == other.storage &&
        measuredCount == other.measuredCount &&
        sampleCount == other.sampleCount &&
        gapsCount == other.gapsCount;
  }

  @override
  int get hashCode => Object.hash(
    headline,
    battery.hashCode,
    heat.hashCode,
    memory.hashCode,
    storage.hashCode,
    measuredCount,
    sampleCount,
    gapsCount,
  );
}

/// Computes the health index from the last 24h of samples.
/// [samples] must be ordered oldest first and represent the last 24 hours.
/// [thermalAvailable] indicates if thermal status info is available from the hardware.
/// [nowMillis] the current time (used once to define the 24h window; defaults to [DateTime.now]).
/// [baselineDrainPerHour] optional baseline drain rate (%/h) for comparison.
HealthResult computeHealthIndex({
  required List<Map<String, dynamic>> samples,
  required bool thermalAvailable,
  int? nowMillis,
  double? baselineDrainPerHour,
}) {
  final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
  final windowStart = now - 24 * 60 * 60 * 1000; // 24h window

  // Filter samples to the 24h window, oldest first.
  final windowSamples = <Map<String, dynamic>>[];
  for (final s in samples) {
    final ts = s['timestamp'] as int?;
    if (ts != null && ts >= windowStart && ts <= now) {
      windowSamples.add(s);
    }
  }

  final sampleCount = windowSamples.length;

  // Count gaps > 60 min between consecutive samples in the window.
  int gapsCount = 0;
  for (int i = 1; i < windowSamples.length; i++) {
    final prevTs = windowSamples[i - 1]['timestamp'] as int?;
    final currTs = windowSamples[i]['timestamp'] as int?;
    if (prevTs != null && currTs != null) {
      final gapMinutes = (currTs - prevTs) / (1000 * 60);
      if (gapMinutes > 60) {
        gapsCount++;
      }
    }
  }

  // ---- Battery Component ----
  // Uses dischargeRuns with splitByScreen: false.
  final dischargeRunList = dischargeRuns(windowSamples, splitByScreen: false);
  final overallRateValue = overallRate(dischargeRunList);

  ComponentResult batteryComponent;
  if (overallRateValue == null) {
    // No rate -> learning ("Learning your normal usage").
    batteryComponent = ComponentResult(
      status: 'learning',
      pointsLost: 0,
      sentence: 'Learning your normal usage',
      details: [],
    );
  } else {
    final rate = overallRateValue; // % per hour
    int pointsLost;
    final String sentence;
    if (baselineDrainPerHour == null) {
      // Without baseline.
      if (rate <= Thresholds.drainRateNoBaselineLow) {
        pointsLost = 0;
        sentence = 'Draining normally';
      } else if (rate <= Thresholds.drainRateNoBaselineMedium) {
        pointsLost = 2;
        sentence = 'Draining faster than usual';
      } else {
        pointsLost = 5;
        sentence = 'Draining faster than usual';
      }
    } else {
      // With baseline.
      final ratio = rate / baselineDrainPerHour;
      if (ratio <= Thresholds.drainRateWithBaselineLow) {
        pointsLost = 0;
        sentence = 'Draining normally';
      } else if (ratio <= Thresholds.drainRateWithBaselineMedium) {
        pointsLost = 5;
        sentence = 'Draining faster than usual';
      } else {
        pointsLost = 15;
        sentence = 'Draining faster than usual';
      }
    }

    final status = _componentStatus(pointsLost);
    batteryComponent = ComponentResult(
      status: status,
      pointsLost: pointsLost,
      sentence: sentence,
      details: [],
    );
  }

  // ---- Heat Component ----
  // Find peak battery_temp_c (non-null values) in the window.
  final tempValues = <double>[];
  final thermalStatusValues = <int>[];

  for (final s in windowSamples) {
    final temp = s['batteryTempC'] as double?;
    if (temp != null) {
      tempValues.add(temp);
    }
    final ts = s['thermalStatus'] as int?;
    if (ts != null) {
      thermalStatusValues.add(ts);
    }
  }

  // thermalStatusUsed: true when thermalAvailable and there are thermal status values.
  final thermalStatusUsed = thermalAvailable && thermalStatusValues.isNotEmpty;
  int peakThermalStatus = thermalStatusValues.isNotEmpty
      ? thermalStatusValues.reduce(max)
      : 0;

  int tempPoints;
  int statusPoints;
  double peakTemp = tempValues.isNotEmpty ? tempValues.reduce(max) : double.nan;
  double latestTemp = tempValues.isNotEmpty ? tempValues.last : double.nan;

  if (tempValues.isNotEmpty) {
    // Temperature-based points.
    if (peakTemp < 40.0) {
      tempPoints = 0;
    } else if (peakTemp < 45.0) { // 40-44.9
      tempPoints = 5;
    } else if (peakTemp < 50.0) { // 45-49.9
      tempPoints = 12;
    } else { // >= 50
      tempPoints = 25;
    }
  } else {
    tempPoints = 0;
  }

  if (thermalAvailable && thermalStatusValues.isNotEmpty) {
    // Status-based points.
    if (peakThermalStatus < 2) {
      statusPoints = 0;
    } else if (peakThermalStatus == 2) {
      statusPoints = 10;
    } else if (peakThermalStatus == 3) {
      statusPoints = 20;
    } else { // >= 4
      statusPoints = 25;
    }
  } else {
    statusPoints = 0;
  }

  int heatLost = max(tempPoints, statusPoints);
  String heatStatusStr = _componentStatus(heatLost);
  final heatHasTemp = tempValues.isNotEmpty;
  final heatHasStatus = thermalStatusUsed;

  String heatSentence;
  List<String> heatDetails = <String>[];

  if (!heatHasTemp && !heatHasStatus) {
    // No temperature and no status at all -> unavailable.
    heatStatusStr = 'unavailable';
    heatLost = 0;
    heatSentence = 'Unavailable';
    heatDetails = <String>[];
  } else if (!heatHasTemp) {
    // Only thermal status available.
    heatSentence = 'Got warm, peak ${_formatTemp(peakTemp)} C';
    heatDetails = <String>['Thermal status used'];
  } else if (!heatHasStatus) {
    // Only temperature available.
    heatSentence = 'Normal, ${_formatTemp(latestTemp)} C';
    heatDetails = <String>['Thermal status not available on this device'];
  } else {
    // Both available.
    heatSentence = peakTemp < 40.0
        ? 'Normal, ${_formatTemp(latestTemp)} C'
        : 'Got warm, peak ${_formatTemp(peakTemp)} C';
    heatDetails = <String>['Thermal status used'];
  }

  ComponentResult heatComponent;
  if (!heatHasTemp && !heatHasStatus) {
    heatComponent = ComponentResult(
      status: 'unavailable',
      pointsLost: 0,
      sentence: 'Unavailable',
      details: <String>[],
    );
  } else {
    heatComponent = ComponentResult(
      status: heatStatusStr,
      pointsLost: heatLost,
      sentence: heatSentence,
      details: heatDetails,
    );
  }

  // ---- Memory Component ----
  // median of mem_avail_mb / mem_total_mb over the window.
  final availabilityRatios = <double>[];
  int lowMemoryCount = 0;
  for (final s in windowSamples) {
    final avail = s['memAvailMb'] as int?;
    final total = s['memTotalMb'] as int?;
    if (avail != null && total != null && total > 0) {
      availabilityRatios.add(avail / total);
    }
    if (s['lowMemory'] == true) {
      lowMemoryCount++;
    }
  }

  int memPointsLost;
  final String memSentence;
  List<String> memDetails = <String>[];

  if (availabilityRatios.isNotEmpty) {
    // Compute median.
    final sorted = List<double>.from(availabilityRatios);
    sorted.sort();
    final medianIdx = sorted.length ~/ 2;
    final median = sorted.length % 2 == 0
        ? (sorted[medianIdx - 1] + sorted[medianIdx]) / 2
        : sorted[medianIdx];

    // Convert to percentage.
    final medianPct = median * 100;

    if (medianPct >= Thresholds.memLowPct) {
      // >= 15% free: no penalty.
      memPointsLost = 0;
      memSentence = 'Enough free RAM';
    } else if (medianPct >= 8.0) {
      // 8-15% free.
      memPointsLost = 8;
      memSentence = 'Memory is running low';
    } else {
      // < 8% free.
      memPointsLost = 20;
      memSentence = 'Memory is running low';
    }

    // Add 5 if low_memory was true in more than 30% of samples (cap 25).
    final lowMemoryRatio = windowSamples.isNotEmpty
        ? lowMemoryCount / windowSamples.length
        : 0;
    if (lowMemoryRatio > 0.3 && memPointsLost + 5 <= 25) {
      memPointsLost += 5;
    }
  } else {
    // No memory data available.
    memPointsLost = 0;
    memSentence = 'Unavailable';
    memDetails = <String>[];
  }

  final memStatus = _componentStatus(memPointsLost);
  final memLowFlagUsed = lowMemoryCount / windowSamples.length > 0.3;
  if (memLowFlagUsed) {
    memDetails = <String>['Low memory flag frequent'];
  }

  ComponentResult memoryComponent = ComponentResult(
    status: memStatus,
    pointsLost: memPointsLost,
    sentence: memSentence,
    details: memDetails,
  );

  // ---- Storage Component ----
  // the LATEST sample's free ratio.
  // Samples are oldest first, so the last sample in the window is the newest.
  final latestSample = windowSamples.isNotEmpty ? windowSamples.last : null;
  int storagePointsLost = 0;
  final String storageSentence;
  List<String> storageDetails = <String>[];

  if (latestSample != null) {
    final freeBytes = latestSample['storageFreeBytes'] as int?;
    final totalBytes = latestSample['storageTotalBytes'] as int?;
    if (totalBytes != null && totalBytes > 0 && freeBytes != null) {
      final freeRatio = freeBytes / totalBytes;
      final freePct = freeRatio * 100;

      if (freePct >= Thresholds.storageLowPct) {
        // >= 20% free.
        storagePointsLost = 0;
      } else if (freePct >= Thresholds.storageMedium1Pct) {
        // 10-20% free.
        storagePointsLost = 8;
      } else if (freePct >= Thresholds.storageMedium2Pct) { // 5-10%
        storagePointsLost = 16;
      } else { // < 5%
        storagePointsLost = 25;
      }
      storageSentence = '${freePct.floor()}% free';
    } else {
      storagePointsLost = 0;
      storageSentence = '0% free';
    }
    storageDetails = <String>['Latest sample used'];
  } else {
    // No storage data.
    storagePointsLost = 0;
    storageSentence = 'Unavailable';
    storageDetails = <String>[];
  }

  final storageStatus = _componentStatus(storagePointsLost);
  ComponentResult storageComponent = ComponentResult(
    status: storageStatus,
    pointsLost: storagePointsLost,
    sentence: storageSentence,
    details: storageDetails,
  );

  // ---- Compute final score ----
  // Collect measured (non-unavailable, non-learning) components.
  final components = [
    batteryComponent,
    heatComponent,
    memoryComponent,
    storageComponent,
  ];
  final measured = <ComponentResult>[];
  for (final c in components) {
    if (c.status != 'unavailable' && c.status != 'learning') {
      measured.add(c);
    }
  }
  final measuredCount = measured.length;

  final totalLost = measured.fold<int>(0, (sum, c) => sum + c.pointsLost);
  final maxPossible = 25 * measuredCount;
  int finalScore;
  if (measuredCount == 0) {
    finalScore = 0;
  } else {
    finalScore = (100 - totalLost * 100 / maxPossible).round();
    if (finalScore < 0) finalScore = 0;
    if (finalScore > 100) finalScore = 100;
  }

  final headline = _headlineFromScore(finalScore);

  return HealthResult(
    headline: headline,
    battery: batteryComponent,
    heat: heatComponent,
    memory: memoryComponent,
    storage: storageComponent,
    measuredCount: measuredCount,
    sampleCount: sampleCount,
    gapsCount: gapsCount,
  );
}

String _componentStatus(int pointsLost) {
  if (pointsLost <= 3) return 'good';
  if (pointsLost <= 10) return 'fair';
  return 'attention';
}

String _headlineFromScore(int score) {
  if (score >= 80) return 'Your phone is in good shape';
  if (score >= 60) return 'Your phone is doing okay';
  return 'Your phone needs attention';
}

String _formatTemp(double? temp) {
  if (temp == null) return '?';
  return temp.toStringAsFixed(1);
}