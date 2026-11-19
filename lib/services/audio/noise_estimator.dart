import 'dart:math' as math;

import 'level_analysis.dart';

/// Rolling background-noise estimate from 250 ms window peak levels.
///
/// The estimate is a low percentile ([quantile], 10th by default, matching
/// calibration) of recent *ambient* windows. Windows that look like events
/// do not enter the history:
/// - windows the caller marks as candidates (above the detection gate),
/// - windows more than [eventMarginDb] above the current estimate,
/// - the [tailWindows] windows after either of those (echo and decay).
///
/// So a shot cannot drag the estimate up. If the surroundings really do get
/// louder and stay that way, the excluded run ends after [adaptAfterWindows]
/// and the estimate follows.
///
/// Until [minWindows] ambient windows are seen, [estimate] returns [seed]
/// (for example a saved calibration for the microphone), or null.
class BackgroundNoiseEstimator {
  BackgroundNoiseEstimator({
    this.seed,
    this.capacity = 80,
    this.minWindows = 8,
    this.quantile = 0.10,
    this.eventMarginDb = 15,
    this.tailWindows = 2,
    this.adaptAfterWindows = 40,
  });

  /// Value used before enough windows have been measured.
  final double? seed;

  /// History length in windows (80 × 250 ms = 20 s).
  final int capacity;
  final int minWindows;
  final double quantile;
  final double eventMarginDb;
  final int tailWindows;
  final int adaptAfterWindows;

  final List<double> _history = <double>[];
  int _tailLeft = 0;
  int _excludedRun = 0;
  double? _estimate;

  /// Current estimate in dBFS, or null when unknown.
  double? get estimate => _estimate ?? seed;

  /// Whether [estimate] comes from live audio (not the seed).
  bool get isLive => _estimate != null;

  /// Number of ambient windows in the history.
  int get windowCount => _history.length;

  /// Adds one window. [isCandidate] marks a window that passed the gate.
  void add(double dbFs, {bool isCandidate = false}) {
    if (!dbFs.isFinite) return;
    final double v = math.max(dbFs, kSilenceFloorDbFs);
    final double? current = estimate;
    final bool eventLike =
        isCandidate || (current != null && v > current + eventMarginDb);

    if (eventLike || _tailLeft > 0) {
      if (eventLike) {
        _tailLeft = tailWindows;
      } else {
        _tailLeft--;
      }
      _excludedRun++;
      if (_excludedRun < adaptAfterWindows || isCandidate) return;
      // Loud for a long time without being a candidate: the surroundings
      // changed. Let these windows in so the estimate catches up.
    } else {
      _excludedRun = 0;
    }

    _history.add(v);
    if (_history.length > capacity) _history.removeAt(0);
    if (_history.length >= minWindows) {
      _estimate = percentile(_history, quantile);
    }
  }

  /// Clears live measurements; [seed] still applies.
  void reset() {
    _history.clear();
    _tailLeft = 0;
    _excludedRun = 0;
    _estimate = null;
  }
}
