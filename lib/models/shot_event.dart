import 'package:equatable/equatable.dart';

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
  }) {
    return ShotEvent(
      shotNumber: shotNumber ?? this.shotNumber,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      confidence: confidence ?? this.confidence,
      detectionTimestamp: detectionTimestamp ?? this.detectionTimestamp,
      peakDecibels: peakDecibels ?? this.peakDecibels,
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
    };
  }

  /// Deserializes a [ShotEvent] from a JSON-compatible map.
  factory ShotEvent.fromMap(Map<String, dynamic> map) {
    return ShotEvent(
      shotNumber: map['shotNumber'] as int,
      elapsedTime: Duration(milliseconds: map['elapsedTimeMs'] as int),
      confidence: (map['confidence'] as num).toDouble(),
      detectionTimestamp: DateTime.parse(map['detectionTimestamp'] as String),
      peakDecibels: (map['peakDecibels'] as num?)?.toDouble() ?? 160.0,
    );
  }

  @override
  List<Object?> get props => [
        shotNumber,
        elapsedTime,
        confidence,
        detectionTimestamp,
        peakDecibels,
      ];

  @override
  String toString() =>
      'ShotEvent(#$shotNumber, elapsed: ${elapsedTime.inMilliseconds}ms, '
      'dB: ${peakDecibels.toStringAsFixed(1)}, '
      'confidence: ${confidence.toStringAsFixed(3)})';
}
