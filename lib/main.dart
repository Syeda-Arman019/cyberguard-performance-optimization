import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'performance/data/perf_repository.dart';
import 'performance/ui/home/perf_dashboard_screen.dart';
import 'performance/debug/perf_debug_screen.dart';

// Keep the original app class for test compatibility
class PerformanceOptimizationApp extends StatelessWidget {
  const PerformanceOptimizationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CyberGuard Performance Optimization',
      theme: CyberTheme.light,
      home: const PerfDebugScreen(),
    );
  }
}

// The production app: launches the 5-tab Performance Dashboard
class PerformanceDashboardApp extends StatelessWidget {
  const PerformanceDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CyberGuard Performance Optimization',
      theme: CyberTheme.light,
      home: const PerformanceDashboardScreen(),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the performance native channel before running the app
  final MethodChannel performanceChannel = MethodChannel(
    'cyberguard/performance',
  );
  PerfRepository.setChannel(performanceChannel);

  runApp(const PerformanceDashboardApp());
}
