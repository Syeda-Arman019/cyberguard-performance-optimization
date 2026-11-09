import 'package:flutter/material.dart';

import 'performance/debug/perf_debug_screen.dart';
import 'performance/ui/home/perf_dashboard_screen.dart';

// Keep the original app class for test compatibility
class PerformanceOptimizationApp extends StatelessWidget {
  const PerformanceOptimizationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CyberGuard Performance Optimization',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PerfDebugScreen(),
    );
  }
}

// New app class for the performance dashboard
class PerformanceDashboardApp extends StatelessWidget {
  const PerformanceDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CyberGuard Performance Optimization',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const PerformanceDashboardScreen(),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PerformanceDashboardApp());
}