import 'thresholds.dart';

/// A single contiguous discharge run.
class DischargeRun {
  /// Milliseconds of the first sample in the run.
  final int startMillis;
  /// Milliseconds of the last sample in the run.
  final int endMillis;
  /// Battery percentage at the start of the run.
  final double startPct;
  /// Battery percentage at the end of the run.
  final double endPct;
  /// Total percentage point drop (startPct - endPct, guaranteed >= 0 after discarding rising runs).
  final double drop;
  /// Duration of the run in hours (float).
  final double hours;
  /// Whether the screen was on during any part of the run.
  final bool? screenOn;
  /// Discharge rate per hour (drop / hours).
  final double ratePerHour;

  DischargeRun({
    required this.startMillis,
    required this.endMillis,
    required this.startPct,
    required this.endPct,
    required this.drop,
    required this.hours,
    required this.screenOn,
    required this.ratePerHour,
  });
}

/// Group consecutive discharging samples into runs.
///
/// [samples] must be ordered oldest first.
/// [splitByScreen] if true, a change in screen_interactive breaks the run;
///   a null screen_interactive breaks the run entirely.
/// [minMinutes] minimum run duration to keep (runs shorter are discarded).
/// Returns runs sorted oldest first.
List<DischargeRun> dischargeRuns(
  List<Map<String, dynamic>> samples, {
  bool splitByScreen = false,
  int minMinutes = 60,
}) {
  // Keep only samples that are discharging and have battery_pct.
  // "discharging" = chargingState is not 'charging' (null or other string).
  final discharging = <Map<String, dynamic>>[];
  for (final s in samples) {
    final pct = s['batteryPct'];
    final charging = s['chargingState'];
    if (pct != null && (charging == null || charging != 'charging')) {
      discharging.add(s);
    }
  }

  if (discharging.isEmpty) return [];

  // Ensure ascending by timestamp (oldest first).
  discharging.sort((a, b) {
    final ta = a['timestamp'] as int;
    final tb = b['timestamp'] as int;
    return ta.compareTo(tb);
  });

  final n = discharging.length;
  final runsList = <DischargeRun>[];
  int i = 0;

  while (i < n) {
    final startSamp = discharging[i];
    final startMillis = startSamp['timestamp'] as int;
    final startPct = startSamp['batteryPct'] as double;
    if (startPct.isNaN) {
      i++;
      continue;
    }

    // Figure out the end of this run by scanning forward.
    int runEndMillis = startMillis;
    double runEndPct = startPct;
    bool? runScreenOn = startSamp['screenInteractive'];
    int prevMillis = startMillis;
    int runJ = i; // first index NOT included in the run (initialized to i, will advance)

    for (int j = i + 1; j < n; j++) {
      final curr = discharging[j];
      final currMillis = curr['timestamp'] as int;
      final currPct = curr['batteryPct'] as double;
      final currScreen = curr['screenInteractive'];
      final gapMillis = currMillis - prevMillis;

      // Gap too large → end of run.
      if (gapMillis > Thresholds.runMaxGapMin * 60 * 1000) {
        runJ = j;
        break;
      }

      // splitByScreen: break when screen_interactive changes.
      if (splitByScreen) {
        final prevScreen = discharging[j - 1]['screenInteractive'];
        if (currScreen != prevScreen) {
          // A null screen state breaks the run entirely.
          if (currScreen == null) {
            runJ = j;
            break;
          }
          // Any other change (true→false, false→true, etc.) breaks the run.
          runJ = j;
          break;
        }
      }

      // Consecutive sample: extend the run.
      runEndMillis = currMillis;
      runEndPct = currPct;
      if (currScreen != null) runScreenOn = currScreen;
      prevMillis = currMillis;
      runJ = j + 1; // next sample after this one
    }

    // If the for loop completed naturally (no break), runJ = n.
    if (runJ == i) runJ = n;

    // Now evaluate the run from index i to runJ-1 (inclusive).
    // Check: percentage must not have risen.
    if (startPct < runEndPct) {
      // Percentage rose → discard this run.
      i = runJ;
      continue;
    }

    // Check: minimum duration.
    final durationMillis = runEndMillis - startMillis;
    final minMillis = minMinutes * 60 * 1000;
    if (durationMillis < minMillis) {
      // Too short → discard, try next starting point.
      i = runJ;
      continue;
    }

    // Valid run.
    final drop = startPct - runEndPct; // >= 0
    final hours = durationMillis / (1000 * 60 * 60);
    final ratePerHour = hours > 0 ? drop / hours : 0.0;

    runsList.add(DischargeRun(
      startMillis: startMillis,
      endMillis: runEndMillis,
      startPct: startPct,
      endPct: runEndPct,
      drop: drop,
      hours: _roundToTwo(hours),
      screenOn: runScreenOn,
      ratePerHour: _roundToTwo(ratePerHour),
    ));

    // Advance i to the first sample after this run (index runJ).
    i = runJ;
  }

  return runsList;
}

/// Compute the overall discharge rate from a list of [DischargeRun]s.
///
/// Returns total drop / total hours, or null when total hours < [Thresholds.minDrainHours].
double? overallRate(List<DischargeRun> runs) {
  if (runs.isEmpty) return null;

  double sumDrop = 0.0;
  double sumHours = 0.0;
  for (int i = 0; i < runs.length; i++) {
    final run = runs[i];
    sumDrop = sumDrop + run.drop;
    sumHours = sumHours + run.hours;
  }

  if (sumHours < Thresholds.minDrainHours) return null;

  if (sumHours == 0.0) return null;

  return sumDrop / sumHours;
}

/// Internal helper: round to two decimal places.
double _roundToTwo(double value) {
  // Use int rounding to avoid Dart analyzer type inference issues
  final int rounded = (value * 100).round();
  return rounded / 100.0;
}