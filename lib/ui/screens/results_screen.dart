import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format_utils.dart';
import '../../models/detection_zone.dart';
import '../../models/session.dart';
import '../../models/session_statistics.dart';
import '../../models/shot_event.dart';
import '../../providers/session_history_provider.dart';
import '../layout/page_scaffold.dart';
import '../navigation.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/panel.dart';
import '../widgets/shot_list_tile.dart';
import '../widgets/state_views.dart';
import '../widgets/statistics_card.dart';
import '../widgets/status_tag.dart';

/// Summary and review of a finished session.
///
/// Every metric is computed from recorded event timestamps. Rejected
/// events are excluded from statistics; review changes are saved
/// immediately to session storage.
class ResultsScreen extends ConsumerStatefulWidget {
  final Session session;

  /// Whether saving the session failed when it ended.
  final bool saveFailed;

  const ResultsScreen({
    super.key,
    required this.session,
    this.saveFailed = false,
  });

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  late Session _session = widget.session;

  /// The session's Detection Zone profile, if it was recorded.
  DetectionZone? get _zone {
    final String? name = _session.detectionZone;
    for (final DetectionZone z in DetectionZone.values) {
      if (z.name == name) return z;
    }
    return null;
  }
  late bool _unsaved = widget.saveFailed;
  bool _saving = false;

  Future<void> _persist(Session updated) async {
    setState(() {
      _session = updated;
      _saving = true;
    });
    try {
      await ref.read(sessionHistoryControllerProvider).save(updated);
      if (mounted) setState(() => _unsaved = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _unsaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save changes: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _review(int index, ReviewStatus status) {
    final List<ShotEvent> shots = [..._session.shots];
    shots[index] = shots[index].copyWith(reviewStatus: status);
    _persist(_session.copyWith(shots: shots));
  }

  void _reviewAll(ReviewStatus status) {
    _persist(_session.copyWith(
      shots: [
        for (final s in _session.shots)
          s.isRejected ? s : s.copyWith(reviewStatus: status),
      ],
    ));
  }

  Future<void> _delete() async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete session?',
      message: 'This permanently removes the session from ${Fmt.dateTime(_session.startTime)} '
          'and its ${_session.shotCount} events. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(sessionHistoryControllerProvider).delete(_session.id);
      if (mounted) AppNav.backToShell(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionStatistics stats = SessionStatistics.fromSession(_session);
    final List<ShotEvent> shots = _session.shots;
    final int unreviewed =
        shots.where((s) => s.reviewStatus == ReviewStatus.unreviewed).length;

    // Splits are measured from the previous counted (non-rejected) event,
    // matching how statistics are computed.
    final List<Duration?> splits = [];
    Duration? prev;
    int? fastestIndex;
    for (int i = 0; i < shots.length; i++) {
      final Duration split = shots[i].elapsedTime - (prev ?? Duration.zero);
      splits.add(split);
      if (!shots[i].isRejected) {
        if (prev != null &&
            stats.fastestInterval != null &&
            split == stats.fastestInterval &&
            fastestIndex == null) {
          fastestIndex = i;
        }
        prev = shots[i].elapsedTime;
      }
    }

    String fmtOr(Duration? d) => d == null ? '—' : Fmt.split(d);

    final Widget header = Panel(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SESSION', style: AppType.overline),
          const SizedBox(height: AppSpace.xs),
          Text(Fmt.dateTime(_session.startTime), style: AppType.title),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              StatusTag(label: _session.firearmProfile.displayName, icon: Icons.tune),
              _session.isSimulated
                  ? const StatusTag(
                      label: 'Simulated', tone: Tone.info, icon: Icons.science_outlined)
                  : const StatusTag(label: 'Live microphone', icon: Icons.mic),
              if (_session.confidenceThreshold != null)
                StatusTag(
                    label: 'Threshold ${Fmt.percent(_session.confidenceThreshold!)}',
                    icon: Icons.filter_alt_outlined),
              if (_session.inputLabel != null)
                StatusTag(label: _session.inputLabel!, icon: Icons.mic_none),
              if (_zone != null && _zone != DetectionZone.standard)
                StatusTag(label: _zone!.label, icon: Icons.radar),
              if (_session.zoneFilteredCount > 0)
                StatusTag(
                    label: '${_session.zoneFilteredCount} filtered by zone',
                    tone: Tone.info,
                    icon: Icons.filter_list),
              if (_session.pausedDuration > Duration.zero)
                StatusTag(
                    label: 'Paused ${Fmt.duration(_session.pausedDuration)} (excluded)',
                    tone: Tone.warning,
                    icon: Icons.pause),
            ],
          ),
        ],
      ),
    );

