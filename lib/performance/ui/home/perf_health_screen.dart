import 'package:flutter/material.dart';

import 'package:performance_optimization/core/theme.dart';
import 'package:performance_optimization/performance/data/perf_repository.dart';
import 'package:performance_optimization/performance/engine/health_index.dart';
import 'package:performance_optimization/performance/ui/common/perf_status.dart';
import 'package:performance_optimization/performance/ui/common/perf_widgets.dart';

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
      debugPrint(
        '[PERF_TRACE] HealthScreen.loadData: calling refreshAndGetLatest',
      );
      final result = await PerfRepository.refreshAndGetLatest();
      _latestSample = result;
      debugPrint(
        '[PERF_TRACE] HealthScreen.loadData: refresh complete; latest sample '
        'is ${result == null ? 'null' : 'present'}, timestamp=${result?['timestamp']}',
      );

      // Get samples from last 24 hours
      final sinceMillis =
          DateTime.now().millisecondsSinceEpoch - 24 * 60 * 60 * 1000;
      debugPrint(
        '[PERF_TRACE] HealthScreen.loadData: requesting samples since $sinceMillis',
      );
      _samples = await PerfRepository.getSamples(sinceMillis: sinceMillis);
      debugPrint(
        '[PERF_TRACE] HealthScreen.loadData: received ${_samples.length} samples',
      );

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
      debugPrint(
        '[PERF_TRACE] HealthScreen.loadData: usageAccessGranted=$_usageAccessGranted',
      );

      // Compute health index
      if (_samples.isNotEmpty) {
        debugPrint(
          '[PERF_TRACE] HealthScreen.loadData: computing health index',
        );
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
        debugPrint(
          '[PERF_TRACE] HealthScreen.loadData: no samples; clearing health result',
        );
        setState(() => _healthResult = null);
      }

      // If no samples yet, show collecting data message
      if (_samples.isEmpty) {
        _showNoDataMessage();
      }
      debugPrint('[PERF_TRACE] HealthScreen.loadData: completed successfully');
    } catch (e, stackTrace) {
      debugPrint('[PERF_TRACE] HealthScreen.loadData: FAILED: $e');
      debugPrint(
        '[PERF_TRACE] HealthScreen.loadData: stack trace:\n$stackTrace',
      );
      setState(() {
        _hasError = true;
      });
    } finally {
      debugPrint(
        '[PERF_TRACE] HealthScreen.loadData: finally; mounted=$mounted',
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showNoDataMessage() {
    debugPrint('No samples available yet');
  }

  int? _healthScore(HealthResult? result) {
    if (result == null) return null;
    final components =
        [result.battery, result.heat, result.memory, result.storage].where(
          (component) =>
              component.status != 'unavailable' &&
              component.status != 'learning',
        );
    final measured = components.toList();
    if (measured.isEmpty) return 0;
    final pointsLost = measured.fold<int>(
      0,
      (sum, component) => sum + component.pointsLost,
    );
    return (100 - pointsLost * 100 / (25 * measured.length)).round().clamp(
      0,
      100,
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final score = _healthScore(_healthResult);
    final result = _healthResult;
    final statusLabel = result == null
        ? (_loading ? 'Loading' : 'Unavailable')
        : result.measuredCount == 0
        ? 'Learning'
        : result.headline;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: CyberColors.heroGradient),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Health Index',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: CyberColors.surface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh health data',
                    onPressed: _loading ? null : _loadData,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: CyberColors.surface,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    color: CyberColors.surface,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 104,
                          height: 104,
                          child: CircularProgressIndicator(
                            value: (score ?? 0) / 100,
                            strokeWidth: 9,
                            strokeCap: StrokeCap.round,
                            backgroundColor: CyberColors.surface.withAlpha(55),
                            color: CyberColors.surface,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              score?.toString() ?? '—',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: CyberColors.surface,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'OUT OF 100',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: CyberColors.surface.withAlpha(220),
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: CyberColors.surface.withAlpha(35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: CyberColors.surface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          result?.measuredCount == 0
                              ? 'Collecting enough measurements to assess your device.'
                              : result?.headline ??
                                    (_loading
                                        ? 'Updating your device health…'
                                        : 'Health data is not available yet.'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: CyberColors.surface,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result == null
                              ? 'No health result available'
                              : '${result.measuredCount} of 4 components measured',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: CyberColors.surface.withAlpha(220),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required String value,
    required String description,
    required ComponentResult? result,
  }) {
    final valueAvailable = value != 'Unavailable' && value != '—';
    final measured =
        result != null &&
        result.status != 'unavailable' &&
        result.sentence != 'Unavailable' &&
        result.status != 'learning';
    final status = result == null || result.status == 'unavailable'
        ? PerfStatus.unavailable
        : _stringToPerfStatus(result.status);

    return PerfMetricCard(
      icon: icon,
      title: title,
      value: valueAvailable || !_loading ? value : 'Loading…',
      description: description,
      status: status,
      pointsLost: measured ? result.pointsLost : null,
    );
  }

  // Build the Usage Access banner - returns null or a non-null widget
  Widget? _buildUsageAccessBanner() {
    if (_usageAccessGranted) return null;

    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.privacy_tip_outlined,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Usage Access can provide additional app-usage details. It is optional.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
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

  Widget _buildFooter() {
    final theme = Theme.of(context);
    final sampleCount = _healthResult?.sampleCount ?? _samples.length;
    final batteryResult = _healthResult?.battery;
    final heatResult = _healthResult?.heat;
    final memoryResult = _healthResult?.memory;
    final storageResult = _healthResult?.storage;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Icon(
            Icons.fact_check_outlined,
            color: theme.colorScheme.primary,
          ),
          title: const Text('How this was measured'),
          subtitle: Text(
            '$sampleCount samples · Last 24 hours',
            style: theme.textTheme.bodySmall,
          ),
          children: [
            _detailRow('Measurement window', 'Last 24 hours', theme),
            _detailRow('Available samples', '$sampleCount', theme),
            _detailRow(
              'Last updated',
              _latestSample == null
                  ? 'Unavailable'
                  : _formatTimestamp(_latestSample!['timestamp']),
              theme,
            ),
            _detailRow(
              'Data sources',
              'Battery readings, device memory and storage, and thermal status when available.',
              theme,
            ),
            const Divider(height: 24),
            _detailRow(
              'Battery',
              _componentDetail(batteryResult, _batteryValue()),
              theme,
            ),
            _detailRow(
              'Thermal',
              _componentDetail(heatResult, _temperatureValue()),
              theme,
            ),
            _detailRow(
              'Memory',
              _componentDetail(memoryResult, _memoryValue()),
              theme,
            ),
            _detailRow(
              'Storage',
              _componentDetail(storageResult, _storageValue()),
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  String _componentDetail(ComponentResult? result, String measurement) {
    if (result == null) return '$measurement · No score available';
    final penalty = result.status == 'unavailable'
        ? 'No score available'
        : '${result.pointsLost} points lost';
    return '$measurement · ${result.sentence} · $penalty';
  }

  String _batteryValue() {
    final value = _latestSample?['batteryPct'];
    return value is num ? '${value.toStringAsFixed(0)}%' : 'Unavailable';
  }

  String _temperatureValue() {
    final value = _latestSample?['batteryTempC'];
    if (value is num) return '${value.toStringAsFixed(1)}°C';
    final thermalStatus = _latestSample?['thermalStatus'];
    return thermalStatus is num
        ? 'Thermal status $thermalStatus'
        : 'Unavailable';
  }

  String _memoryValue() {
    final available = _latestSample?['memAvailMb'];
    final total = _latestSample?['memTotalMb'];
    if (available is! num || total is! num) return 'Unavailable';
    return '${available.toStringAsFixed(0)} MB available of '
        '${total.toStringAsFixed(0)} MB';
  }

  String _memoryDescription() {
    final result = _healthResult?.memory;
    if (result != null) return result.sentence;
    return _loading ? 'Updating memory status' : 'No memory result';
  }

  String _storageValue() {
    final free = _latestSample?['storageFreeBytes'];
    final total = _latestSample?['storageTotalBytes'];
    if (free is! num || total is! num || total <= 0) return 'Unavailable';
    return '${(free / total * 100).floor()}% free';
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
    final theme = Theme.of(context);
    final usageBanner = _buildUsageAccessBanner();
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: CyberColors.backgroundGradient,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_hasError)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Health data could not be refreshed. Your saved measurements have not been changed.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _loading ? null : _loadData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      if (usageBanner != null) ...[
                        usageBanner,
                        const SizedBox(height: 12),
                      ],
                      _buildHeader(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Device health',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            'LIVE MEASUREMENTS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildMetricCard(
                            title: 'Battery Health',
                            icon: Icons.battery_charging_full,
                            value: _batteryValue(),
                            description:
                                _healthResult?.battery.sentence ??
                                (_loading
                                    ? 'Updating battery status'
                                    : 'No battery result'),
                            result: _healthResult?.battery,
                          ),
                          _buildMetricCard(
                            title: 'Thermal Health',
                            icon: Icons.device_thermostat,
                            value: _temperatureValue(),
                            description:
                                _healthResult?.heat.sentence ??
                                (_loading
                                    ? 'Updating thermal status'
                                    : 'No thermal result'),
                            result: _healthResult?.heat,
                          ),
                          _buildMetricCard(
                            title: 'Memory Health',
                            icon: Icons.memory,
                            value: _memoryValue(),
                            description: _memoryDescription(),
                            result: _healthResult?.memory,
                          ),
                          _buildMetricCard(
                            title: 'Storage Health',
                            icon: Icons.storage_rounded,
                            value: _storageValue(),
                            description:
                                _healthResult?.storage.sentence ??
                                (_loading
                                    ? 'Updating storage status'
                                    : 'No storage result'),
                            result: _healthResult?.storage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
