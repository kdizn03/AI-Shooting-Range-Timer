import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/constants.dart';
import '../../core/errors/failures.dart';
import '../audio/mel_spectrogram_preprocessor.dart';
import 'audio_classification.dart';
import 'audio_classifier.dart';
import 'energy_classifier.dart';

/// Implementation of [AudioClassifier] using `tflite_flutter`.
///
/// Loads the on-device TFLite model from assets. If the model file
/// is not found or fails to initialize, it automatically falls back
/// to [EnergyClassifier] so the application remains functional.
class TFLiteAudioClassifier implements AudioClassifier {
  Interpreter? _interpreter;
  bool _isReady = false;
  final EnergyClassifier _fallbackClassifier = EnergyClassifier();
  bool _useFallback = false;

  @override
  bool get isReady => _isReady;

  @override
  String get engineLabel => !_isReady
      ? 'Not loaded'
      : _useFallback
          ? 'Energy heuristic (model not bundled)'
          : 'TFLite model';

  @override
  Future<void> loadModel() async {
    try {
      _interpreter =
          await Interpreter.fromAsset(InferenceConstants.modelAssetPath);
      _isReady = true;
      _useFallback = false;
    } catch (e) {
      debugPrint(
          'Notice: TFLite model not loaded, using EnergyClassifier fallback: $e');
      _useFallback = true;
      _isReady = true;
    }
  }

  @override
  Future<AudioClassification> classify(Float32List features) async {
    if (!_isReady) {
      throw const ModelLoadException(
          'Model has not been loaded. Call loadModel() first.');
    }

    if (_useFallback) {
      return _fallbackClassifier.classify(features);
    }

    try {
      // Model input tensor shape: [1, 1, 40, 26]
      const int nMels = InferenceConstants.nMels;
      const int nFrames = MelSpectrogramPreprocessor.numFrames;

      final input = List.generate(
        1,
        (_) => List.generate(
          1,
          (_) => List.generate(
            nMels,
            (m) => List.generate(
              nFrames,
              (t) => (m * nFrames + t < features.length)
                  ? features[m * nFrames + t]
                  : 0.0,
            ),
          ),
        ),
      );

      final output = List.generate(1, (_) => List.filled(5, 0.0));
      _interpreter?.run(input, output);

      final List<double> probs = (output[0] as List).cast<double>();

      // Map outputs to AudioLabel
      final Map<AudioLabel, double> scores = {
        AudioLabel.gunshot: probs[0],
        AudioLabel.backgroundNoise: probs[1],
        AudioLabel.voice: probs[2],
        AudioLabel.otherLoudSound: probs[3],
        AudioLabel.beep: probs[4],
      };

      // Find highest score
      AudioLabel bestLabel = AudioLabel.backgroundNoise;
      double maxScore = -1.0;
      scores.forEach((label, score) {
        if (score > maxScore) {
          maxScore = score;
          bestLabel = label;
        }
      });

      return AudioClassification(
        label: bestLabel,
        confidence: maxScore,
        scores: scores,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw InvalidAudioFrameException('Failed to classify features: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _isReady = false;
  }
}
