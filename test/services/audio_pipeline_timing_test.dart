import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/shot_event.dart';
import 'package:shot_timer_ai/services/audio/audio_pipeline.dart';
import 'package:shot_timer_ai/services/audio/audio_preprocessor.dart';
import 'package:shot_timer_ai/services/audio/level_analysis.dart';
import 'package:shot_timer_ai/services/classifier/audio_classification.dart';
import 'package:shot_timer_ai/services/classifier/audio_classifier.dart';
import 'package:shot_timer_ai/services/detection/detection_config.dart';
import 'package:shot_timer_ai/services/detection/shot_detector.dart';

import '../support/fake_audio_service.dart';

/// Preprocessing is irrelevant to timing, so features are empty.
class _FakePreprocessor implements AudioPreprocessor {
  @override
  Float32List processAudioFrame(Uint8List pcmData) => Float32List(1);

  @override
  Float32List pcmToFloat(Uint8List pcmData) => Float32List(1);

  @override
  Float32List computeLogMelSpectrogram(Float32List samples) => Float32List(1);
}

/// Labels every window as a gunshot. [delay] simulates slow inference.
class _SlowGunshotClassifier implements AudioClassifier {
  _SlowGunshotClassifier({this.delay = Duration.zero});

  final Duration delay;

  @override
  bool get isReady => true;

  @override
  String get engineLabel => 'Test classifier';

  @override
  Future<void> loadModel() async {}

  @override
  Future<AudioClassification> classify(Float32List features) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return AudioClassification(
      label: AudioLabel.gunshot,
      confidence: 0.95,
      scores: const {AudioLabel.gunshot: 0.95},
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> dispose() async {}
}

/// PCM16 buffer of [samples] zeros with a loud spike at each index in [spikes].
Uint8List _pcmWithSpikes(int samples, Map<int, int> spikes) {
  final ByteData d = ByteData(samples * 2);
  spikes.forEach((index, amplitude) {
    d.setInt16(index * 2, amplitude, Endian.little);
  });
  return d.buffer.asUint8List();
}

/// Runs a pipeline over one chunk containing two spikes, 5500 samples apart
/// (about 344 ms), and returns the two recorded event times.
Future<(Duration, Duration)> _runTwoSpikes(Duration classifierDelay) async {
  final FakeAudioService mic = FakeAudioService();
  final ShotDetector detector = ShotDetector(
    config: const DetectionConfig(
      minPeakDbFs: -30,
      debounceDurationMs: 100,
      inferenceLatencyCompensationMs: 0,
    ),
  )..start(DateTime.now().subtract(const Duration(seconds: 2)));
  final AudioPipeline pipeline = AudioPipeline(
    audioService: mic,
    audioPreprocessor: _FakePreprocessor(),
    audioClassifier: _SlowGunshotClassifier(delay: classifierDelay),
    shotDetector: detector,
  );
  final List<ShotEvent> shots = [];
  final sub = detector.shotStream.listen(shots.add);

  await pipeline.start();
  // Window 0 holds the first spike at sample 1000; window 1 holds the second
  // at sample 4000 + 2500 = 6500.
  mic.emit(_pcmWithSpikes(12000, {1000: 20000, 6500: 20000}));

  // Wait until both events are recorded (the classifier may be slow).
  for (int i = 0; i < 100 && shots.length < 2; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  await sub.cancel();
  await pipeline.dispose();
  detector.dispose();
  expect(shots, hasLength(2));
  return (shots[0].elapsedTime, shots[1].elapsedTime);
}

void main() {
  group('peakIndexFromPcm16', () {
    test('finds the sample index of the loudest value', () {
      final Uint8List pcm = _pcmWithSpikes(100, {37: 500, 81: -20000});
      expect(peakIndexFromPcm16(pcm), 81);
    });

    test('all-zero input returns index 0', () {
      expect(peakIndexFromPcm16(_pcmWithSpikes(50, {})), 0);
    });
  });

  test('event spacing matches the audio, with a fast classifier', () async {
    final (Duration a, Duration b) = await _runTwoSpikes(Duration.zero);
    final Duration spacing = b - a;
    // (6500 - 1000) samples / 16 kHz = 343.75 ms.
    expect((spacing.inMicroseconds - 343750).abs(), lessThan(2000));
  });

  test('a slow classifier does not move recorded event times', () async {
    final (Duration a, Duration b) =
        await _runTwoSpikes(const Duration(milliseconds: 150));
    final Duration spacing = b - a;
    expect((spacing.inMicroseconds - 343750).abs(), lessThan(2000),
        reason: 'times come from the audio, not from when processing finished');
  });
}
