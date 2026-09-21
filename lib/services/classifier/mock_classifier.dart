import 'dart:math';
import 'dart:typed_data';

import 'audio_classification.dart';
import 'audio_classifier.dart';

/// Mock implementation of [AudioClassifier] for development and testing.
///
/// Generates randomized classification results without requiring
/// an actual TFLite model. Useful for UI development and testing
/// the detection pipeline before the real model is available.
class MockClassifier implements AudioClassifier {
  /// Creates a [MockClassifier].
  ///
  /// [gunshotProbability] controls how often the mock predicts gunshot
  /// (0.0–1.0). Default is 0.1 (10% of the time).
  ///
  /// [latencyMs] simulates inference latency in milliseconds.
  MockClassifier({
    this.gunshotProbability = 0.1,
    this.latencyMs = 30,
  });

  /// Probability of generating a gunshot classification.
  final double gunshotProbability;

  /// Simulated inference latency in milliseconds.
  final int latencyMs;

  final Random _random = Random();
  bool _isReady = false;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> loadModel() async {
    // Simulate model loading time.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _isReady = true;
  }

  @override
  Future<AudioClassification> classify(Float32List features) async {
    if (!_isReady) {
      throw StateError('MockClassifier: model not loaded. Call loadModel().');
    }

    // Simulate inference latency.
    await Future<void>.delayed(Duration(milliseconds: latencyMs));

    // Generate mock scores.
    final bool isGunshot = _random.nextDouble() < gunshotProbability;
    final Map<AudioLabel, double> scores = _generateScores(isGunshot);
    final AudioLabel label = scores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return AudioClassification(
      label: label,
      confidence: scores[label]!,
      scores: scores,
      timestamp: DateTime.now(),
    );
  }

  Map<AudioLabel, double> _generateScores(bool biasGunshot) {
    final Map<AudioLabel, double> raw = {};
    double sum = 0;

    for (final AudioLabel label in AudioLabel.values) {
      double score;
      if (biasGunshot && label == AudioLabel.gunshot) {
        score = 0.7 + _random.nextDouble() * 0.3; // 0.7–1.0
      } else if (!biasGunshot && label == AudioLabel.backgroundNoise) {
        score = 0.5 + _random.nextDouble() * 0.4; // 0.5–0.9
      } else {
        score = _random.nextDouble() * 0.3; // 0.0–0.3
      }
      raw[label] = score;
      sum += score;
    }

    // Normalize to sum ≈ 1.0.
    return raw.map((key, value) => MapEntry(key, value / sum));
  }

  @override
  Future<void> dispose() async {
    _isReady = false;
  }
}

