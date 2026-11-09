import 'package:flutter/material.dart';

import 'package:performance_optimization/performance/data/perf_repository.dart';
import 'package:performance_optimization/performance/engine/health_index.dart';
import 'package:performance_optimization/performance/ui/common/perf_status.dart';
import 'package:performance_optimization/performance/ui/common/perf_time.dart';
import 'package:performance_optimization/performance/ui/common/perf_widgets.dart';

// Import the settings screen from the dashboard file
import 'perf_dashboard_screen.dart';

/// The Health tab screen showing the phone health index and metrics.
class PerfHealthScreen extends StatefulWidget {
  const PerfHealthScreen({super.key});

  @override
  State<PerfHealthScreen> createState() => _PerfHealthScreenState();
}

class _PerfHealthScreenState extends State<PerfHealthScreen> {
  // State for pull-to-refresh and data loading
  bool _loading = true;
  bool _hasError = false;
  late ScrollController _scrollController;

  // Latest data
  Map<String, dynamic>? _latestSample;
  List<Map<String, dynamic>> _samples = [];
  bool _usageAccessGranted = false;
  bool _thermalAvailable = false;

  // Computed health result
  HealthResult? _healthResult;

  // Mapping from status string to PerfStatus enum
  PerfStatus _stringToPerfStatus(String status) {
    return PerfStatus.values.firstWhere(
      (e) => e.toString().split('.').last == status,
      orElse: () => PerfStatus.unavailable,
    );
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[PERF_TRACE] HealthScreen.initState');
    _scrollController = ScrollController();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter == 0 && !_loading) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    debugPrint('[PERF_TRACE] HealthScreen.loadData: start');
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      // Refresh and get latest sample
      debugPrint('[PERF_TRACE] HealthScreen.loadData: calling refreshAndGetLatest');
      final result = await PerfRepository.refreshAndGetLatest();
      _latestSample = result;
      debugPrint(
        '[PERF_TRACE] HealthScreen.loadData: refresh complete; latest sample '
        'is ${result == null ? 'null' : 'present'}, timestamp=${result?['timestamp']}',
      );

      // Get samples from last 24 hours
      final sinceMillis =
          DateTime.now().millisecondsSinceEpoch - 24 * 60 * 60 * 1000;
      debugPrint('[PERF_TRACE] HealthScreen.loadData: requesting samples since $sinceMillis');
      _samples = await PerfRepository.getSamples(sinceMillis: sinceMillis);
      debugPrint('[PERF_TRACE] HealthScreen.loadData: received ${_samples.length} samples');

      // Check capabilities for thermal availability
      debugPrint('[PERF_TRACE] HealthScreen.loadData: requesting capabilities');
      final capabilities = await PerfRepository.getCapabilities();
      _thermalAvailable = capabilities.any((cap) {
        final metricName = cap['metricName'] as String?;
        return metricName == 'thermal_status';
      });
      debugPrint(
        '[PERF_TRACE] HealthScreen.loadData: received ${capabilities.length} capabilities; '
        'thermalAvailable=$_thermalAvailable',
      );

      // Check usage access
      debugPrint('[PERF_TRACE] HealthScreen.loadData: checking Usage Access');
      _usageAccessGranted = await PerfRepository.isUsageAccessGranted();
      debugPrint('[PERF_TRACE] HealthScreen.loadData: usageAccessGranted=$_usageAccessGranted');

      // Compute health index
      if (_samples.isNotEmpty) {
        debugPrint('[PERF_TRACE] HealthScreen.loadData: computing health index');
        final healthResult = computeHealthIndex(
          samples: _samples,
          thermalAvailable: _thermalAvailable,
          nowMillis: DateTime.now().millisecondsSinceEpoch,
          baselineDrainPerHour: null,
        );
        debugPrint(
          '[PERF_TRACE] HealthScreen.loadData: health result sampleCount=${healthResult.sampleCount}, '
          'headline=${healthResult.headline}',
        );
        setState(() => _healthResult = healthResult);
      } else {
        debugPrint('[PERF_TRACE] HealthScreen.loadData: no samples; clearing health result');
        setState(() => _healthResult = null);
      }

