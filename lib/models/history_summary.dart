import 'session.dart';
import 'session_statistics.dart';

/// Aggregate metrics across stored sessions, computed only from recorded
/// data. Rejected detections and paused time are excluded (via
/// [SessionStatistics]).
class HistorySummary {
  HistorySummary._({
    required this.sessions,
    required this.stats,
    required this.totalDetections,
    required this.averageDuration,
    required this.averageSplit,
    required this.bestSplit,
    required this.simulatedCount,
  });

  /// Builds a summary of [all]. Simulated sessions are excluded unless
  /// [includeSimulated] is set.
  factory HistorySummary.from(
    List<Session> all, {
    bool includeSimulated = false,
    DateTime? since,
  }) {
    final List<Session> sessions = all
        .where((s) => includeSimulated || !s.isSimulated)
        .where((s) => since == null || !s.startTime.isBefore(since))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final List<SessionStatistics> stats =
        sessions.map(SessionStatistics.fromSession).toList(growable: false);

    int detections = 0;
    int durationMs = 0;
    int splitMsTotal = 0;
    int splitCount = 0;
    Duration? best;
    for (final SessionStatistics s in stats) {
      detections += s.totalShots;
      durationMs += s.sessionDuration.inMilliseconds;
      for (final Duration d in s.intervals) {
        splitMsTotal += d.inMilliseconds;
        splitCount++;
      }
      final Duration? f = s.fastestInterval;
      if (f != null && (best == null || f < best)) best = f;
    }

    return HistorySummary._(
      sessions: sessions,
      stats: stats,
      totalDetections: detections,
      averageDuration: sessions.isEmpty
          ? null
          : Duration(milliseconds: durationMs ~/ sessions.length),
      averageSplit: splitCount == 0
          ? null
          : Duration(milliseconds: splitMsTotal ~/ splitCount),
      bestSplit: best,
      simulatedCount: all.where((s) => s.isSimulated).length,
    );
  }

  /// Included sessions, oldest first.
  final List<Session> sessions;

  /// Statistics for each entry in [sessions] (same order).
  final List<SessionStatistics> stats;

  /// Counted (non-rejected) detections across included sessions.
  final int totalDetections;

  /// Mean active duration, or `null` with no sessions.
  final Duration? averageDuration;

  /// Mean split across every interval in included sessions.
  final Duration? averageSplit;

  /// Fastest split across included sessions.
  final Duration? bestSplit;

  /// Number of simulated sessions in the unfiltered input.
  final int simulatedCount;

  /// Number of included sessions.
  int get sessionCount => sessions.length;

  /// Whether no sessions are included.
  bool get isEmpty => sessions.isEmpty;

  /// Session counts per calendar day (or per 7-day block when [weekly]),
  /// from [start] through [end] inclusive, with empty buckets kept so the
  /// time axis is continuous.
  List<MapEntry<DateTime, int>> sessionsPerBucket({
    required DateTime start,
    required DateTime end,
    bool weekly = false,
  }) {
    final DateTime s = DateTime(start.year, start.month, start.day);
    final DateTime e = DateTime(end.year, end.month, end.day);
    final int step = weekly ? 7 : 1;
    final List<MapEntry<DateTime, int>> buckets = [];
    for (DateTime d = s; !d.isAfter(e); d = DateTime(d.year, d.month, d.day + step)) {
      final DateTime next = DateTime(d.year, d.month, d.day + step);
      final int n = sessions
          .where((x) => !x.startTime.isBefore(d) && x.startTime.isBefore(next))
          .length;
      buckets.add(MapEntry(d, n));
    }
    return buckets;
  }
}
