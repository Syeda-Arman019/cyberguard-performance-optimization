// Pure Dart: format age of a sample into a human-readable string.
// No Flutter imports so this can be unit-tested independently.
String formatAge(int? latestMillis, int nowMillis) {
  if (latestMillis == null || latestMillis <= 0) {
    return 'Updated just now';
  }

  final difference = nowMillis - latestMillis;

  if (difference < 60 * 1000) {
    return 'Updated just now';
  }

  final diffMinutes = difference ~/ (60 * 1000);
  if (diffMinutes < 2) {
    return 'Updated 1 min ago';
  }

  if (diffMinutes < 60) {
    return 'Updated $diffMinutes min ago';
  }

  final diffHours = diffMinutes ~/ 60;
  if (diffHours < 2) {
    return 'Updated 1 hour ago';
  }

  if (diffHours < 24) {
    return 'Updated $diffHours hours ago';
  }

  final diffDays = diffHours ~/ 24;
  if (diffDays < 2) {
    return 'Updated 1 day ago';
  }

  return 'Updated $diffDays days ago';
}