      // If no samples yet, show collecting data message
      if (_samples.isEmpty) {
        _showNoDataMessage();
      }
      debugPrint('[PERF_TRACE] HealthScreen.loadData: completed successfully');
    } catch (e, stackTrace) {
      debugPrint('[PERF_TRACE] HealthScreen.loadData: FAILED: $e');
      debugPrint('[PERF_TRACE] HealthScreen.loadData: stack trace:\n$stackTrace');
      setState(() {
        _hasError = true;
      });
    } finally {
      debugPrint('[PERF_TRACE] HealthScreen.loadData: finally; mounted=$mounted');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showNoDataMessage() {
    debugPrint('No samples available yet');
  }

  // Helper to format the age of the latest sample
  String _formatLatestAge() {
    if (_latestSample == null || _latestSample!['timestamp'] == null) {
      return 'Updated just now';
    }
    final latestMillis = _latestSample!['timestamp'] as int;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    return formatAge(latestMillis, nowMillis);
  }

  // Build the header band with gauge
  Widget _buildHeader() {
    // ignore: unused_local_variable
    final measuredCount = _healthResult?.measuredCount ?? 0;
    final latestAge = _formatLatestAge();

    return Container(
      height: 200,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: LayoutBuilder(builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final gaugeSize = maxWidth * 0.6; // gauge takes 60% of width

        // Build the semi-circle gauge using CustomPainter
        return Stack(
          children: [
            // Semi-circle gauge background + progress
            CustomPaint(
              size: Size(gaugeSize, gaugeSize),
              painter: _GaugePainter(
                progress: _healthResult != null
                    ? _healthResult!.headline == 'Your phone is in good shape'
                        ? 1.0
                        : _healthResult!.headline == 'Your phone is doing okay'
                            ? 0.6
                            : 0.3
                    : 0.0,
              ),
            ),

            // Score text in the center
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _healthResult?.headline ?? 'Collecting data...',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'HEALTH INDEX / 100',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // N of 4 parts measured caption
            if (_healthResult != null && measuredCount > 0 && measuredCount < 4)
              Positioned(
                bottom: 4,
                left: 4,
                child: Text(
                  '$measuredCount of 4 parts measured.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),

            // Updated time on the right
            Positioned(
              top: 8,
              right: 8,
              child: Text(
                'Updated $latestAge',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),

            // Gear icon on the far right
            Positioned(
              top: 8,
              right: 32,
              child: IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Performance settings',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PerformanceSettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  // Build a metric card for the 2x2 grid
  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required String sentence,
    required int pointsLost,
    required String statusString,
  }) {
    // Points not lost out of 25, as a percentage for the bar
    final pointsNotLost = 25 - pointsLost;
    final barValue =
        (pointsNotLost / 25).clamp(0.0, 1.0); // 0.0 to 1.0

    final status = _stringToPerfStatus(statusString);

    return PerfCard(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + PerfChip at top
            Row(
              children: [
                Icon(icon, size: 24),
                const Spacer(),
                PerfChip(status: status),
              ],
            ),
            const SizedBox(height: 8),

            // Component sentence
            Text(
              sentence,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Thin bar showing share of points not lost
            SizedBox(
              height: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(4),
                  right: Radius.circular(4),
                ),
                child: LinearProgressIndicator(
                  value: barValue > 0 ? barValue : null,
                  minHeight: 4,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Points text
            Text(
              '$pointsLost pts lost',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // Build the Usage Access banner - returns null or a non-null widget
  Widget? _buildUsageAccessBanner() {
    if (_usageAccessGranted) return null;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Some details need Usage Access. Optional. Nothing leaves your phone.',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () async {
              final opened = await PerfRepository.openUsageAccessSettings();
              if (opened && mounted) {
                setState(() => _usageAccessGranted = true);
                _loadData();
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Build the footer card
  Widget _buildFooter() {
    final sampleCount = _healthResult?.sampleCount ?? 0;
    final gapsCount = _healthResult?.gapsCount ?? 0;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Based on $sampleCount samples, last 24 hours',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (gapsCount > 0)
                Text(
                  '$gapsCount small data gaps',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              // "How this was measured" link
              TextButton(
                onPressed: () {
                  _showDetailsSheet(context);
                },
                child: const Text(
                  'How this was measured',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show the details bottom sheet
  void _showDetailsSheet(BuildContext context) {
    if (_healthResult == null || _latestSample == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available yet')),
      );
      return;
    }

    final lines = <String>[];

    // Add each component's details
    lines.add('Battery: ${_healthResult!.battery.sentence}');
    lines.add('Heat: ${_healthResult!.heat.sentence}');
    lines.add('Memory: ${_healthResult!.memory.sentence}');
    lines.add('Storage: ${_healthResult!.storage.sentence}');

    // Add thermal capability reason
    if (!_thermalAvailable) {
      lines.add(
        'Thermal capability: not available on this device',
      );
    } else {
      // Thermal is available - show basic info from the health result
      // Use the heat details if available, otherwise generic message
      if (_healthResult!.heat.details.isNotEmpty) {
        lines.add('Thermal: ${_healthResult!.heat.details.join(', ')}');
      } else {
        lines.add('Thermal: capability available');
      }
    }

    // Add latest sample details
    final chargingState =
        _latestSample?['chargingState'] ?? 'Unknown';
    final batteryPct = _latestSample?['batteryPct'] ?? '?';
    final batteryTemp = _latestSample?['batteryTempC'] ?? '?';
    final memAvail = _latestSample?['memAvailMb'] ?? '?';
    final memTotal = _latestSample?['memTotalMb'] ?? '?';
    final storageFree = _latestSample?['storageFreeBytes'];
    final storageTotal = _latestSample?['storageTotalBytes'];

    lines.add('Latest sample:');
    lines.add(
      '  Time: ${_formatTimestamp(_latestSample?['timestamp'])}',
    );
    lines.add(
      '  Battery: $batteryPct%, Temperature: $batteryTemp°C, '
      'Charging: $chargingState',
    );
    lines.add(
      '  Memory: $memAvail MB of $memTotal MB',
    );
    lines.add(
      '  Storage: ${storageFree ?? 0} free of ${storageTotal ?? 0} bytes',
    );

    // Debug battery read from latest stored sample (NOT a live hardware read).
    lines.add('Live raw battery (debug):');
    // This block is for development debugging only; remove at merge.
    if (_latestSample != null) {
      lines.add('  Status: ${_latestSample?['status']}');
      lines.add('  Plugged: ${_latestSample?['pluggedType']}');
      lines.add('  Level: ${_latestSample?['batteryPct']}');
      lines.add('  Temperature: ${_latestSample?['batteryTempC']}°C');
    } else {
      lines.add('  Unavailable');
    }

    showPerfDetailsSheet(
      context,
      'How this was measured',
      lines,
    );
  }

  String _formatTimestamp(Object? value) {
    final millis = value as int?;
    if (millis == null) return 'Unknown';
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Refresh indicator for pull-to-refresh
          RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header band
                  _buildHeader(),

                  const SizedBox(height: 16),

                  // Usage Access banner - use ?? const SizedBox.shrink() to handle nullable return
                  _buildUsageAccessBanner() ?? const SizedBox.shrink(),

                  const SizedBox(height: 16),

                  // 2x2 grid of metric cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Battery',
                          icon: Icons.battery_full,
                          sentence:
                              _healthResult?.battery.sentence ?? 'Loading...',
                          pointsLost: _healthResult?.battery.pointsLost ?? 0,
                          statusString:
                              _healthResult?.battery.status ?? 'learning',
                        ),
                      ),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Heat',
                          icon: Icons.remove_circle,
                          sentence:
                              _healthResult?.heat.sentence ?? 'Loading...',
                          pointsLost: _healthResult?.heat.pointsLost ?? 0,
                          statusString:
                              _healthResult?.heat.status ?? 'learning',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Memory',
                          icon: Icons.memory,
                          sentence:
                              _healthResult?.memory.sentence ?? 'Loading...',
                          pointsLost: _healthResult?.memory.pointsLost ?? 0,
                          statusString:
                              _healthResult?.memory.status ?? 'learning',
                        ),
                      ),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Storage',
                          icon: Icons.storage,
                          sentence:
                              _healthResult?.storage.sentence ?? 'Loading...',
                          pointsLost: _healthResult?.storage.pointsLost ?? 0,
                          statusString:
                              _healthResult?.storage.status ?? 'learning',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Footer
                  _buildFooter(),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // Error overlay
          if (_hasError)
            const Center(
              child: Text('Failed to load performance data'),
            ),
      ],
      ),
    );
  }
}

/// Custom painter for the semi-circle gauge.
class _GaugePainter extends CustomPainter {
  /// Progress from 0.0 to 1.0 across the semi-circle.
  final double progress;

  _GaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Draw the full circle background
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1;

    canvas.drawCircle(center, r, backgroundPaint);

    // Draw the progress arc (semi-circle from -90 to 90 degrees, i.e. top half)
    final progressPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1
      ..strokeCap = StrokeCap.round;

    final arcAngle = progress * 3.14159; // semi-circle = PI radians
    // Use a rectangular bound that covers the full width for the arc
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, -1.57079, arcAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.progress != progress;
}