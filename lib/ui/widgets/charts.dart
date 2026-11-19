import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'panel.dart';

/// One data point in a single-series chart.
class ChartPoint {
  /// Creates a [ChartPoint].
  const ChartPoint(this.label, this.value, {this.detail});

  /// X-axis label (e.g. a date).
  final String label;

  /// Value; must be ≥ 0 for bar charts.
  final double value;

  /// Optional extra text for the readout (e.g. "4 sessions").
  final String? detail;
}

/// Chart form.
enum ChartKind { bar, line }

/// A titled chart card with a hover/tap readout and a table-view toggle.
///
/// Single series only: marks use steel blue; [highlightIndex] (e.g. the
/// fastest split) is drawn in lime and named in [highlightLabel] so it is
/// never identified by colour alone.
class AnalyticsChart extends StatefulWidget {
  /// Creates an [AnalyticsChart].
  const AnalyticsChart({
    super.key,
    required this.title,
    required this.points,
    required this.format,
    this.kind = ChartKind.bar,
    this.subtitle,
    this.highlightIndex,
    this.highlightLabel,
    this.height = 180,
    this.emptyMessage = 'Not enough data yet.',
    this.minPoints = 1,
  });

  final String title;
  final String? subtitle;
  final List<ChartPoint> points;

  /// Formats values for axis labels, the readout, and the table.
  final String Function(double) format;
  final ChartKind kind;
  final int? highlightIndex;
  final String? highlightLabel;
  final double height;
  final String emptyMessage;

  /// Minimum points required before the chart is drawn.
  final int minPoints;

  @override
  State<AnalyticsChart> createState() => _AnalyticsChartState();
}

class _AnalyticsChartState extends State<AnalyticsChart> {
  int? _selected;
  bool _table = false;

