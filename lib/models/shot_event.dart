import 'package:equatable/equatable.dart';

/// User review state of a detected event.
///
/// Detections are never assumed to be real shots: every event starts as
/// [unreviewed] and the shooter may confirm or reject it after the session.
enum ReviewStatus {
  /// Detected by the system, not yet reviewed by the user.
  unreviewed,

  /// User confirmed the detection was a real shot.
  confirmed,

  /// User rejected the detection as a false positive.
  rejected,
}

/// Represents a single detected gunshot event during a session.
///
/// Each [ShotEvent] records when a gunshot was detected relative to
/// the session start, along with the AI classifier's confidence score
/// and estimated sound pressure level in decibels (dB SPL).
class ShotEvent extends Equatable {
  /// Creates a new [ShotEvent].
  const ShotEvent({
    required this.shotNumber,
    required this.elapsedTime,
    required this.confidence,
    required this.detectionTimestamp,
    this.peakDecibels = 160.0,
    this.reviewStatus = ReviewStatus.unreviewed,
    this.uncertain = false,
    this.zoneNote,
  });

  /// The 1-indexed sequential shot number within the session.
  final int shotNumber;

  /// Time elapsed since the session started (since the starting beep).
  final Duration elapsedTime;

  /// AI classifier confidence score for this detection (0.0–1.0).
  ///
  /// A higher value indicates greater certainty that the audio event
  /// was a gunshot.
  final double confidence;

  /// Wall-clock timestamp when the shot was detected.
  final DateTime detectionTimestamp;

  /// Estimated sound pressure level in decibels (dB SPL) of the shot impulse.
  ///
  /// For example, unsuppressed 9mm (Glock 19) typically registers 155–167 dB,
  /// while suppressed 9mm registers 134–140 dB.
  final double peakDecibels;

  /// User review state for this detection.
  final ReviewStatus reviewStatus;

  /// The Detection Zone check could not decide; review this event.
  final bool uncertain;

  /// Why the Detection Zone check decided as it did, if it ran.
  final String? zoneNote;

  /// Whether the user rejected this detection as a false positive.
  bool get isRejected => reviewStatus == ReviewStatus.rejected;

  /// The interval from the previous shot, if applicable.
  ///
  /// Returns `null` for the first shot in a session. This should be
  /// computed by the caller using the previous shot's [elapsedTime].
  Duration? intervalFrom(ShotEvent? previousShot) {
    if (previousShot == null) return null;
    return elapsedTime - previousShot.elapsedTime;
  }

  /// Creates a copy of this [ShotEvent] with the given fields replaced.
  ShotEvent copyWith({
    int? shotNumber,
    Duration? elapsedTime,
    double? confidence,
    DateTime? detectionTimestamp,
    double? peakDecibels,
    ReviewStatus? reviewStatus,
    bool? uncertain,
    String? zoneNote,
  }) {
    return ShotEvent(
      shotNumber: shotNumber ?? this.shotNumber,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      confidence: confidence ?? this.confidence,
      detectionTimestamp: detectionTimestamp ?? this.detectionTimestamp,
      peakDecibels: peakDecibels ?? this.peakDecibels,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      uncertain: uncertain ?? this.uncertain,
      zoneNote: zoneNote ?? this.zoneNote,
    );
  }

  /// Serializes this [ShotEvent] to a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'shotNumber': shotNumber,
      'elapsedTimeMs': elapsedTime.inMilliseconds,
      'confidence': confidence,
      'detectionTimestamp': detectionTimestamp.toIso8601String(),
      'peakDecibels': peakDecibels,
      'reviewStatus': reviewStatus.name,
      if (uncertain) 'uncertain': true,
      if (zoneNote != null) 'zoneNote': zoneNote,
    };
  }

  /// Deserializes a [ShotEvent] from a JSON-compatible map.
  ///
  /// Records written before review support existed load as
  /// [ReviewStatus.unreviewed].
  factory ShotEvent.fromMap(Map<String, dynamic> map) {
    return ShotEvent(
      shotNumber: map['shotNumber'] as int,
      elapsedTime: Duration(milliseconds: map['elapsedTimeMs'] as int),
      confidence: (map['confidence'] as num).toDouble(),
      detectionTimestamp: DateTime.parse(map['detectionTimestamp'] as String),
      peakDecibels: (map['peakDecibels'] as num?)?.toDouble() ?? 160.0,
      reviewStatus: ReviewStatus.values.firstWhere(
        (r) => r.name == map['reviewStatus'],
        orElse: () => ReviewStatus.unreviewed,
      ),
      uncertain: map['uncertain'] == true,
      zoneNote: map['zoneNote'] is String ? map['zoneNote'] as String : null,
    );
  }

  @override
  List<Object?> get props => [
        shotNumber,
        elapsedTime,
        confidence,
        detectionTimestamp,
        peakDecibels,
        reviewStatus,
        uncertain,
        zoneNote,
      ];

  @override
  String toString() =>
      'ShotEvent(#$shotNumber, elapsed: ${elapsedTime.inMilliseconds}ms, '
      'dB: ${peakDecibels.toStringAsFixed(1)}, '
      'confidence: ${confidence.toStringAsFixed(3)}, '
      'review: ${reviewStatus.name})';
}
