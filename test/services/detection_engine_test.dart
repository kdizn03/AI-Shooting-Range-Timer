import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/app_settings.dart';
import 'package:shot_timer_ai/models/detection_engine.dart';
import 'package:shot_timer_ai/services/classifier/audio_classification.dart';
import 'package:shot_timer_ai/services/classifier/audio_classifier.dart';
import 'package:shot_timer_ai/services/classifier/classifier_factory.dart';
import 'package:shot_timer_ai/services/classifier/energy_classifier.dart';

class _BrokenClassifier implements AudioClassifier {
  bool disposed = false;

  @override
  bool get isReady => false;

  @override
  String get engineLabel => 'Broken';

  @override
  Future<void> loadModel() async => throw StateError('wasm blocked');

  @override
  Future<AudioClassification> classify(Float32List features) =>
      throw UnimplementedError();

  @override
  Future<void> dispose() async => disposed = true;
}

class _OkClassifier extends _BrokenClassifier {
  @override
  Future<void> loadModel() async {}
}

void main() {
  group('AppSettings detection engine', () {
    test('defaults to YAMNet with its own threshold', () {
      const AppSettings s = AppSettings();
      expect(s.detectionEngine, DetectionEngine.yamnet);
      expect(s.activeThreshold, DetectionEngine.yamnet.defaultThreshold);
      expect(s.thresholdFor(DetectionEngine.energy), 0.7);
    });

    test('each engine keeps its own threshold', () {
      final AppSettings s = const AppSettings()
          .withThreshold(DetectionEngine.yamnet, 0.3)
          .withThreshold(DetectionEngine.energy, 0.8);
      expect(s.thresholdFor(DetectionEngine.yamnet), 0.3);
      expect(s.thresholdFor(DetectionEngine.energy), 0.8);
      expect(s.copyWith(detectionEngine: DetectionEngine.energy).activeThreshold,
          0.8);
    });

    test('thresholds are clamped to the engine range', () {
      expect(
          const AppSettings()
              .withThreshold(DetectionEngine.yamnet, 2)
              .yamnetThreshold,
          DetectionEngine.yamnet.maxThreshold);
      expect(
          const AppSettings()
              .withThreshold(DetectionEngine.yamnet, double.nan)
              .yamnetThreshold,
          DetectionEngine.yamnet.defaultThreshold);
    });

    test('round-trips through toMap/fromMap', () {
      const AppSettings s = AppSettings(
        detectionEngine: DetectionEngine.energy,
        yamnetThreshold: 0.35,
      );
      expect(AppSettings.fromMap(s.toMap()), s);
    });

    test('older saved settings load with YAMNet defaults', () {
      final AppSettings s =
          AppSettings.fromMap(const {'confidenceThreshold': 0.8});
      expect(s.detectionEngine, DetectionEngine.yamnet);
      expect(s.yamnetThreshold, DetectionEngine.yamnet.defaultThreshold);
      expect(s.confidenceThreshold, 0.8);
    });

    test('invalid stored values fall back or clamp', () {
      final AppSettings s = AppSettings.fromMap(
          const {'detectionEngine': 'nope', 'yamnetThreshold': -4});
      expect(s.detectionEngine, DetectionEngine.yamnet);
      expect(s.yamnetThreshold, DetectionEngine.yamnet.minThreshold);
    });
  });

  group('loadAudioClassifier', () {
    test('energy engine loads the heuristic', () async {
      final LoadedClassifier l =
          await loadAudioClassifier(DetectionEngine.energy);
      expect(l.classifier, isA<EnergyClassifier>());
      expect(l.fallbackReason, isNull);
      expect(l.engineLabel, 'Energy heuristic');
    });

    test('YAMNet that loads is used as is', () async {
      final _OkClassifier ok = _OkClassifier();
      final LoadedClassifier l = await loadAudioClassifier(
          DetectionEngine.yamnet,
          createYamnet: () => ok);
      expect(l.classifier, same(ok));
      expect(l.fallbackReason, isNull);
    });

    test('YAMNet that fails falls back to the heuristic and says so',
        () async {
      final _BrokenClassifier broken = _BrokenClassifier();
      final LoadedClassifier l = await loadAudioClassifier(
          DetectionEngine.yamnet,
          createYamnet: () => broken);
      expect(l.classifier, isA<EnergyClassifier>());
      expect(l.fallbackReason, contains('wasm blocked'));
      expect(l.engineLabel, 'Energy heuristic (YAMNet unavailable)');
      expect(broken.disposed, isTrue);
    });
  });
}
