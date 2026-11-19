import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'panel.dart';

/// A single metric: label, large monospace value, optional unit and caption.
class StatCard extends StatelessWidget {
  /// Creates a [StatCard].
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.unit,
    this.caption,
    this.highlight = false,
    this.compact = false,
  });

  final String label;

  /// The value; pass `'—'` when the metric is unavailable.
  final String value;
  final IconData? icon;

  /// Unit shown after the value in secondary colour (e.g. `s`, `dB`).
  final String? unit;

  /// Supporting text under the value.
  final String? caption;

  /// Render the value in the lime accent (reserve for the key metric).
  final bool highlight;

  /// Tighter padding and smaller value for dense grids.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextStyle valueStyle = AppType.metric.copyWith(
      fontSize: compact ? 20 : 26,
      color: highlight ? AppColors.accent : AppColors.textPrimary,
    );
    return Semantics(
      label: '$label: $value${unit != null ? ' $unit' : ''}'
          '${caption != null ? '. $caption' : ''}',
      excludeSemantics: true,
      child: Panel(
        padding: EdgeInsets.all(compact ? AppSpace.md : AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: AppType.overline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? AppSpace.sm : AppSpace.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: value,
                  style: valueStyle,
                  children: [
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: AppType.monoCaption.copyWith(fontSize: 13),
                      ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                caption!,
                style: AppType.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Previous name of [StatCard], kept for compatibility.
typedef StatisticsCard = StatCard;

/// Lays out [children] in equal-width columns, choosing as many columns as
/// fit at [minItemWidth] (capped at [maxColumns]).
class AdaptiveGrid extends StatelessWidget {
  /// Creates an [AdaptiveGrid].
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 160,
    this.maxColumns = 4,
    this.spacing = AppSpace.md,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        int cols = ((w + spacing) / (minItemWidth + spacing)).floor();
        cols = cols.clamp(1, maxColumns);
        // Rows of equal-height cells so cards align regardless of captions.
        final List<Widget> rows = [];
        for (int i = 0; i < children.length; i += cols) {
          if (i > 0) rows.add(SizedBox(height: spacing));
          rows.add(IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int j = 0; j < cols; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  Expanded(
                    child: i + j < children.length
                        ? children[i + j]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
