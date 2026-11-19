import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format_utils.dart';
import '../../models/history_summary.dart';
import '../../models/session.dart';
import '../../models/session_statistics.dart';
import '../../providers/session_history_provider.dart';
import '../layout/page_scaffold.dart';
import '../navigation.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/panel.dart';
import '../widgets/state_views.dart';
import '../widgets/statistics_card.dart';

/// Analysis time window.
enum AnalyticsRange {
  week('7 days', 7),
  month('30 days', 30),
  quarter('90 days', 90),
  all('All time', null);

  const AnalyticsRange(this.label, this.days);
  final String label;
  final int? days;
}

/// Trends computed from stored sessions only.
///
/// Simulated sessions are excluded by default because their events are not
/// real detections.
class AnalyticsScreen extends ConsumerStatefulWidget {
  /// Creates an [AnalyticsScreen].
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsRange _range = AnalyticsRange.month;
  bool _includeSimulated = false;

  /// Maximum sessions plotted in per-session charts.
  static const int _maxBars = 24;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Session>> history = ref.watch(sessionHistoryProvider);

    return PageScaffold(
      title: 'Analytics',
      subtitle: 'Trends from your recorded sessions',
      slivers: [
        SliverSection(gap: AppSpace.lg, child: _filters()),
        ...history.when(
          loading: () => const [SliverSection(child: LoadingState())],
          error: (e, _) => [
            SliverSection(
              child: ErrorState(
                title: 'Could not load sessions',
                message: '$e',
                onRetry: () => ref.invalidate(sessionHistoryProvider),
              ),
            ),
          ],
          data: _content,
        ),
      ],
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<AnalyticsRange>(
          segments: [
            for (final r in AnalyticsRange.values)
              ButtonSegment(value: r, label: Text(r.label)),
          ],
          selected: {_range},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _range = s.first),
        ),
        Semantics(
          toggled: _includeSimulated,
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () => setState(() => _includeSimulated = !_includeSimulated),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _includeSimulated,
                    onChanged: (v) => setState(() => _includeSimulated = v),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  const Text('Include simulated', style: AppType.body),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _content(List<Session> all) {
    final DateTime now = DateTime.now();
    final DateTime? since = _range.days == null
        ? null
        : DateTime(now.year, now.month, now.day - (_range.days! - 1));
    final HistorySummary sum = HistorySummary.from(
      all,
      includeSimulated: _includeSimulated,
      since: since,
    );

    if (sum.isEmpty) {
      final bool onlySimulated =
          !_includeSimulated && all.isNotEmpty && all.every((s) => s.isSimulated);
      return [
        SliverSection(
          child: Panel(
            child: EmptyState(
              icon: Icons.insights_outlined,
              title: all.isEmpty ? 'No data yet' : 'No sessions in this range',
              message: all.isEmpty
                  ? 'Analytics appear after you complete sessions.'
                  : onlySimulated
                      ? 'All stored sessions are simulated. Turn on “Include simulated” to view them.'
                      : 'Choose a longer time range to see trends.',
              action: all.isEmpty
                  ? FilledButton.icon(
                      onPressed: () => AppNav.startNewSession(context),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start new session'),
                    )
                  : null,
            ),
          ),
        ),
      ];
    }

    // Sessions over time: daily buckets up to 30 days, weekly beyond.
    final DateTime first = since ?? sum.sessions.first.startTime;
    final bool weekly = now.difference(first).inDays > 31;
    final List<ChartPoint> activity = [
      for (final e in sum.sessionsPerBucket(start: first, end: now, weekly: weekly))
        ChartPoint(
          weekly ? 'Wk of ${Fmt.shortDate(e.key)}' : Fmt.shortDate(e.key),
          e.value.toDouble(),
          detail: '${e.value} session${e.value == 1 ? '' : 's'}',
        ),
    ];

    final int start =
        sum.sessions.length > _maxBars ? sum.sessions.length - _maxBars : 0;
    final List<Session> recent = sum.sessions.sublist(start);
    final List<SessionStatistics> recentStats = sum.stats.sublist(start);
    String sessionLabel(Session s) =>
        '${Fmt.shortDate(s.startTime)} ${Fmt.time(s.startTime)}';

    final List<ChartPoint> detections = [
      for (int i = 0; i < recent.length; i++)
        ChartPoint(sessionLabel(recent[i]), recentStats[i].totalShots.toDouble(),
            detail: Fmt.duration(recentStats[i].sessionDuration)),
    ];

    final List<ChartPoint> splitTrend = [];
    int? bestIdx;
    Duration? best;
    for (int i = 0; i < recent.length; i++) {
      final Duration? avg = recentStats[i].averageInterval;
      if (avg == null) continue;
      if (best == null || avg < best) {
        best = avg;
        bestIdx = splitTrend.length;
      }
      splitTrend.add(ChartPoint(sessionLabel(recent[i]), avg.inMilliseconds / 1000,
          detail: '${recentStats[i].totalShots} events'));
    }

    final List<ChartPoint> durations = [
      for (int i = 0; i < recent.length; i++)
        ChartPoint(sessionLabel(recent[i]),
            recentStats[i].sessionDuration.inMilliseconds / 1000),
    ];

    final Widget kpis = AdaptiveGrid(
      minItemWidth: 150,
      children: [
        StatCard(label: 'Sessions', value: '${sum.sessionCount}', icon: Icons.layers_outlined),
        StatCard(
            label: 'Detections',
            value: '${sum.totalDetections}',
            icon: Icons.graphic_eq,
            highlight: true),
        StatCard(
            label: 'Avg duration',
            value: sum.averageDuration == null ? '—' : Fmt.duration(sum.averageDuration!),
            icon: Icons.schedule),
        StatCard(
            label: 'Avg split',
            value: sum.averageSplit == null ? '—' : Fmt.split(sum.averageSplit!),
            icon: Icons.timer_outlined,
            caption: sum.bestSplit == null ? null : 'Best ${Fmt.split(sum.bestSplit!)}'),
      ],
    );

    final List<Widget> charts = [
      AnalyticsChart(
        title: 'Sessions over time',
        subtitle: weekly ? 'Sessions per week' : 'Sessions per day',
        points: activity,
        format: (v) => v.toStringAsFixed(0),
      ),
      AnalyticsChart(
        title: 'Detections per session',
        subtitle: 'Counted events (rejected excluded), last ${recent.length} sessions',
        points: detections,
        format: (v) => v.toStringAsFixed(0),
      ),
      AnalyticsChart(
        title: 'Average split trend',
        subtitle: 'Mean interval per session · lower is faster',
        kind: ChartKind.line,
        points: splitTrend,
        highlightIndex: bestIdx,
        highlightLabel: 'Best',
        format: (v) => '${v.toStringAsFixed(2)}s',
        minPoints: 2,
        emptyMessage: 'Needs at least two sessions with two or more counted events.',
      ),
      AnalyticsChart(
        title: 'Session duration',
        subtitle: 'Active time per session (pauses excluded)',
        points: durations,
        format: (v) => v >= 60 ? '${(v / 60).toStringAsFixed(1)}m' : '${v.toStringAsFixed(0)}s',
      ),
    ];

    return [
      SliverSection(child: kpis),
      SliverToBoxAdapter(
        child: LayoutBuilder(builder: (context, c) {
          final bool two = c.maxWidth >= 840;
          if (!two) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final w in charts) ...[w, const SizedBox(height: AppSpace.lg)],
              ],
            );
          }
          return Column(
            children: [
              for (int i = 0; i < charts.length; i += 2) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: charts[i]),
                    const SizedBox(width: AppSpace.lg),
                    Expanded(
                        child: i + 1 < charts.length
                            ? charts[i + 1]
                            : const SizedBox.shrink()),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
              ],
            ],
          );
        }),
      ),
      if (sum.simulatedCount > 0 && !_includeSimulated)
        SliverSection(
          child: Text(
            '${sum.simulatedCount} simulated session${sum.simulatedCount == 1 ? '' : 's'} excluded.',
            style: AppType.caption,
          ),
        ),
    ];
  }
}