  @override
  void didUpdateWidget(AnalyticsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= widget.points.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ChartPoint> pts = widget.points;
    final bool enough = pts.length >= widget.minPoints &&
        pts.any((p) => p.value > 0);

    return Panel(
      title: widget.title,
      trailing: enough
          ? TextButton.icon(
              onPressed: () => setState(() => _table = !_table),
              icon: Icon(_table ? Icons.bar_chart : Icons.table_rows_outlined,
                  size: 16),
              label: Text(_table ? 'Chart' : 'Table'),
            )
          : null,
      child: !enough
          ? SizedBox(
              height: widget.height * 0.6,
              child: Center(
                child: Text(widget.emptyMessage,
                    style: AppType.bodySecondary,
                    textAlign: TextAlign.center),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.subtitle != null) ...[
                  Text(widget.subtitle!, style: AppType.caption),
                  const SizedBox(height: AppSpace.sm),
                ],
                if (_table) _buildTable(pts) else _buildChart(pts),
              ],
            ),
    );
  }

  Widget _buildChart(List<ChartPoint> pts) {
    final int shown = _selected ?? widget.highlightIndex ?? pts.length - 1;
    final ChartPoint p = pts[shown];
    final bool isHighlight = shown == widget.highlightIndex;
    final double maxV = pts.map((e) => e.value).reduce(math.max);
    double niceMax = _niceCeil(maxV);
    // Integer series (counts) get an even integer max so the midpoint
    // gridline label is a whole number too.
    if (pts.every((p) => p.value == p.value.roundToDouble())) {
      niceMax = math.max(2, (niceMax / 2).ceil() * 2).toDouble();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Readout: values in text ink; the mark beside it carries identity.
        Row(
          children: [
            Text(p.label, style: AppType.caption),
            const SizedBox(width: AppSpace.sm),
            Text(widget.format(p.value),
                style: AppType.monoBody.copyWith(fontWeight: FontWeight.w600)),
            if (p.detail != null) ...[
              const SizedBox(width: AppSpace.sm),
              Flexible(
                child: Text(p.detail!,
                    style: AppType.caption, overflow: TextOverflow.ellipsis),
              ),
            ],
            if (isHighlight && widget.highlightLabel != null) ...[
              const SizedBox(width: AppSpace.sm),
              Text(widget.highlightLabel!.toUpperCase(),
                  style: AppType.overline.copyWith(color: AppColors.accent)),
            ],
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Semantics(
          label: '${widget.title}. ${pts.length} points. '
              'Maximum ${widget.format(maxV)}. Use table view for all values.',
          child: SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, c) {
                const double axisW = 44;
                final double plotW = c.maxWidth - axisW;
                int? hit(Offset local) {
                  if (pts.isEmpty || plotW <= 0) return null;
                  final double x = (local.dx - axisW).clamp(0, plotW - 0.01);
                  return (x / plotW * pts.length).floor().clamp(0, pts.length - 1);
                }

                return MouseRegion(
                  onHover: (e) => setState(() => _selected = hit(e.localPosition)),
                  onExit: (_) => setState(() => _selected = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) =>
                        setState(() => _selected = hit(d.localPosition)),
                    onHorizontalDragUpdate: (d) =>
                        setState(() => _selected = hit(d.localPosition)),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(c.maxWidth, widget.height),
                        painter: _ChartPainter(
                          values: [for (final e in pts) e.value],
                          max: niceMax,
                          kind: widget.kind,
                          selected: _selected,
                          highlight: widget.highlightIndex,
                          axisWidth: axisW,
                          axisLabels: [
                            widget.format(0),
                            widget.format(niceMax / 2),
                            widget.format(niceMax),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Row(
            children: [
              Text(pts.first.label, style: AppType.monoCaption.copyWith(fontSize: 10)),
              const Spacer(),
              if (pts.length > 1)
                Text(pts.last.label,
                    style: AppType.monoCaption.copyWith(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<ChartPoint> pts) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.height + 40),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: pts.length,
        itemBuilder: (context, i) {
          final ChartPoint p = pts[i];
          return Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(p.label, style: AppType.body)),
                if (p.detail != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.md),
                    child: Text(p.detail!, style: AppType.caption),
                  ),
                Text(widget.format(p.value), style: AppType.monoBody),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _niceCeil(double v) {
    if (v <= 0) return 1;
    final double mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final double m in const [1, 2, 2.5, 5, 10]) {
      if (v <= m * mag) return m * mag;
    }
    return 10 * mag;
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.max,
    required this.kind,
    required this.selected,
    required this.highlight,
    required this.axisWidth,
    required this.axisLabels,
  });

  final List<double> values;
  final double max;
  final ChartKind kind;
  final int? selected;
  final int? highlight;
  final double axisWidth;
  final List<String> axisLabels;

  static const double _topPad = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final double plotW = size.width - axisWidth;
    final double plotH = size.height - _topPad;
    if (plotW <= 0 || values.isEmpty) return;

    // Recessive grid + y labels.
    final Paint grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final double y = _topPad + plotH - plotH * (i / 2);
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), grid);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: axisLabels[i],
          style: AppType.monoCaption.copyWith(fontSize: 10, color: AppColors.textMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: axisWidth - 6);
      tp.paint(canvas, Offset(axisWidth - 6 - tp.width, y - tp.height / 2));
    }

    final double slot = plotW / values.length;
    double yOf(double v) => _topPad + plotH - (v / max).clamp(0.0, 1.0) * plotH;

    if (selected != null) {
      canvas.drawRect(
        Rect.fromLTWH(axisWidth + slot * selected!, _topPad, slot, plotH),
        Paint()..color = AppColors.tint(AppColors.textPrimary, 0.04),
      );
    }

    Color colorFor(int i) {
      if (i == highlight) return AppColors.accent;
      if (selected != null && i != selected) {
        return AppColors.tint(AppColors.info, 0.55);
      }
      return AppColors.info;
    }

    if (kind == ChartKind.bar) {
      // Thin bars, 2px gap minimum, 4px rounded data end anchored at baseline.
      final double barW = math.max(2, math.min(28, slot - math.max(2, slot * 0.35)));
      for (int i = 0; i < values.length; i++) {
        if (values[i] <= 0) continue;
        final double cx = axisWidth + slot * i + slot / 2;
        final double top = yOf(values[i]);
        final double bottom = _topPad + plotH;
        final double r = math.min(4, barW / 2);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(cx - barW / 2, top, cx + barW / 2, bottom),
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r),
          ),
          Paint()..color = colorFor(i),
        );
      }
    } else {
      final Path path = Path();
      for (int i = 0; i < values.length; i++) {
        final Offset p = Offset(axisWidth + slot * i + slot / 2, yOf(values[i]));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.info
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
      for (int i = 0; i < values.length; i++) {
        final bool emph = i == selected || i == highlight;
        final Offset p = Offset(axisWidth + slot * i + slot / 2, yOf(values[i]));
        // Surface ring keeps overlapping markers distinct.
        canvas.drawCircle(p, emph ? 6 : 4.5, Paint()..color = AppColors.surface);
        canvas.drawCircle(p, emph ? 4.5 : 3, Paint()..color = colorFor(i));
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values ||
      old.max != max ||
      old.selected != selected ||
      old.highlight != highlight ||
      old.kind != kind;
}
