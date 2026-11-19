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
    this.analyzed = true,
    this.backgroundDbFs,
    this.directRatioDb,
  });

  /// A level-only reading for a window the classifier did not examine,
  /// used when the classifier only runs on sounds that pass the gate.
  /// [label] and [confidence] carry no meaning; check [analyzed].
  const AudioClassification.levelOnly({
    required this.timestamp,
    required this.peakDbFs,
    this.estimatedDbSpl = 160.0,
    this.backgroundDbFs,
  })  : label = AudioLabel.backgroundNoise,
        confidence = 0,
        scores = const {},
        analyzed = false,
        directRatioDb = null;

  /// The predicted class label with the highest score.
  final AudioLabel label;

  /// Confidence score for the predicted [label] (0.0–1.0).
  final double confidence;

  /// Confidence scores for all categories.
  ///
  /// Keys are [AudioLabel] values, values are scores (0.0–1.0). For the
  /// energy heuristic they sum to about 1.0; YAMNet scores are independent.
  final Map<AudioLabel, double> scores;

  /// Wall-clock time the sound occurred.
  ///
  /// Set by the audio pipeline from the sample position of the window's peak,
  /// so it does not depend on how long processing took.
  final DateTime timestamp;

  /// Peak amplitude of the audio frame in decibels relative to full scale (-90.0 to 0.0 dBFS).
  final double peakDbFs;

  /// Estimated acoustic Sound Pressure Level (dB SPL) calibrated for firearm acoustics.
  final double estimatedDbSpl;

  /// Whether a classifier examined this audio. `false` for level-only
  /// readings (see [AudioClassification.levelOnly]).
  final bool analyzed;

  /// Live background-noise estimate when this audio arrived (dBFS), if known.
  final double? backgroundDbFs;

  /// Direct-to-tail energy ratio around the peak (dB), if measurable.
  /// See `directToTailRatioDb`.
  final double? directRatioDb;

  /// Returns a copy with the pipeline's timing and signal measurements.
  AudioClassification withMeasurements({
    required DateTime timestamp,
    required double peakDbFs,
    required double estimatedDbSpl,
    double? backgroundDbFs,
    double? directRatioDb,
  }) =>
      AudioClassification(
        label: label,
        confidence: confidence,
        scores: scores,
        timestamp: timestamp,
        peakDbFs: peakDbFs,
        estimatedDbSpl: estimatedDbSpl,
        analyzed: analyzed,
        backgroundDbFs: backgroundDbFs,
        directRatioDb: directRatioDb,
      );

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
        analyzed,
        backgroundDbFs,
        directRatioDb,
      ];

  @override
  String toString() =>
      'AudioClassification(${label.name}, '
      'confidence: ${confidence.toStringAsFixed(3)}, '
      'dBFS: ${peakDbFs.toStringAsFixed(1)}, '
      'SPL: ${estimatedDbSpl.toStringAsFixed(1)} dB)';
}
