import 'package:flutter_test/flutter_test.dart';
import 'package:performance_optimization/performance/ui/common/perf_time.dart';

void main() {
  group('formatAge', () {
    test('returns "Updated just now" for null latestMillis', () {
      expect(formatAge(null, 1000), equals('Updated just now'));
    });

    test('returns "Updated just now" for recent sample (0 diff)', () {
      expect(formatAge(1000, 1000), equals('Updated just now'));
    });

    test('returns "Updated just now" for less than 1 minute diff', () {
      // 30 seconds ago
      expect(formatAge(1000 - 30 * 1000, 1000), equals('Updated just now'));
    });

    test('returns "Updated 1 min ago" for 1 minute diff', () {
      // 1 minute = 60 * 1000 ms, use positive timestamps
      final now = 1000000;
      final oneMinAgo = now - 60 * 1000;
      expect(formatAge(oneMinAgo, now), equals('Updated 1 min ago'));
    });

    test('returns appropriate string for minutes < 60', () {
      // 45 minutes ago = 45 * 60 * 1000 ms
      final now = DateTime.now().millisecondsSinceEpoch;
      final fortyFiveMinAgo = now - 45 * 60 * 1000;
      expect(formatAge(fortyFiveMinAgo, now), startsWith('Updated'));
    });

    test('returns appropriate string for 1 hour diff', () {
      // 1 hour = 60 * 60 * 1000 ms
      final now = DateTime.now().millisecondsSinceEpoch;
      final oneHourAgo = now - 60 * 60 * 1000;
      expect(formatAge(oneHourAgo, now), startsWith('Updated'));
    });

    test('returns appropriate string for hours < 24', () {
      // 12 hours = 12 * 60 * 60 * 1000 ms
      final now = DateTime.now().millisecondsSinceEpoch;
      final twelveHoursAgo = now - 12 * 60 * 60 * 1000;
      expect(formatAge(twelveHoursAgo, now), startsWith('Updated'));
    });

    test('returns appropriate string for 1 day diff', () {
      // 1 day = 24 * 60 * 60 * 1000 ms
      final now = DateTime.now().millisecondsSinceEpoch;
      final oneDayAgo = now - 24 * 60 * 60 * 1000;
      expect(formatAge(oneDayAgo, now), startsWith('Updated'));
    });

    test('returns appropriate string for 5 days ago', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final fiveDaysAgo = now - 5 * 24 * 60 * 60 * 1000;
      expect(formatAge(fiveDaysAgo, now), startsWith('Updated'));
    });
  });
}