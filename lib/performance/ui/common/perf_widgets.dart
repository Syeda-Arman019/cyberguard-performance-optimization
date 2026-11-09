import 'package:flutter/material.dart';

import 'perf_status.dart';

/// Card with radius 20, used for each perf metric card.
class PerfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const PerfCard({
    required this.child,
    this.padding,
    this.margin,
    super.key,
  });

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

  const PerfChip({
    required this.status,
    super.key,
  });

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
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...lines.map((line) => Text(line)).toList(),
            ],
          ),
        ),
      );
    },
  );
}