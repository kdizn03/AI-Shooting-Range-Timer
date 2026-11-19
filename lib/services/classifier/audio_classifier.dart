import 'dart:typed_data';

import 'audio_classification.dart';

/// Abstract interface for audio classification using AI inference.
///
/// Implementations run a trained model (e.g., TFLite) to classify
/// audio segments into categories such as gunshot, background noise,
/// voice, etc.
///
/// The classifier does NOT directly modify UI state.
abstract class AudioClassifier {
  /// Whether the classifier model has been loaded and is ready.
  bool get isReady;

  /// Human-readable name of the inference engine actually in use, shown in
  /// audio status displays (e.g. "TFLite model", "Energy heuristic").
  String get engineLabel;

  /// Loads the AI model from assets and prepares for inference.
  ///
  /// Must be called before [classify]. Throws [ModelLoadException]
  /// if the model file cannot be loaded.
  Future<void> loadModel();

  /// Classifies preprocessed audio features.
  ///
  /// [features] is a [Float32List] containing the log-Mel spectrogram
  /// output from [AudioPreprocessor.processAudioFrame].
  ///
  /// Returns an [AudioClassification] with the predicted label
  /// and confidence scores.
  ///
  /// Throws [InvalidAudioFrameException] if [features] has an
  /// unexpected shape or contains invalid values.
  Future<AudioClassification> classify(Float32List features);

  /// Releases model resources.
  Future<void> dispose();
}

