/// Application-wide constants for Shot Timer AI.
///
/// Centralizes magic numbers and configuration values used across
/// the audio pipeline, AI inference, and detection engine.
library;

/// Audio acquisition constants.
abstract final class AudioConstants {
  /// Sample rate for microphone audio capture in Hz.
  static const int sampleRate = 16000;

  /// Number of audio channels (mono).
  static const int channels = 1;

  /// Bit depth for PCM audio samples.
  static const int bitDepth = 16;

  /// Duration of each audio analysis window in milliseconds.
  static const int windowDurationMs = 250;

  /// Number of samples per analysis window.
  static int get windowSamples => (sampleRate * windowDurationMs) ~/ 1000;
}

/// AI inference constants.
abstract final class InferenceConstants {
  /// Number of Mel filter banks for spectrogram generation.
  static const int nMels = 40;

  /// FFT window size (number of samples).
  static const int nFft = 512;

  /// Hop length between successive FFT frames.
  static const int hopLength = 160;

  /// Name of the TFLite model asset file.
  static const String modelFileName = 'audio_classifier.tflite';

  /// Path to the model asset.
  static const String modelAssetPath = 'assets/models/$modelFileName';
}

/// Shot detection constants.
abstract final class DetectionConstants {
  /// Minimum confidence score (0.0–1.0) to classify audio as a gunshot.
  static const double defaultConfidenceThreshold = 0.7;

  /// Minimum time in milliseconds between consecutive shot detections.
  ///
  /// Prevents the same gunshot from being counted multiple times.
  static const int defaultDebounceDurationMs = 300;

  /// Maximum number of shots per session (safety limit).
  static const int maxShotsPerSession = 999;
}

/// Timing constants.
abstract final class TimingConstants {
  /// Timer tick interval for UI updates in milliseconds.
  static const int timerTickIntervalMs = 10;

  /// Estimated inference latency in milliseconds.
  ///
  /// Used to adjust detected shot timestamps to account for the
  /// delay between audio capture and classification result.
  static const int estimatedInferenceLatencyMs = 50;
}

