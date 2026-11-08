import 'package:flutter/material.dart';
import 'performance/debug/perf_debug_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PerformanceOptimizationApp());
}

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
