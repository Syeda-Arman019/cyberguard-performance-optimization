/// Named constants for the Health Index engine.
/// All values are declared once so they can be referenced across
/// discharge_runs.dart and health_index.dart without magic numbers.
class Thresholds {
  /// Maximum gap (in minutes) between consecutive samples for them to belong
  /// to the same discharge run.
  static const int runMaxGapMin = 60;

  /// Minimum total drain hours for overallRate to return a non-null value.
  static const int minDrainHours = 2;

  /// Minimum run duration (in minutes) for a discharge run to be kept.
  static const int minRunMinutes = 60;

  /// Percentage-per-hour drain threshold without baseline:
  /// rate <= 10 → 0 points lost; <= 15 → 2 points lost; > 15 → 5 points lost.
  static const double drainRateNoBaselineLow = 10.0;
  static const double drainRateNoBaselineMedium = 15.0;
  static const double drainRateNoBaselineHigh = 5;

  /// Percentage-per-hour drain threshold with baseline:
  /// ratio <= 1.3 → 0 points lost; <= 2.0 → 5 points lost; > 2.0 → 15 points lost.
  static const double drainRateWithBaselineLow = 1.3;
  static const double drainRateWithBaselineMedium = 2.0;
  static const double drainRateWithBaselineHigh = 15;

  /// Battery temperature thresholds (degrees C).
  static const double tempLow = 40.0;
  static const double tempMedium1 = 44.9;
  static const double tempMedium2 = 49.9;

  /// Thermal status thresholds.
  static const int thermalLow = 0;
  static const int thermalMedium1 = 2;
  static const int thermalMedium2 = 3;
  static const int thermalHigh = 4;

  /// Memory availability thresholds (percentage of total).
  static const double memLowPct = 15.0;
  static const double memMedium1Pct = 8.0;

  /// Storage free ratio thresholds.
  static const double storageLowPct = 20.0;
  static const double storageMedium1Pct = 10.0;
  static const double storageMedium2Pct = 5.0;
}