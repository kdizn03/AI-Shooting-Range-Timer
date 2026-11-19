import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_classification.dart';
import 'audio_classifier.dart';

/// Heuristic-based fallback classifier.
///
/// Analyzes the transient peak and spectral distribution of the
/// log-Mel spectrogram when the TFLite model is not loaded.
///
/// Gunshots exhibit sharp, high-amplitude acoustic transients that
/// produce peak z-scores > 3.0 standard deviations in the spectrogram.
class EnergyClassifier implements AudioClassifier {
  bool _isReady = true;

  @override
  bool get isReady => _isReady;

  @override
  String get engineLabel => 'Energy heuristic';

  @override
  Future<void> loadModel() async {
    _isReady = true;
  }

  @override
  Future<AudioClassification> classify(Float32List features) async {
    if (features.isEmpty) {
      return AudioClassification(
        label: AudioLabel.backgroundNoise,
        confidence: 0.95,
        scores: const {
          AudioLabel.gunshot: 0.0,
          AudioLabel.backgroundNoise: 0.95,
          AudioLabel.voice: 0.02,
          AudioLabel.otherLoudSound: 0.02,
          AudioLabel.beep: 0.01,
        },
        timestamp: DateTime.now(),
      );
    }

    // Find peak value and energy distribution in normalized spectrogram
    double maxVal = features[0];
    double minVal = features[0];

    for (int i = 0; i < features.length; i++) {
      final double val = features[i];
      if (val > maxVal) maxVal = val;
      if (val < minVal) minVal = val;
    }

    final double range = maxVal - minVal;

    AudioLabel label;
    double confidence;

    // Transient peak analysis
    if (maxVal > 3.2 && range > 4.5) {
      // Strong sharp acoustic impulse characteristic of gunshot
      label = AudioLabel.gunshot;
      confidence = math.min(0.98, 0.75 + (maxVal - 3.2) * 0.08);
    } else if (maxVal > 2.4 && range > 3.5) {
      // Moderate loud sound (slam, clap, dropped object)
      label = AudioLabel.otherLoudSound;
      confidence = math.min(0.90, 0.70 + (maxVal - 2.4) * 0.1);
    } else if (maxVal > 1.8) {
      // Speech / vocalization formant pattern
      label = AudioLabel.voice;
      confidence = math.min(0.85, 0.65 + (maxVal - 1.8) * 0.1);
    } else {
      // Steady ambient environmental noise
      label = AudioLabel.backgroundNoise;
      confidence = 0.90;
    }

    // Distribute normalized softmax-like scores
    final Map<AudioLabel, double> scores = {
      AudioLabel.gunshot: label == AudioLabel.gunshot ? confidence : (1.0 - confidence) * 0.1,
      AudioLabel.backgroundNoise: label == AudioLabel.backgroundNoise ? confidence : (1.0 - confidence) * 0.3,
      AudioLabel.voice: label == AudioLabel.voice ? confidence : (1.0 - confidence) * 0.2,
      AudioLabel.otherLoudSound: label == AudioLabel.otherLoudSound ? confidence : (1.0 - confidence) * 0.3,
      AudioLabel.beep: (1.0 - confidence) * 0.1,
    };

    return AudioClassification(
      label: label,
      confidence: confidence,
      scores: scores,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> dispose() async {
    _isReady = false;
  }
}
