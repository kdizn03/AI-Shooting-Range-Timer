import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/detection_zone.dart';
import 'package:shot_timer_ai/models/shot_event.dart';
import 'package:shot_timer_ai/services/audio/audio_pipeline.dart';
import 'package:shot_timer_ai/services/audio/audio_preprocessor.dart';
import 'package:shot_timer_ai/services/classifier/audio_classification.dart';
import 'package:shot_timer_ai/services/classifier/waveform_classifier.dart';
import 'package:shot_timer_ai/services/detection/detection_config.dart';
import 'package:shot_timer_ai/services/detection/shot_detector.dart';

import '../support/fake_audio_service.dart';

/// Calls every sound a gunshot, so only the gate and the Detection Zone
/// decide. Uses the waveform path (as YAMNet does), which has ~575 ms of
/// audio after each peak for the echo measurement.
class _AcceptAll implements WaveformClassifier {
  @override
  int get inputSamples => 15600;
  @override
  int get preRollSamples => 6400;
  @override
  bool get isReady => true;
  @override
  String get engineLabel => 'accept-all';
  @override
  Future<void> loadModel() async {}
  @override
  Future<AudioClassification> classifyWaveform(Float32List samples) async =>
      AudioClassification(
        label: AudioLabel.gunshot,
        confidence: 1,
        scores: const {AudioLabel.gunshot: 1},
        timestamp: DateTime.now(),
      );
  @override
  Future<AudioClassification> classify(Float32List features) =>
      throw UnimplementedError();
  @override
  Future<void> dispose() async {}
}

class _Pre implements AudioPreprocessor {
  @override
  Float32List processAudioFrame(Uint8List pcmData) => Float32List(1);
  @override
  Float32List pcmToFloat(Uint8List pcmData) => Float32List(1);
  @override
  Float32List computeLogMelSpectrogram(Float32List samples) => Float32List(1);
}

/// PCM16 data of a 16 kHz mono WAV fixture (44-byte header).
Uint8List _wavPcm(String name) {
  final Uint8List bytes =
      File('test/fixtures/audio/$name').readAsBytesSync();
  return Uint8List.sublistView(bytes, 44);
}

class _Run {
  final List<ZoneDecision> decisions = [];
  final List<ShotEvent> events = [];
  int get accepted => decisions.where((d) => d.verdict == ZoneVerdict.accepted).length;
  int get uncertain => decisions.where((d) => d.verdict == ZoneVerdict.uncertain).length;
  int get rejected => decisions.where((d) => d.verdict == ZoneVerdict.rejected).length;
}

Future<_Run> _run(String fixture, DetectionZone zone) async {
  final FakeAudioService mic = FakeAudioService();
  final ShotDetector detector = ShotDetector(
    config: DetectionConfig(
      minPeakDbFs: -30,
      confidenceThreshold: 0.15,
      debounceDurationMs: 300,
      inferenceLatencyCompensationMs: 0,
      detectionZone: zone,
    ),
  )..start(DateTime.now().subtract(const Duration(seconds: 30)));
  final AudioPipeline pipeline = AudioPipeline(
    audioService: mic,
    audioPreprocessor: _Pre(),
    audioClassifier: _AcceptAll(),
    shotDetector: detector,
  );
  final _Run run = _Run();
  detector.zoneDecisions.listen(run.decisions.add);
  detector.shotStream.listen(run.events.add);
  await pipeline.start();

  // Feed the recording in 100 ms chunks, as a microphone would.
  final Uint8List pcm = _wavPcm(fixture);
  for (int i = 0; i < pcm.length; i += 3200) {
    mic.emit(Uint8List.sublistView(pcm, i, i + 3200 > pcm.length ? pcm.length : i + 3200));
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await pipeline.stop();
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await pipeline.dispose();
  detector.dispose();
  return run;
}

void main() {
  // Fixtures: a public-domain gunshot recording (Wikimedia Commons,
  // "Gunshots 8.ogg") with a 3 s -50 dBFS noise lead-in, and a controlled
  // distant-sounding version of it (-14 dB, high frequencies rolled off,
  // 0.9 s reverb). See test/fixtures/audio/README.md.
  test('near recording: every main shot is accepted', () async {
    final _Run r = await _run('gunshots_near_16k.wav', DetectionZone.nearField);
    // The main reports are the candidates far above background.
    final List<ZoneDecision> mainShots = r.decisions
        .where((d) => (d.features.snrDb ?? 0) > 40)
        .toList();
    expect(mainShots, hasLength(greaterThanOrEqualTo(6)));
    expect(mainShots.every((d) => d.verdict == ZoneVerdict.accepted), isTrue,
        reason: mainShots.map((d) => d.reason).join('; '));
    expect(r.accepted, greaterThanOrEqualTo(10));
    expect(r.rejected, lessThanOrEqualTo(2),
        reason: 'only echo-like secondary peaks may be rejected');
    expect(r.events.where((e) => e.uncertain), hasLength(lessThanOrEqualTo(1)));
  });

  test('distant version: nothing is accepted', () async {
    final _Run r =
        await _run('gunshots_distant_16k.wav', DetectionZone.nearField);
    expect(r.decisions, isNotEmpty);
    expect(r.accepted, 0);
    expect(r.rejected, greaterThanOrEqualTo(r.decisions.length * 2 ~/ 3));
    // Whatever is recorded is flagged for review, never confirmed.
    expect(r.events.every((e) => e.uncertain), isTrue);
  });

  test('standard detection records the same distant audio unfiltered',
      () async {
    final _Run r =
        await _run('gunshots_distant_16k.wav', DetectionZone.standard);
    expect(r.decisions, isEmpty);
    expect(r.events, isNotEmpty);
    expect(r.events.any((e) => e.uncertain), isFalse);
  });
}
