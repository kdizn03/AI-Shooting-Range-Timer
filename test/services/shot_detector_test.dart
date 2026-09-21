import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/services/classifier/audio_classification.dart';
import 'package:shot_timer_ai/services/detection/detection_config.dart';
import 'package:shot_timer_ai/services/detection/shot_detector.dart';

/// Helper to create an [AudioClassification] for testing.
AudioClassification _makeClassification({
  AudioLabel label = AudioLabel.gunshot,
  double confidence = 0.9,
  required DateTime timestamp,
  double peakDbFs = 0.0,
  double estimatedDbSpl = 160.0,
}) {
  final scores = <AudioLabel, double>{};
  for (final l in AudioLabel.values) {
    scores[l] = l == label
        ? confidence
        : (1 - confidence) / (AudioLabel.values.length - 1);
  }
  return AudioClassification(
    label: label,
    confidence: confidence,
    scores: scores,
    timestamp: timestamp,
    peakDbFs: peakDbFs,
    estimatedDbSpl: estimatedDbSpl,
  );
}

void main() {
  group('ShotDetector', () {
    late ShotDetector detector;
    final tTime = DateTime(2023, 1, 1, 12, 0, 0);

    setUp(() {
      detector = ShotDetector(
        config: const DetectionConfig(
          confidenceThreshold: 0.7,
          debounceDurationMs: 100,
          maxShotsPerSession: 5,
          inferenceLatencyCompensationMs: 50,
          minPeakDbFs: -14.0,
        ),
      );
    });

    tearDown(() {
      detector.dispose();
    });

    test('not active before start', () {
      expect(detector.isActive, isFalse);
      expect(detector.shotCount, 0);
    });

    test('returns null when not active', () {
      final result = detector.processClassification(
        _makeClassification(timestamp: tTime.add(const Duration(seconds: 1))),
      );
      expect(result, isNull);
    });

    test('gunshot above threshold is detected', () {
      detector.start(tTime);
      final event = detector.processClassification(
        _makeClassification(
          confidence: 0.8,
          timestamp: tTime.add(const Duration(seconds: 1)),
        ),
      );
      expect(event, isNotNull);
      expect(event!.shotNumber, 1);
      expect(event.confidence, 0.8);
      expect(detector.shotCount, 1);
    });

    test('gunshot below threshold is rejected', () {
      detector.start(tTime);
      final event = detector.processClassification(
        _makeClassification(
          confidence: 0.6,
          timestamp: tTime.add(const Duration(seconds: 1)),
        ),
      );
      expect(event, isNull);
      expect(detector.shotCount, 0);
    });

    test('non-gunshot classification is rejected', () {
      detector.start(tTime);
      final event = detector.processClassification(
        _makeClassification(
          label: AudioLabel.backgroundNoise,
          confidence: 0.9,
          timestamp: tTime.add(const Duration(seconds: 1)),
        ),
      );
      expect(event, isNull);
      expect(detector.shotCount, 0);
    });

    test('debounce prevents duplicate within window', () {
      detector.start(tTime);

      final event1 = detector.processClassification(
        _makeClassification(
          timestamp: tTime.add(const Duration(seconds: 1)),
        ),
      );
      final event2 = detector.processClassification(
        _makeClassification(
          timestamp: tTime.add(const Duration(seconds: 1, milliseconds: 50)),
        ),
      );

      expect(event1, isNotNull);
      expect(event2, isNull);
      expect(detector.shotCount, 1);
    });

    test('debounce allows shot after window expires', () {
      detector.start(tTime);

      final event1 = detector.processClassification(
        _makeClassification(
          timestamp: tTime.add(const Duration(seconds: 1)),
        ),
      );
      final event2 = detector.processClassification(
        _makeClassification(
          timestamp: tTime.add(const Duration(seconds: 1, milliseconds: 150)),
        ),
      );

      expect(event1, isNotNull);
      expect(event2, isNotNull);
      expect(detector.shotCount, 2);
    });

    test('maxShotsPerSession limit enforced', () {
      detector.start(tTime);

      for (int i = 0; i < 5; i++) {
        final e = detector.processClassification(
          _makeClassification(
            timestamp: tTime.add(Duration(seconds: i + 1)),
          ),
        );
        expect(e, isNotNull);
      }
      expect(detector.shotCount, 5);

      final extra = detector.processClassification(
        _makeClassification(
          timestamp: tTime.add(const Duration(seconds: 10)),
        ),
      );
      expect(extra, isNull);
      expect(detector.shotCount, 5);
    });

    test('shot numbering is sequential', () {
      detector.start(tTime);

      final e1 = detector.processClassification(
        _makeClassification(timestamp: tTime.add(const Duration(seconds: 1))),
      );
      final e2 = detector.processClassification(
        _makeClassification(timestamp: tTime.add(const Duration(seconds: 2))),
      );

      expect(e1?.shotNumber, 1);
      expect(e2?.shotNumber, 2);
    });

    test('latency compensation adjusts elapsed time', () {
      detector.start(tTime);

      final event = detector.processClassification(
        _makeClassification(
          timestamp: tTime.add(const Duration(seconds: 1)),
        ),
      );

      // Elapsed: 1000ms - 50ms latency compensation = 950ms
      expect(event?.elapsedTime.inMilliseconds, 950);
    });

    test('gunshot rejected if below decibel gate threshold', () {
      final unsuppressedDetector = ShotDetector(
        config: const DetectionConfig(
          confidenceThreshold: 0.7,
          minPeakDbFs: -4.0, // Glock 19 unsuppressed gate
        ),
      );
      unsuppressedDetector.start(tTime);

      // Gunshot with high AI confidence, but below decibel threshold
      final event = unsuppressedDetector.processClassification(
        _makeClassification(
          confidence: 0.99,
          peakDbFs: -10.0,
          timestamp: tTime.add(const Duration(seconds: 1)),
        ),
      );

      expect(event, isNull);
      expect(unsuppressedDetector.shotCount, 0);
    });

    test(
        'suppressed firearm profile detects quieter shots that unsuppressed profile rejects',
        () {
      final unsuppressedDetector = ShotDetector(
        config: const DetectionConfig(
          confidenceThreshold: 0.7,
          minPeakDbFs: -4.0, // Glock 19 unsuppressed: -4 dBFS
        ),
      );
      final suppressedDetector = ShotDetector(
        config: const DetectionConfig(
          confidenceThreshold: 0.7,
          minPeakDbFs: -14.0, // Glock 19 suppressed: -14 dBFS
        ),
      );

      unsuppressedDetector.start(tTime);
      suppressedDetector.start(tTime);

      // A suppressed gunshot around -8 dBFS (~137 dB SPL)
      final classification = _makeClassification(
        confidence: 0.92,
        peakDbFs: -8.0,
        estimatedDbSpl: 137.0,
        timestamp: tTime.add(const Duration(seconds: 1)),
      );

      // Unsuppressed rejects it because -8 dBFS < -4 dBFS
      expect(
          unsuppressedDetector.processClassification(classification), isNull);

      // Suppressed accepts it because -8 dBFS >= -14 dBFS
      final shot = suppressedDetector.processClassification(classification);
      expect(shot, isNotNull);
      expect(shot!.peakDecibels, 137.0);
    });

    test('shotStream emits events', () async {
      detector.start(tTime);

      final events = <dynamic>[];
      detector.shotStream.listen(events.add);

      detector.processClassification(
        _makeClassification(
          timestamp: tTime.add(const Duration(seconds: 1)),
        ),
      );

      // Allow stream to propagate
      await Future<void>.delayed(Duration.zero);

      expect(events, isNotEmpty);
      expect(events.first.shotNumber, 1);
    });

    test('reset clears state', () {
      detector.start(tTime);
      detector.processClassification(
        _makeClassification(timestamp: tTime.add(const Duration(seconds: 1))),
      );
      expect(detector.shotCount, 1);

      detector.reset();
      expect(detector.shotCount, 0);
      expect(detector.isActive, isFalse);
    });
  });
}
