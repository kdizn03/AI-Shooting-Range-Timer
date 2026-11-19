import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:shot_timer_ai/models/detection_zone.dart';
import 'package:shot_timer_ai/models/microphone.dart';
import 'package:shot_timer_ai/models/shot_event.dart';
import 'package:shot_timer_ai/services/audio/audio_pipeline.dart';
import 'package:shot_timer_ai/services/audio/audio_preprocessor.dart';
import 'package:shot_timer_ai/services/audio/microphone_manager.dart';
import 'package:shot_timer_ai/services/classifier/audio_classification.dart';
import 'package:shot_timer_ai/services/classifier/audio_classifier.dart';
import 'package:shot_timer_ai/services/detection/detection_config.dart';
import 'package:shot_timer_ai/services/detection/shot_detector.dart';

import '../support/fake_audio_service.dart';

AudioClassification _gunshot(DateTime t,
        {double peak = -2, double? bg, double? dtr}) =>
    AudioClassification(
      label: AudioLabel.gunshot,
      confidence: 0.9,
      scores: const {AudioLabel.gunshot: 0.9},
      timestamp: t,
      peakDbFs: peak,
      backgroundDbFs: bg,
      directRatioDb: dtr,
    );

ShotDetector _detector(DetectionZone zone) => ShotDetector(
      config: DetectionConfig(
        minPeakDbFs: -30,
        debounceDurationMs: 300,
        inferenceLatencyCompensationMs: 0,
        detectionZone: zone,
      ),
    );

class _Pre implements AudioPreprocessor {
  @override
  Float32List processAudioFrame(Uint8List pcmData) => Float32List(1);
  @override
  Float32List pcmToFloat(Uint8List pcmData) => Float32List(1);
  @override
  Float32List computeLogMelSpectrogram(Float32List samples) => Float32List(1);
}

class _AlwaysGunshot implements AudioClassifier {
  @override
  bool get isReady => true;
  @override
  String get engineLabel => 'test';
  @override
  Future<void> loadModel() async {}
  @override
  Future<AudioClassification> classify(Float32List features) async =>
      _gunshot(DateTime.now());
  @override
  Future<void> dispose() async {}
}

Uint8List _pcm(int samples, {int level = 0, Map<int, int> spikes = const {}}) {
  final ByteData d = ByteData(samples * 2);
  for (int i = 0; i < samples; i++) {
    d.setInt16(i * 2, i.isEven ? level : -level, Endian.little);
  }
  spikes.forEach((i, v) => d.setInt16(i * 2, v, Endian.little));
  return d.buffer.asUint8List();
}

