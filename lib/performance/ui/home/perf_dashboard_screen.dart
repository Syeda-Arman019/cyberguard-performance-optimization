import 'package:flutter/material.dart';
import 'perf_health_screen.dart';
import 'package:performance_optimization/performance/debug/perf_debug_screen.dart';

/// The main performance dashboard screen with 5 tabs and a Settings option.
class PerformanceDashboardScreen extends StatefulWidget {
  const PerformanceDashboardScreen({super.key});

  @override
  State<PerformanceDashboardScreen> createState() =>
      _PerformanceDashboardScreenState();
}

class _PerformanceDashboardScreenState
    extends State<PerformanceDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PerformanceSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildTab(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.monitor_heart),
            label: 'Health',
          ),
          NavigationDestination(
            icon: const Icon(Icons.battery_full),
            label: 'Battery',
          ),
          NavigationDestination(
            icon: const Icon(Icons.remove_circle),
            label: 'Heat',
          ),
          NavigationDestination(
            icon: const Icon(Icons.storage),
            label: 'Storage',
          ),
          NavigationDestination(
            icon: const Icon(Icons.build),
            label: 'Fix',
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const PerfHealthScreen();
      case 1:
        return const Center(child: Text('Battery'));
      case 2:
        return const Center(child: Text('Heat'));
      case 3:
        return const Center(child: Text('Storage'));
      case 4:
        return const Center(child: Text('Fix'));
      default:
        return const Center(child: Text('Unknown'));
    }
  }
}

/// Settings screen with a Developer tools tile that opens the debug screen.
class PerformanceSettingsScreen extends StatelessWidget {
  const PerformanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Performance Settings content
            const Text('Performance Settings', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 24),

            // Developer tools tile
            _DevToolsTile(),
          ],
        ),
      ),
    );
  }
}

/// Opens the Performance debug screen to inspect capabilities, samples, and device info when tapped.
class _DevToolsTile extends StatelessWidget {
  const _DevToolsTile();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PerfDebugScreen(),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.remove_circle,
                  size: 28, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              const Text('Developer tools', style: TextStyle(fontSize: 18)),
              const Spacer(),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: Theme.of(context).colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}