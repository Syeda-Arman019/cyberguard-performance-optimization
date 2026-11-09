import 'package:flutter/material.dart';

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
    return Center(
      child: Text(
        ['Health', 'Battery', 'Heat', 'Storage', 'Fix'][index],
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}

/// Empty stub for the settings screen.
class PerformanceSettingsScreen extends StatelessWidget {
  const PerformanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Performance Settings')),
    );
  }
}