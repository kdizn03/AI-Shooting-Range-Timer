import 'dart:async';

import '../../models/detection_zone.dart';
import '../../models/shot_event.dart';
import '../classifier/audio_classification.dart';
import 'detection_config.dart';

/// Engine that converts AI classifications into confirmed shot events.
///
/// Applies dual-stage gating:
/// 1. Decibel acoustic gate (ensuring peak dBFS meets firearm profile threshold).
/// 2. AI confidence thresholding and debounce/lockout logic to prevent
///    duplicate detections of the same gunshot.
///
/// Emits confirmed [ShotEvent]s through a stream.
/// The detector does NOT directly modify UI state.
class ShotDetector {
  /// Creates a [ShotDetector] with the given [config].
  ShotDetector({DetectionConfig? config})
      : _config = config ?? const DetectionConfig();

  final DetectionConfig _config;
  final StreamController<ShotEvent> _shotController =
      StreamController<ShotEvent>.broadcast();
  final StreamController<ZoneDecision> _zoneController =
      StreamController<ZoneDecision>.broadcast();
  int _zoneRejected = 0;
  int _zoneUncertain = 0;

  /// Every Detection Zone decision, for status displays.
  Stream<ZoneDecision> get zoneDecisions => _zoneController.stream;

  /// Sounds the Detection Zone filtered out this session.
  int get zoneRejectedCount => _zoneRejected;

  /// Events recorded as uncertain this session.
  int get zoneUncertainCount => _zoneUncertain;

  int _shotCount = 0;
  DateTime? _lastShotTime;
  DateTime? _sessionStartTime;
  bool _isActive = false;

  /// Stream of confirmed shot events.
  ///
  /// Subscribe to receive [ShotEvent]s whenever the detector
  /// confirms a gunshot classification.
  Stream<ShotEvent> get shotStream => _shotController.stream;

  /// Whether the detector is actively processing classifications.
  bool get isActive => _isActive;

  /// Number of confirmed shots in the current session.
  int get shotCount => _shotCount;

  /// The current detection configuration.
  DetectionConfig get config => _config;

  /// Starts the detector for a new session.
  ///
  /// [sessionStartTime] is the reference time (when the beep sounded)
  /// from which elapsed times are measured.
  void start(DateTime sessionStartTime) {
    _sessionStartTime = sessionStartTime;
    _shotCount = 0;
    _zoneRejected = 0;
    _zoneUncertain = 0;
    _lastShotTime = null;
    _pausedAt = null;
    _totalPaused = Duration.zero;
    _isActive = true;
  }

  /// Stops the detector.
  void stop() {
    _isActive = false;
  }

  DateTime? _pausedAt;
  Duration _totalPaused = Duration.zero;

  /// Whether detection is currently paused.
  bool get isPaused => _pausedAt != null;

  /// Total time spent paused so far in this session.
  Duration get totalPaused => _totalPaused;

  /// Pauses detection. Classifications received while paused are ignored,
  /// and the paused interval is excluded from subsequent elapsed times.
  ///
  /// [at] defaults to now; it is injectable for deterministic tests.
  void pause([DateTime? at]) {
    if (!_isActive || _pausedAt != null) return;
    _pausedAt = at ?? DateTime.now();
  }

  /// Resumes detection after [pause].
  void resume([DateTime? at]) {
    final DateTime? pausedAt = _pausedAt;
    if (pausedAt == null) return;
    final Duration gap = (at ?? DateTime.now()).difference(pausedAt);
    if (!gap.isNegative) _totalPaused += gap;
    _pausedAt = null;
  }

  /// Processes an [AudioClassification] result.
  ///
  /// If the classification meets the decibel gate, the AI confidence threshold,
  /// and passes debounce checks, a [ShotEvent] is emitted on [shotStream].
  ///
  /// Returns the [ShotEvent] if one was created, or `null` if the
  /// classification was rejected.
  ShotEvent? processClassification(AudioClassification classification) {
    if (!_isActive || _sessionStartTime == null) return null;
    if (_pausedAt != null) return null;

    // 1. Check if it's a gunshot with sufficient AI confidence.
    if (!classification.isGunshot) return null;
    if (classification.confidence < _config.confidenceThreshold) return null;

    // 2. Check decibel gate threshold (dBFS) for the selected firearm profile.
    if (classification.peakDbFs < _config.minPeakDbFs) return null;

    // 3. Check shot limit.
    if (_shotCount >= _config.maxShotsPerSession) return null;

    // 3b. Detection Zone. Runs before debounce, so a rejected distant sound
    // never locks out a nearby shot right after it.
    ZoneDecision? zone;
    if (_config.detectionZone == DetectionZone.nearField) {
      zone = NearFieldPolicy.evaluate(ZoneFeatures(
        peakDbFs: classification.peakDbFs,
        backgroundDbFs: classification.backgroundDbFs,
        directRatioDb: classification.directRatioDb,
      ));
      if (!_zoneController.isClosed) _zoneController.add(zone);
      if (zone.verdict == ZoneVerdict.rejected) {
        _zoneRejected++;
        return null;
      }
    }

    // 4. Check debounce lockout.
    final DateTime now = classification.timestamp;
    if (_lastShotTime != null) {
      final Duration elapsed = now.difference(_lastShotTime!);
      if (elapsed < _config.debounceDuration) return null;
    }

    // 5. Compute elapsed time with latency compensation.
    Duration elapsedTime = now.difference(_sessionStartTime!) - _totalPaused;
    elapsedTime -= _config.latencyCompensation;
    if (elapsedTime.isNegative) {
      elapsedTime = Duration.zero;
    }

    // 6. Create confirmed shot event with recorded decibels.
    _shotCount++;
    _lastShotTime = now;
    final bool uncertain = zone?.verdict == ZoneVerdict.uncertain;
    if (uncertain) _zoneUncertain++;

    final ShotEvent shot = ShotEvent(
      shotNumber: _shotCount,
      elapsedTime: elapsedTime,
      confidence: classification.confidence,
      detectionTimestamp: now,
      peakDecibels: classification.estimatedDbSpl,
      uncertain: uncertain,
      zoneNote: zone?.reason,
    );

    _shotController.add(shot);
    return shot;
  }

  /// Resets the detector state without stopping it.
  void reset() {
    _shotCount = 0;
    _lastShotTime = null;
    _sessionStartTime = null;
    _pausedAt = null;
    _totalPaused = Duration.zero;
    _isActive = false;
  }

  /// Releases resources.
  void dispose() {
    _shotController.close();
    _zoneController.close();
  }
}
