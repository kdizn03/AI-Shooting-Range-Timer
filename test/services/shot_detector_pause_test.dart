import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/services/classifier/audio_classification.dart';
import 'package:shot_timer_ai/services/detection/detection_config.dart';
import 'package:shot_timer_ai/services/detection/shot_detector.dart';

AudioClassification _gunshot(DateTime t) => AudioClassification(
      label: AudioLabel.gunshot,
      confidence: 0.9,
      scores: const {AudioLabel.gunshot: 0.9},
      timestamp: t,
      peakDbFs: 0,
    );

void main() {
  group('ShotDetector pause/resume', () {
    late ShotDetector detector;
    final DateTime t0 = DateTime(2026, 1, 1, 12);

    setUp(() {
      detector = ShotDetector(
        config: const DetectionConfig(
          debounceDurationMs: 100,
          inferenceLatencyCompensationMs: 0,
        ),
      )..start(t0);
    });

    tearDown(() => detector.dispose());

    test('ignores classifications while paused', () {
      detector.pause(t0.add(const Duration(seconds: 1)));
      expect(detector.isPaused, isTrue);
      expect(
          detector.processClassification(_gunshot(t0.add(const Duration(seconds: 2)))),
          isNull);
      expect(detector.shotCount, 0);
    });

    test('excludes paused time from elapsed time after resume', () {
      detector.pause(t0.add(const Duration(seconds: 1)));
      detector.resume(t0.add(const Duration(seconds: 6))); // 5 s paused
      expect(detector.totalPaused, const Duration(seconds: 5));

      final shot = detector
          .processClassification(_gunshot(t0.add(const Duration(seconds: 8))));
      expect(shot, isNotNull);
      expect(shot!.elapsedTime, const Duration(seconds: 3));
    });

    test('accumulates multiple pauses', () {
      detector
        ..pause(t0.add(const Duration(seconds: 1)))
        ..resume(t0.add(const Duration(seconds: 2)))
        ..pause(t0.add(const Duration(seconds: 3)))
        ..resume(t0.add(const Duration(seconds: 5)));
      expect(detector.totalPaused, const Duration(seconds: 3));
    });

    test('pause is a no-op when not started, resume no-op when not paused', () {
      final ShotDetector idle = ShotDetector()..pause(t0);
      expect(idle.isPaused, isFalse);
      idle.dispose();

      detector.resume(t0.add(const Duration(seconds: 1)));
      expect(detector.totalPaused, Duration.zero);
    });

    test('start and reset clear paused state', () {
      detector
        ..pause(t0)
        ..resume(t0.add(const Duration(seconds: 2)));
      detector.start(t0);
      expect(detector.totalPaused, Duration.zero);
      expect(detector.isPaused, isFalse);
    });
  });
}
