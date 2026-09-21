import 'package:equatable/equatable.dart';

/// Possible audio classification categories.
///
/// The AI classifier assigns one of these labels to each
/// analyzed audio segment.
enum AudioLabel {
  /// The sound of a firearm discharge.
  gunshot,

  /// Ambient environmental noise.
  backgroundNoise,

  /// Human speech or vocalization.
  voice,

  /// A loud sound that is not a gunshot (e.g., clap, slam).
  otherLoudSound,

  /// An electronic or mechanical beep signal.
  beep,
}

/// Result of classifying a single audio segment.
///
/// Contains the predicted label, confidence scores for all categories,
/// and acoustic decibel metrics (peak dBFS and estimated dB SPL).
class AudioClassification extends Equatable {
  /// Creates an [AudioClassification] result.
  const AudioClassification({
    required this.label,
    required this.confidence,
    required this.scores,
    required this.timestamp,
    this.peakDbFs = 0.0,
    this.estimatedDbSpl = 160.0,
  });

  /// The predicted class label with the highest score.
  final AudioLabel label;

  /// Confidence score for the predicted [label] (0.0–1.0).
  final double confidence;

  /// Confidence scores for all categories.
  ///
  /// Keys are [AudioLabel] values, values are scores (0.0–1.0)
  /// that sum to approximately 1.0.
  final Map<AudioLabel, double> scores;

  /// Wall-clock timestamp when classification was performed.
  final DateTime timestamp;

  /// Peak amplitude of the audio frame in decibels relative to full scale (-90.0 to 0.0 dBFS).
  final double peakDbFs;

  /// Estimated acoustic Sound Pressure Level (dB SPL) calibrated for firearm acoustics.
  final double estimatedDbSpl;

  /// Whether this classification predicts a gunshot.
  bool get isGunshot => label == AudioLabel.gunshot;

  /// Whether this classification predicts a beep.
  bool get isBeep => label == AudioLabel.beep;

  /// The gunshot confidence score, regardless of predicted label.
  double get gunshotScore => scores[AudioLabel.gunshot] ?? 0.0;

  @override
  List<Object?> get props => [
        label,
        confidence,
        scores,
        timestamp,
        peakDbFs,
        estimatedDbSpl,
      ];

  @override
  String toString() =>
      'AudioClassification(${label.name}, '
      'confidence: ${confidence.toStringAsFixed(3)}, '
      'dBFS: ${peakDbFs.toStringAsFixed(1)}, '
      'SPL: ${estimatedDbSpl.toStringAsFixed(1)} dB)';
}
