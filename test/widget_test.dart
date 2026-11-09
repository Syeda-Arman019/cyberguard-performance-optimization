import 'package:flutter_test/flutter_test.dart';

import 'package:performance_optimization/main.dart';

void main() {
  testWidgets(
    'Performance optimization app boots and shows the debug screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(const PerformanceOptimizationApp());

      // The old counter app showed "Flutter Demo Home Page"; the new app's
      // debug screen shows "Performance debug" in its AppBar.
      expect(find.text('Performance debug'), findsOneWidget);
    },
  );
}