    final Widget statGrid = AdaptiveGrid(
      minItemWidth: 140,
      maxColumns: 4,
      spacing: AppSpace.sm,
      children: [
        StatCard(
            compact: true,
            label: 'Detections',
            value: '${stats.totalShots}',
            highlight: true,
            caption: stats.rejectedShots > 0
                ? '${stats.rejectedShots} rejected'
                : null),
        StatCard(
            compact: true,
            label: 'Duration',
            value: Fmt.duration(stats.sessionDuration)),
        StatCard(
            compact: true,
            label: 'First event',
            value: fmtOr(stats.firstShotTime),
            caption: 'From beep'),
        StatCard(
            compact: true,
            label: 'Avg split',
            value: fmtOr(stats.averageInterval)),
        StatCard(
            compact: true, label: 'Fastest', value: fmtOr(stats.fastestInterval)),
        StatCard(
            compact: true, label: 'Slowest', value: fmtOr(stats.slowestInterval)),
        StatCard(
            compact: true,
            label: 'Avg confidence',
            value: stats.averageConfidence == null
                ? '—'
                : Fmt.percent(stats.averageConfidence!),
            caption: 'Classifier score'),
        StatCard(
            compact: true,
            label: 'Est. peak level',
            value: stats.maxDecibels == null
                ? '—'
                : stats.maxDecibels!.toStringAsFixed(0),
            unit: stats.maxDecibels == null ? null : 'dB',
            caption: 'Estimated, uncalibrated'),
      ],
    );

    final Widget reviewSummary = Panel(
      title: 'Review',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              StatusTag(
                  label: '${stats.confirmedShots} confirmed',
                  tone: Tone.accent,
                  icon: Icons.check_circle_outline),
              StatusTag(
                  label: '${stats.rejectedShots} rejected',
                  tone: Tone.error,
                  icon: Icons.block),
              StatusTag(
                  label: '$unreviewed unreviewed', icon: Icons.graphic_eq),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            _session.isSimulated
                ? 'These events were generated by simulation mode, not detected from audio.'
                : 'Detections are automatic and may include false positives. Reject '
                    'any that were not shots — rejected events are excluded from all '
                    'statistics and analytics.',
            style: AppType.caption,
          ),
          if (unreviewed > 0) ...[
            const SizedBox(height: AppSpace.md),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _reviewAll(ReviewStatus.confirmed),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Confirm all remaining'),
            ),
          ],
        ],
      ),
    );

    final List<ChartPoint> splitPoints = [];
    int? splitHighlight;
    {
      Duration? p;
      int n = 0;
      for (final ShotEvent s in shots) {
        if (s.isRejected) continue;
        n++;
        if (p != null) {
          final Duration d = s.elapsedTime - p;
          if (d == stats.fastestInterval && splitHighlight == null) {
            splitHighlight = splitPoints.length;
          }
          splitPoints.add(ChartPoint('#${n - 1}→#$n', d.inMilliseconds / 1000));
        }
        p = s.elapsedTime;
      }
    }

    final Widget splitChart = AnalyticsChart(
      title: 'Split times',
      subtitle: 'Interval between consecutive counted events',
      points: splitPoints,
      format: (v) => '${v.toStringAsFixed(2)}s',
      highlightIndex: splitHighlight,
      highlightLabel: 'Fastest',
      minPoints: 1,
      emptyMessage: 'Split times need at least two counted events.',
    );

    final Widget events = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
            child: Row(
              children: [
                const Expanded(
                    child: Text('EVENT TIMELINE', style: AppType.overline)),
                if (_saving)
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                if (_saving) const SizedBox(width: AppSpace.sm),
                Text('${shots.length} events', style: AppType.caption),
              ],
            ),
          ),
          const Divider(),
          if (shots.isEmpty)
            EmptyState(
              compact: true,
              icon: Icons.hearing,
              title: 'No events detected',
              message: _session.isSimulated
                  ? 'The session ended before any simulated event.'
                  : 'Nothing passed the decibel gate and confidence threshold. '
                      'If shots were fired, try a lower threshold or a quieter '
                      'firearm profile.',
            )
          else
            for (int i = 0; i < shots.length; i++)
              DetectionEventItem(
                key: ValueKey(shots[i].shotNumber),
                shot: shots[i],
                interval: splits[i],
                threshold: _session.confidenceThreshold,
                simulated: _session.isSimulated,
                isFastest: i == fastestIndex,
                onReview: _saving ? null : (s) => _review(i, s),
              ),
        ],
      ),
    );

    final Widget? notice = _unsaved
        ? InlineNotice(
            icon: Icons.warning_amber,
            color: AppColors.warning,
            message: 'This session has not been saved to history.',
            action: TextButton(
              onPressed: _saving ? null : () => _persist(_session),
              child: const Text('Retry save'),
            ),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: const Text('Session results'),
        actions: [
          IconButton(
            tooltip: 'Delete session',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: AppSpace.xs),
        ],
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
        children: [
          ContentWidth(
            child: LayoutBuilder(builder: (context, c) {
              final List<Widget> summary = [
                if (notice != null) ...[notice, const SizedBox(height: AppSpace.lg)],
                header,
                const SizedBox(height: AppSpace.lg),
                statGrid,
                const SizedBox(height: AppSpace.lg),
                reviewSummary,
                const SizedBox(height: AppSpace.lg),
                splitChart,
              ];
              if (c.maxWidth >= 960) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: summary),
                    ),
                    const SizedBox(width: AppSpace.xl),
                    Expanded(flex: 6, child: events),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...summary,
                  const SizedBox(height: AppSpace.lg),
                  events,
                ],
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceSunken,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: ContentWidth(
              maxWidth: 720,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNav.backToShell(context),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56)),
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        AppNav.backToShell(context);
                        AppNav.startNewSession(context);
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('New session'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
