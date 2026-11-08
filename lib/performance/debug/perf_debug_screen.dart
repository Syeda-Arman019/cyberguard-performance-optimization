import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../perf_channel.dart';

/// TEMPORARY developer screen for the CyberGuard performance module.
///
/// It exists only so the foundation can be inspected on a real phone: which metrics this
/// device can measure, what the latest stored sample actually contains, and how many rows the
/// database holds. It will be replaced by the real five screens and is not part of the
/// shipped UI.
///
/// Honesty rules visible here:
///  - A value the phone did not report is shown as "Unavailable", never as 0.
///  - Metrics that need Usage Access say "Permission needed" and explain why.
///  - Every sample shows its real timestamp (WorkManager may run late, so the scheduled
///    time would be a lie).
///  - A data-quality hint appears whenever the results rest on very few samples.
///
/// Styling comes exclusively from Theme.of(context) - no hardcoded colours or fonts.
class PerfDebugScreen extends StatefulWidget {
  const PerfDebugScreen({super.key});

  @override
  State<PerfDebugScreen> createState() => _PerfDebugScreenState();
}

class _PerfDebugScreenState extends State<PerfDebugScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<Map<String, dynamic>> _capabilities = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _sample;
  Map<String, dynamic>? _deviceInfo;
  int _rowCount = 0;
  bool _usageAccessGranted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------------------

  /// Reads everything from the Android side. Any failure is shown on screen instead of
  /// thrown, so a missing channel (e.g. running on a desktop target) cannot crash the app.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final capabilities = await PerfChannel.getCapabilities();
      final sample = await PerfChannel.getLatestSample();
      final deviceInfo = await PerfChannel.getDeviceInfo();
      final samples = await PerfChannel.getSamples(sinceMillis: 0);
      final usageAccess = await PerfChannel.isUsageAccessGranted();

      if (!mounted) return;
      setState(() {
        _capabilities = capabilities;
        _sample = sample;
        _deviceInfo = deviceInfo;
        _rowCount = samples.length;
        _usageAccessGranted = usageAccess;
        _loading = false;
      });
    } on PlatformException catch (error) {
      _showError('The Android side reported an error: ${error.message ?? error.code}');
    } on MissingPluginException {
      _showError(
        'The native side is not registered. This screen only works in a running '
        'Android app build.',
      );
    } catch (error) {
      _showError('Could not read the performance data: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------------------

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _collectNow() {
    return _runBusy(() async {
      final stored = await PerfChannel.collectSampleNow();
      await _load();
      if (!mounted) return;
      _snack(
        stored == null
            ? 'No sample was stored: this phone did not report memory or storage, '
                'so nothing was written.'
            : 'Sample stored at ${_formatTimestamp(stored['timestamp'])}.',
      );
    });
  }

  Future<void> _exportCsv() {
    return _runBusy(() async {
      final path = await PerfChannel.exportSamplesCsv();
      if (!mounted) return;
      _snack(
        path == null
            ? 'The CSV file could not be written on this device.'
            : 'CSV saved to: $path',
      );
    });
  }

  Future<void> _copyReport() {
    return _runBusy(() async {
      await Clipboard.setData(ClipboardData(text: _buildReport()));
      if (!mounted) return;
      _snack('Capability report copied to the clipboard.');
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance debug'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) _ErrorCard(message: _error!),
                _SectionTitle('Device'),
                ..._deviceRows(),
                const SizedBox(height: 16),
                _SectionTitle('Actions'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _collectNow,
                      child: const Text('Collect now'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _exportCsv,
                      child: const Text('Export CSV'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _copyReport,
                      child: const Text('Copy capability report'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionTitle('Latest sample'),
                if (_sample == null)
                  _Body(
                    'Nothing has been sampled yet. Open the app once, or tap '
                    '"Collect now".',
                  ),
                ..._sampleRows(),
                const SizedBox(height: 16),
                _SectionTitle('Stored rows'),
                _InfoRow('Samples in database', '$_rowCount'),
                _Body(
                  _rowCount == 0
                      ? 'No samples yet: every finding in the finished screens will say '
                          'so rather than guessing.'
                      : _rowCount < 8
                          ? 'Data quality: only $_rowCount sample(s) (about '
                              '${(_rowCount * 15)} min of coverage at best). Treat any '
                              'result based on this as low confidence. A periodic sample is '
                              'taken every 15 minutes while the phone is awake.'
                          : 'Data quality: $_rowCount samples available.',
                ),
                const SizedBox(height: 16),
                _SectionTitle('Capabilities'),
                _Body(
                  'Checked at app start. A metric this phone cannot report is listed as '
                  'Unavailable, and it is never stored as 0.',
                ),
                ..._capabilityRows(theme),
                const SizedBox(height: 16),
                _SectionTitle('Usage Access'),
                _InfoRow(
                  'Status',
                  _usageAccessGranted ? 'Granted' : 'Permission needed',
                ),
                if (!_usageAccessGranted)
                  _Body(
                    'Without Usage Access the module keeps working in a degraded way: '
                    'battery, memory, storage and screen samples continue, but per-app '
                    'storage, network usage and usage events stay unavailable.',
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------------------
  // Families of rows
  // ---------------------------------------------------------------------------------------

  List<Widget> _deviceRows() {
    final info = _deviceInfo;
    if (info == null) {
      return <Widget>[
        _Body('Device information has not been recorded yet.'),
      ];
    }
    final sdk = _asInt(info['androidSdk']);
    return <Widget>[
      _InfoRow('Model', _asString(info['deviceModel'])),
      _InfoRow('Android', sdk == null ? 'Unavailable' : 'Android API $sdk'),
      _InfoRow('Total RAM', _asMb(info['totalRamMb'])),
      _InfoRow(
        'Design battery capacity',
        info['batteryCapacityMah'] == null
            ? 'Unavailable (Android has no public API for it)'
            : '${info['batteryCapacityMah']} mAh',
      ),
      _InfoRow('Recorded at', _formatTimestamp(info['recordedAt'])),
    ];
  }

  List<Widget> _sampleRows() {
    final sample = _sample;
    if (sample == null) return const <Widget>[];

    final thermal = _asInt(sample['thermalStatus']);
    final current = _asInt(sample['batteryCurrentUa']);
    final screen = sample['screenInteractive'] as bool?;
    final lowMemory = sample['lowMemory'] as bool?;

    return <Widget>[
      _InfoRow('Measured at', _formatTimestamp(sample['timestamp'])),
      _InfoRow('Battery level', _asPercent(sample['batteryPct'])),
      _InfoRow('Battery temperature', _asTemperature(sample['batteryTempC'])),
      _InfoRow('Charging state', _asString(sample['chargingState'])),
      _InfoRow('Plugged in via', _asString(sample['pluggedType'])),
      _InfoRow(
        'Battery current',
        current == null
            ? 'Unavailable'
            : 'raw $current (Android reports µA; some phones report mA)',
      ),
      _InfoRow(
        'Thermal status',
        thermal == null ? 'Unavailable' : _thermalStatusLabel(thermal),
      ),
      _InfoRow('Screen', screen == null ? 'Unavailable' : (screen ? 'On' : 'Off')),
      _InfoRow(
        'Memory',
        '${_asMb(sample['memAvailMb'])} free of ${_asMb(sample['memTotalMb'])}',
      ),
      _InfoRow(
        'Low memory flag',
        lowMemory == null ? 'Unavailable' : (lowMemory ? 'Yes' : 'No'),
      ),
      _InfoRow(
        'Storage (app partition)',
        '${_asGb(sample['storageFreeBytes'])} free of '
            '${_asGb(sample['storageTotalBytes'])}',
      ),
    ];
  }

  List<Widget> _capabilityRows(ThemeData theme) {
    if (_capabilities.isEmpty) {
      return <Widget>[
        _Body('The capability probe has not stored any result yet.'),
      ];
    }
    return _capabilities.map((capability) {
      final state = _asString(capability['state']);
      final reason = _asStringOrNull(capability['reason']);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _metricLabel(_asStringOrNull(capability['metricName'])),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (reason != null && reason.isNotEmpty)
                    Text(
                      reason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StateBadge(state: state, theme: theme),
          ],
        ),
      );
    }).toList(growable: false);
  }

  // ---------------------------------------------------------------------------------------
  // Copy report
  // ---------------------------------------------------------------------------------------

  /// Plain-text report for pasting into a bug report: device, Android version, and every
  /// capability state with its reason.
  String _buildReport() {
    final buffer = StringBuffer()
      ..writeln('CyberGuard performance - capability report')
      ..writeln('Device: ${_asString(_deviceInfo?['deviceModel'])}');

    final sdk = _asInt(_deviceInfo?['androidSdk']);
    buffer.writeln('Android: ${sdk == null ? 'unknown' : 'API $sdk'}');
    buffer.writeln('Usage Access: ${_usageAccessGranted ? 'granted' : 'not granted'}');
    buffer.writeln('Samples stored: $_rowCount');
    buffer.writeln('Capabilities:');

    for (final capability in _capabilities) {
      final name = _asStringOrNull(capability['metricName']) ?? 'unknown_metric';
      final state = _asString(capability['state']);
      final reason = _asStringOrNull(capability['reason']);
      buffer.writeln(
        '- $name: $state${reason == null || reason.isEmpty ? '' : ' ($reason)'}',
      );
    }
    return buffer.toString();
  }
}

// -------------------------------------------------------------------------------------------
// Small presentational helpers (theme-driven only)
// -------------------------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Label on the left, value on the right. Long values wrap instead of overflowing.
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Capability state chip. Colours come from the theme only; the label carries the meaning.
class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state, required this.theme});

  final String state;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    // Theme roles only: the badge text carries the state, colours just group it.
    final (Color background, Color foreground) = switch (state) {
      'AVAILABLE' => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      'PERMISSION_NEEDED' => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      'UNRELIABLE' => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        state,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
      ),
    );
  }
}

// -------------------------------------------------------------------------------------------
// Formatting helpers
//
// Everything here fails soft: a missing value becomes "Unavailable", never "0".
// -------------------------------------------------------------------------------------------

const String _unavailable = 'Unavailable';

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

String _asString(Object? value) {
  if (value == null) return _unavailable;
  final text = value.toString();
  return text.isEmpty ? _unavailable : text;
}

String? _asStringOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

String _asPercent(Object? value) {
  final number = _asInt(value);
  return number == null ? _unavailable : '$number %';
}

String _asTemperature(Object? value) {
  if (value is num) return '${value.toStringAsFixed(1)} °C';
  return _unavailable;
}

String _asMb(Object? value) {
  final number = _asInt(value);
  return number == null ? _unavailable : '$number MB';
}

String _asGb(Object? value) {
  final number = _asInt(value);
  if (number == null) return _unavailable;
  final gb = number / (1024 * 1024 * 1024);
  return '${gb.toStringAsFixed(2)} GB';
}

/// Human wording for PowerManager thermal status constants (0..6).
String _thermalStatusLabel(int status) {
  switch (status) {
    case 0:
      return 'None (0)';
    case 1:
      return 'Light (1)';
    case 2:
      return 'Moderate (2)';
    case 3:
      return 'Severe (3)';
    case 4:
      return 'Critical (4)';
    case 5:
      return 'Emergency (5)';
    case 6:
      return 'Shutdown (6)';
    default:
      return 'Unknown value ($status)';
  }
}

/// Readable metric names for the capability list.
String _metricLabel(String? metricName) {
  switch (metricName) {
    case 'battery_level':
      return 'Battery level';
    case 'battery_temperature':
      return 'Battery temperature';
    case 'battery_current_now':
      return 'Battery current';
    case 'thermal_status':
      return 'Thermal status';
    case 'memory_info':
      return 'Memory info';
    case 'storage_stats':
      return 'Storage stats';
    case 'screen_state':
      return 'Screen state';
    case 'per_app_storage_stats':
      return 'Per-app storage';
    case 'per_app_network_stats':
      return 'Per-app network';
    case 'usage_events':
      return 'App usage events';
    case 'usage_access':
      return 'Usage Access';
    default:
      return metricName ?? 'Unknown metric';
  }
}

/// Local time without the `intl` package (the module may not add Dart packages).
String _formatTimestamp(Object? value) {
  final millis = _asInt(value);
  if (millis == null) return _unavailable;
  final time = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
