import 'package:flutter/material.dart';

/// Status of a performance metric, with a human-readable label.
enum PerfStatus {
  good,
  fair,
  attention,
  learning,
  unavailable;

  /// Human-readable label shown on the status chip.
  String get label {
    switch (this) {
      case good:
        return 'Good';
      case fair:
        return 'Fair';
      case attention:
        return 'Needs attention';
      case learning:
        return 'Learning';
      case unavailable:
        return 'Unavailable';
    }
  }

  /// Return the colour from a [ColorScheme], as specified by the task:
  /// good=primary, fair=tertiary, attention=error, learning/unavailable=outline.
  Color getFromColorScheme(ColorScheme colorScheme) {
    switch (this) {
      case good:
        return colorScheme.primary;
      case fair:
        return colorScheme.tertiary;
      case attention:
        return colorScheme.error;
      case learning:
      case unavailable:
        return colorScheme.outline;
    }
  }
}