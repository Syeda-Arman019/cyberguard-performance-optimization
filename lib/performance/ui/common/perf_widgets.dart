import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'perf_status.dart';

/// Card with radius 20, used for each perf metric card.
class PerfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const PerfCard({required this.child, this.padding, this.margin, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

/// Status chip displaying a [PerfStatus] using colours from [ColorScheme].
class PerfChip extends StatelessWidget {
  final PerfStatus status;

  const PerfChip({required this.status, super.key});

  @override
  Widget build(BuildContext context) {
    final colour = status.getFromColorScheme(Theme.of(context).colorScheme);
    final label = status.label;

    return FilterChip(
      label: Text(label),
      selected: false,
      onSelected: (_) {},
      side: BorderSide(color: colour),
      color: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => colour,
      ),
    );
  }
}

/// Compact health metric card with an explicit status and penalty label.
class PerfMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String description;
  final PerfStatus status;
  final int? pointsLost;

  const PerfMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
    required this.status,
    required this.pointsLost,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = status.getFromColorScheme(theme.colorScheme);
    final statusLabel = pointsLost == null && status == PerfStatus.unavailable
        ? 'Unavailable'
        : status.label;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: CyberColors.cardGradient),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withAlpha(22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(icon, size: 21, color: color),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                pointsLost == null
                    ? 'No score yet'
                    : pointsLost == 0
                    ? 'No penalty detected'
                    : '$pointsLost points lost',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet showing detailed "Ye kaise pata chala" information.
void showPerfDetailsSheet(
  BuildContext context,
  String title,
  List<String> lines,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: MediaQuery.viewInsetsOf(context) + const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...lines.map((line) => Text(line)),
            ],
          ),
        ),
      );
    },
  );
}