void main() {
  group('ShotDetector with a detection zone', () {
    final DateTime t0 = DateTime(2026, 1, 1, 12);

    test('standard ignores signal measurements entirely', () {
      final ShotDetector d = _detector(DetectionZone.standard)..start(t0);
      final ShotEvent? e = d.processClassification(_gunshot(
          t0.add(const Duration(seconds: 1)), bg: -5, dtr: 1));
      expect(e, isNotNull);
      expect(e!.uncertain, isFalse);
      expect(e.zoneNote, isNull);
      d.dispose();
    });

    test('near-field accepts, flags and rejects by measurement', () {
      final ShotDetector d = _detector(DetectionZone.nearField)..start(t0);
      final List<ZoneDecision> decisions = [];
      d.zoneDecisions.listen(decisions.add);

      final ShotEvent? near = d.processClassification(
          _gunshot(t0.add(const Duration(seconds: 1)), bg: -42, dtr: 14));
      final ShotEvent? distant = d.processClassification(
          _gunshot(t0.add(const Duration(seconds: 2)), bg: -22, dtr: 5));
      final ShotEvent? mid = d.processClassification(
          _gunshot(t0.add(const Duration(seconds: 3)), bg: -31, dtr: 9));

      expect(near, isNotNull);
      expect(near!.uncertain, isFalse);
      expect(distant, isNull);
      expect(mid, isNotNull);
      expect(mid!.uncertain, isTrue);
      expect(mid.zoneNote, contains('Borderline'));
      expect(d.zoneRejectedCount, 1);
      expect(d.zoneUncertainCount, 1);
      expect(mid.shotNumber, 2, reason: 'rejected sounds are not numbered');
      d.dispose();
    });

    test('a rejected sound does not start the debounce lockout', () {
      final ShotDetector d = _detector(DetectionZone.nearField)..start(t0);
      final DateTime t = t0.add(const Duration(seconds: 1));
      expect(d.processClassification(_gunshot(t, bg: -22, dtr: 4)), isNull);
      // 100 ms later, inside the 300 ms debounce window.
      expect(
          d.processClassification(_gunshot(
              t.add(const Duration(milliseconds: 100)), bg: -42, dtr: 14)),
          isNotNull);
      d.dispose();
    });

    test('uncertain flag survives saving and loading', () {
      final ShotEvent e = ShotEvent(
        shotNumber: 1,
        elapsedTime: const Duration(seconds: 1),
        confidence: 0.8,
        detectionTimestamp: t0,
        uncertain: true,
        zoneNote: 'Borderline',
      );
      expect(ShotEvent.fromMap(e.toMap()), e);
      expect(ShotEvent.fromMap(e.copyWith(uncertain: false).toMap()).uncertain,
          isFalse);
    });
  });

  group('AudioPipeline background measurement', () {
    test('candidates carry the background from before them, not their own',
        () async {
      final FakeAudioService mic = FakeAudioService();
      final ShotDetector detector = _detector(DetectionZone.nearField)
        ..start(DateTime.now().subtract(const Duration(seconds: 10)));
      final AudioPipeline pipeline = AudioPipeline(
        audioService: mic,
        audioPreprocessor: _Pre(),
        audioClassifier: _AlwaysGunshot(),
        shotDetector: detector,
      );
      final List<AudioClassification> seen = [];
      pipeline.classificationStream.listen(seen.add);
      await pipeline.start();

      // 3 s of ambient at about -50 dBFS (amplitude 100), then a spike.
      mic.emit(_pcm(48000, level: 100));
      mic.emit(_pcm(4000, level: 100, spikes: {1000: 30000}));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(pipeline.backgroundDbFs, closeTo(-50.3, 0.2));
      final AudioClassification loud = seen.last;
      expect(loud.peakDbFs, greaterThan(-1));
      expect(loud.backgroundDbFs, closeTo(-50.3, 0.2));
      expect(loud.directRatioDb, isNotNull);
      await pipeline.dispose();
      detector.dispose();
    });

    test('starts from the calibration seed before live audio', () async {
      final ShotDetector detector = _detector(DetectionZone.nearField);
      final AudioPipeline pipeline = AudioPipeline(
        audioService: FakeAudioService(),
        audioPreprocessor: _Pre(),
        audioClassifier: _AlwaysGunshot(),
        shotDetector: detector,
        noiseSeedDbFs: -57,
      );
      expect(pipeline.backgroundDbFs, -57);
      expect(pipeline.backgroundIsLive, isFalse);
      await pipeline.dispose();
      detector.dispose();
    });
  });

  group('MicrophoneManager', () {
    test('lists and classifies inputs, dropping duplicate IDs', () async {
      final MicrophoneManager m = MicrophoneManager(
        platform: MicPlatform.android,
        lister: () async => const [
          InputDevice(id: '1', label: 'Phone (built-in microphone)'),
          InputDevice(id: '1', label: 'Phone (built-in microphone)'),
          InputDevice(id: '9', label: 'Mic (USB device)'),
        ],
      );
      final List<MicDevice> list = await m.listInputs();
      expect(list.map((d) => d.kind), [MicKind.builtIn, MicKind.external]);
    });

    test('presence: connected, missing, and unknown when listing fails',
        () async {
      const MicSelection usb = MicSelection(id: '9', label: 'Mic (USB device)');
      List<InputDevice> now = const [InputDevice(id: '9', label: 'Mic (USB device)')];
      bool fail = false;
      final MicrophoneManager m = MicrophoneManager(
        platform: MicPlatform.android,
        lister: () async => fail ? throw StateError('no') : now,
      );
      expect(await m.presenceOf(usb), MicPresence.connected);
      expect(await m.presenceOf(MicSelection.systemDefault),
          MicPresence.connected);
      now = const [];
      expect(await m.presenceOf(usb), MicPresence.missing);
      fail = true;
      expect(await m.presenceOf(usb), MicPresence.unknown);
    });

    test('watch reports disconnection and reconnection once each', () async {
      const MicSelection usb = MicSelection(id: '9', label: 'Mic (USB device)');
      List<InputDevice> now = const [
        InputDevice(id: '9', label: 'Mic (USB device)')
      ];
      final MicrophoneManager m = MicrophoneManager(
          platform: MicPlatform.android, lister: () async => now);
      final List<MicPresence> events = [];
      final StreamSubscription<MicPresence> sub = m
          .watch(usb, interval: const Duration(milliseconds: 20))
          .listen(events.add);
      Future<void> wait() => Future<void>.delayed(const Duration(milliseconds: 80));
      await wait();
      now = const [];
      await wait();
      // Android may reassign the ID on reconnect; the label still matches.
      now = const [InputDevice(id: '14', label: 'Mic (USB device)')];
      await wait();
      await sub.cancel();
      expect(events, [
        MicPresence.connected,
        MicPresence.missing,
        MicPresence.connected,
      ]);
    });

    test('iOS does not poll during sessions; web hides names', () {
      expect(MicrophoneManager(platform: MicPlatform.ios, lister: () async => [])
          .canMonitorDuringSession, isFalse);
      expect(MicrophoneManager(platform: MicPlatform.android, lister: () async => [])
          .canMonitorDuringSession, isTrue);
      expect(MicrophoneManager(platform: MicPlatform.web, lister: () async => [])
          .labelsNeedPermission, isTrue);
    });
  });
}
