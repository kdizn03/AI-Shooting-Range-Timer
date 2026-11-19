import 'package:equatable/equatable.dart';

import '../../core/constants.dart';
import '../../models/detection_zone.dart';
import '../../models/firearm_profile.dart';

/// Configuration parameters for the shot detection engine.
///
/// Encapsulates tunable thresholds, decibel gates, and timing parameters
/// that control when an audio classification is accepted
/// as a confirmed gunshot.
class DetectionConfig extends Equatable {
  /// Creates a [DetectionConfig] with the given parameters.
  const DetectionConfig({
    this.confidenceThreshold = DetectionConstants.defaultConfidenceThreshold,
    this.debounceDurationMs = DetectionConstants.defaultDebounceDurationMs,
    this.maxShotsPerSession = DetectionConstants.maxShotsPerSession,
    this.inferenceLatencyCompensationMs =
        TimingConstants.estimatedInferenceLatencyMs,
    this.minPeakDbFs = -14.0,
    this.firearmProfile = FirearmProfile.glock19Unsuppressed,
    this.detectionZone = DetectionZone.standard,
  });

  /// Minimum confidence score (0.0–1.0) required to confirm a gunshot.
  final double confidenceThreshold;

  /// Minimum time in milliseconds between consecutive shot detections.
  ///
  /// Any detection within this window after a confirmed shot is
  /// discarded as a duplicate.
  final int debounceDurationMs;

  /// Maximum number of shots allowed in a single session.
  final int maxShotsPerSession;

  /// Milliseconds subtracted from detection time to compensate
  /// for inference pipeline latency.
  final int inferenceLatencyCompensationMs;

  /// Minimum digital peak level in dBFS (-90.0 to 0.0) required to register a shot.
  ///
  /// Gunshots produce intense acoustic shockwaves. For unsuppressed firearms
  /// (like Glock 19), this is typically >= -4 dBFS. For suppressed firearms,
  /// this is typically >= -14 dBFS.
  final double minPeakDbFs;

  /// The active firearm profile.
  final FirearmProfile firearmProfile;

  /// Extra filtering after the gate and threshold. Unsupported profiles
  /// (directional) behave as [DetectionZone.standard].
  final DetectionZone detectionZone;

  /// Duration representation of the debounce period.
  Duration get debounceDuration => Duration(milliseconds: debounceDurationMs);

  /// Duration representation of the latency compensation.
  Duration get latencyCompensation =>
      Duration(milliseconds: inferenceLatencyCompensationMs);

  /// Creates a copy with the given fields replaced.
  DetectionConfig copyWith({
    double? confidenceThreshold,
    int? debounceDurationMs,
    int? maxShotsPerSession,
    int? inferenceLatencyCompensationMs,
    double? minPeakDbFs,
    FirearmProfile? firearmProfile,
    DetectionZone? detectionZone,
  }) {
    return DetectionConfig(
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      debounceDurationMs: debounceDurationMs ?? this.debounceDurationMs,
      maxShotsPerSession: maxShotsPerSession ?? this.maxShotsPerSession,
      inferenceLatencyCompensationMs:
          inferenceLatencyCompensationMs ??
              this.inferenceLatencyCompensationMs,
      minPeakDbFs: minPeakDbFs ?? this.minPeakDbFs,
      firearmProfile: firearmProfile ?? this.firearmProfile,
      detectionZone: detectionZone ?? this.detectionZone,
    );
  }

  @override
  List<Object?> get props => [
        confidenceThreshold,
        debounceDurationMs,
        maxShotsPerSession,
        inferenceLatencyCompensationMs,
        minPeakDbFs,
        firearmProfile,
        detectionZone,
      ];
}
