import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/shot_event.dart';
import 'package:shot_timer_ai/services/audio/audio_pipeline.dart';
import 'package:shot_timer_ai/services/audio/audio_preprocessor.dart';
import 'package:shot_timer_ai/services/classifier/audio_classification.dart';
import 'package:shot_timer_ai/services/classifier/waveform_classifier.dart';
import 'package:shot_timer_ai/services/detection/detection_config.dart';
import 'package:shot_timer_ai/services/detection/shot_detector.dart';

import '../support/fake_audio_service.dart';

class _UnusedPreprocessor implements AudioPreprocessor {
  @override
  Float32List processAudioFrame(Uint8List pcmData) =>
      throw StateError('waveform classifiers do not use spectrograms');

  @override
  Float32List pcmToFloat(Uint8List pcmData) => Float32List(0);

  @override
  Float32List computeLogMelSpectrogram(Float32List samples) => Float32List(0);
}

/// Records every clip it is given and calls each one a gunshot.
class _RecordingWaveformClassifier implements WaveformClassifier {
  final List<Float32List> clips = [];

  @override
  int get inputSamples => 15600;

  @override
  int get preRollSamples => 6400;

  @override
  bool get isReady => true;

  @override
  String get engineLabel => 'Fake YAMNet';

  @override
  Future<void> loadModel() async {}

  @override
  Future<AudioClassification> classifyWaveform(Float32List samples) async {
    clips.add(samples);
    return AudioClassification(
      label: AudioLabel.gunshot,
      confidence: 0.5,
      scores: const {AudioLabel.gunshot: 0.5},
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<AudioClassification> classify(Float32List features) =>
      throw StateError('classify must not be called for waveform classifiers');

  @override
  Future<void> dispose() async {}
}

Uint8List _pcm(int samples, Map<int, int> spikes) {
  final ByteData d = ByteData(samples * 2);
  spikes.forEach((i, v) => d.setInt16(i * 2, v, Endian.little));
  return d.buffer.asUint8List();
}

class _Rig {
  _Rig() {
    detector = ShotDetector(
      config: const DetectionConfig(
        minPeakDbFs: -30,
        confidenceThreshold: 0.15,
        debounceDurationMs: 100,
        inferenceLatencyCompensationMs: 0,
      ),
    )..start(DateTime.now().subtract(const Duration(seconds: 10)));
    pipeline = AudioPipeline(
      audioService: mic,
      audioPreprocessor: _UnusedPreprocessor(),
      audioClassifier: classifier,
      shotDetector: detector,
    );
    pipeline.classificationStream.listen(readings.add);
    detector.shotStream.listen(shots.add);
  }

  final FakeAudioService mic = FakeAudioService();
  final _RecordingWaveformClassifier classifier = _RecordingWaveformClassifier();
  late final ShotDetector detector;
  late final AudioPipeline pipeline;
  final List<AudioClassification> readings = [];
  final List<ShotEvent> shots = [];

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  Future<void> close() async {
    await pipeline.dispose();
    detector.dispose();
  }
}

void main() {
  test('only loud sounds are classified, each on ~1 s around its peak',
      () async {
    final _Rig r = _Rig();
    await r.pipeline.start();
    // Two loud spikes 8000 samples (500 ms) apart, one quiet one, and enough
    // audio after the last spike to complete its clip.
    r.mic.emit(_pcm(32000, {1000: 20000, 9000: -20000, 20000: 300}));
    await r.settle();

    expect(r.classifier.clips, hasLength(2));
    for (final Float32List clip in r.classifier.clips) {
      expect(clip, hasLength(15600));
    }
    // The peak sits at the pre-roll position in its clip.
    expect(r.classifier.clips[0][6400], closeTo(20000 / 32768, 1e-6));
    expect(r.classifier.clips[1][6400], closeTo(-20000 / 32768, 1e-6));
    // The first spike's clip starts before the stream: padded with silence.
    expect(r.classifier.clips[0][0], 0);

    expect(r.shots, hasLength(2));
    final Duration spacing = r.shots[1].elapsedTime - r.shots[0].elapsedTime;
    expect((spacing.inMicroseconds - 500000).abs(), lessThan(2000),
        reason: 'event times come from the peak samples');

    // Every 250 ms window still reports its level.
    expect(r.readings.where((c) => !c.analyzed), hasLength(8));
    expect(r.readings.where((c) => c.analyzed), hasLength(2));
    await r.close();
  });

  test('a sound waits for audio after its peak, and stop() flushes it',
      () async {
    final _Rig r = _Rig();
    await r.pipeline.start();
    r.mic.emit(_pcm(4000, {1000: 20000}));
    await r.settle();
    expect(r.classifier.clips, isEmpty,
        reason: 'only 3000 samples after the peak have arrived');

    await r.pipeline.stop();
    await r.settle(); // shot events are delivered asynchronously
    expect(r.classifier.clips, hasLength(1));
    expect(r.classifier.clips.single[6400], closeTo(20000 / 32768, 1e-6));
    // Audio after the stream ended is silence.
    expect(r.classifier.clips.single[15599], 0);
    expect(r.shots, hasLength(1));
    await r.close();
  });

  test('sounds below the gate and while paused are not classified', () async {
    final _Rig r = _Rig();
    await r.pipeline.start();
    r.mic.emit(_pcm(24000, {1000: 600})); // about -35 dBFS, under -30
    await r.settle();
    expect(r.classifier.clips, isEmpty);

    r.detector.pause();
    r.mic.emit(_pcm(24000, {1000: 20000}));
    await r.settle();
    expect(r.classifier.clips, isEmpty);
    expect(r.shots, isEmpty);
    await r.close();
  });
}
