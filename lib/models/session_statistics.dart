import 'package:equatable/equatable.dart';

import 'session.dart';
import 'shot_event.dart';

/// Computed statistics for a completed shooting session.
///
/// Calculates aggregate metrics from the session's shot events
/// including intervals, averages, extremes, and decibel sound pressure metrics.
class SessionStatistics extends Equatable {
  /// Creates [SessionStatistics] with pre-computed values.
  const SessionStatistics({
    required this.totalShots,
    required this.sessionDuration,
    required this.intervals,
    this.averageInterval,
    this.fastestInterval,
    this.slowestInterval,
    this.firstShotTime,
    this.avgDecibels,
    this.maxDecibels,
    this.averageConfidence,
    this.rejectedShots = 0,
    this.confirmedShots = 0,
  });

  /// Computes statistics from a [Session].
  ///
  /// The [Session] should be completed or at least have an [endTime].
  /// If the session has no shots, interval and decibel metrics will be `null`.
  ///
  /// Detections the user has rejected are excluded from every metric, and
  /// [sessionDuration] excludes paused time.
  factory SessionStatistics.fromSession(Session session) {
    final List<ShotEvent> shots = session.countedShots;
    final Duration sessionDuration = session.activeDuration;
    final int totalShots = shots.length;
    final int rejected = session.shots.length - totalShots;
    final int confirmed =
        shots.where((s) => s.reviewStatus == ReviewStatus.confirmed).length;

    if (totalShots == 0) {
      return SessionStatistics(
        totalShots: 0,
        sessionDuration: sessionDuration,
        intervals: const [],
        rejectedShots: rejected,
      );
    }

    // First shot time relative to session start
    final Duration firstShotTime = shots.first.elapsedTime;

    // Calculate intervals between consecutive shots
    final List<Duration> intervals = <Duration>[];
    for (int i = 1; i < shots.length; i++) {
      intervals.add(shots[i].elapsedTime - shots[i - 1].elapsedTime);
    }

    Duration? averageInterval;
    Duration? fastestInterval;
    Duration? slowestInterval;

    if (intervals.isNotEmpty) {
      final int totalIntervalMs = intervals.fold<int>(
        0,
        (sum, d) => sum + d.inMilliseconds,
      );
      averageInterval =
          Duration(milliseconds: totalIntervalMs ~/ intervals.length);
      fastestInterval = intervals.reduce(
        (a, b) => a < b ? a : b,
      );
      slowestInterval = intervals.reduce(
        (a, b) => a > b ? a : b,
      );
    }

    // Calculate decibel metrics
    double totalDb = 0.0;
    double maxDb = shots.first.peakDecibels;
    for (final shot in shots) {
      totalDb += shot.peakDecibels;
      if (shot.peakDecibels > maxDb) {
        maxDb = shot.peakDecibels;
      }
    }
    final double avgDb = totalDb / shots.length;
    final double avgConfidence =
        shots.fold<double>(0, (sum, s) => sum + s.confidence) / shots.length;

    return SessionStatistics(
      totalShots: totalShots,
      sessionDuration: sessionDuration,
      intervals: intervals,
      averageInterval: averageInterval,
      fastestInterval: fastestInterval,
      slowestInterval: slowestInterval,
      firstShotTime: firstShotTime,
      avgDecibels: avgDb,
      maxDecibels: maxDb,
      averageConfidence: avgConfidence,
      rejectedShots: rejected,
      confirmedShots: confirmed,
    );
  }

  /// Total number of shots detected.
  final int totalShots;

  /// Total duration of the session.
  final Duration sessionDuration;

  /// List of intervals between consecutive shots.
  ///
  /// Empty if there are fewer than 2 shots.
  final List<Duration> intervals;

  /// Average time between consecutive shots.
  ///
  /// `null` if there are fewer than 2 shots.
  final Duration? averageInterval;

  /// Shortest interval between consecutive shots.
  ///
  /// `null` if there are fewer than 2 shots.
  final Duration? fastestInterval;

  /// Longest interval between consecutive shots.
  ///
  /// `null` if there are fewer than 2 shots.
  final Duration? slowestInterval;

  /// Time from session start to the first shot.
  ///
  /// `null` if there are no shots.
  final Duration? firstShotTime;

  /// Average sound pressure level across all detected shots (dB SPL).
  final double? avgDecibels;

  /// Highest sound pressure level recorded among all detected shots (dB SPL).
  final double? maxDecibels;

  /// Mean classifier confidence across counted detections.
  final double? averageConfidence;

  /// Number of detections the user rejected (excluded from all metrics).
  final int rejectedShots;

  /// Number of counted detections the user explicitly confirmed.
  final int confirmedShots;

  /// Whether this session has any shot data.
  bool get hasShots => totalShots > 0;

  /// Whether interval statistics are available.
  bool get hasIntervals => intervals.isNotEmpty;

  @override
  List<Object?> get props => [
        totalShots,
        sessionDuration,
        intervals,
        averageInterval,
        fastestInterval,
        slowestInterval,
        firstShotTime,
        avgDecibels,
        maxDecibels,
        averageConfidence,
        rejectedShots,
        confirmedShots,
      ];

  @override
  String toString() =>
      'SessionStatistics(shots: $totalShots, duration: $sessionDuration, '
      'avgDb: ${avgDecibels?.toStringAsFixed(1)}, maxDb: ${maxDecibels?.toStringAsFixed(1)})';
}
