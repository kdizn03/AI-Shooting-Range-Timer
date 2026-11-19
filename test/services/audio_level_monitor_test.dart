import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/services/audio/audio_level_monitor.dart';
import 'package:shot_timer_ai/services/audio/level_analysis.dart';

import '../support/fake_audio_service.dart';

/// One analysis window (250 ms at 16 kHz = 4000 samples) of constant [value].
Uint8List _window(int value) {
  final ByteData d = ByteData(8000);
  for (int i = 0; i < 4000; i++) {
    d.setInt16(i * 2, value, Endian.little);
  }
  return d.buffer.asUint8List();
}

void main() {
  late FakeAudioService mic;
  late AudioLevelMonitor monitor;

  setUp(() {
    mic = FakeAudioService();
    monitor = AudioLevelMonitor(createAudio: () => mic);
  });

  tearDown(() async {
    await monitor.dispose();
  });

  test('reports the measured peak of each real window', () async {
    await monitor.start();
    expect(mic.startCount, 1);

    mic.emit(_window(16384));
    await Future<void>.delayed(Duration.zero);

    expect(monitor.status.value, MonitorStatus.listening);
    expect(monitor.level.value!.dbFs, closeTo(-6.0206, 1e-3));
    // One window is not enough for a background estimate (needs ~2 s).
    expect(monitor.backgroundDbFs.value, isNull);

    for (int i = 0; i < 7; i++) {
      mic.emit(_window(16384));
    }
    await Future<void>.delayed(Duration.zero);
    expect(monitor.backgroundDbFs.value, closeTo(-6.0206, 1e-3));
  });

  test('joins chunks into windows and emits one value per 250 ms', () async {
    final List<double> seen = [];
    final StreamSubscription<double> sub = monitor.windows.listen(seen.add);
    await monitor.start();

    final Uint8List full = _window(8000);
    mic.emit(Uint8List.sublistView(full, 0, 3000));
    mic.emit(Uint8List.sublistView(full, 3000));
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    await sub.cancel();
  });

  test('digital silence reads the finite floor value', () async {
    await monitor.start();
    mic.emit(_window(0));
    await Future<void>.delayed(Duration.zero);

    expect(monitor.level.value!.dbFs, kSilenceFloorDbFs);
    expect(monitor.level.value!.dbFs.isFinite, isTrue);
  });

  test('refused permission is reported and the microphone is not opened',
      () async {
    final FakeAudioService denied = FakeAudioService(permission: false);
    final AudioLevelMonitor m = AudioLevelMonitor(createAudio: () => denied);
    await m.start();

    expect(m.status.value, MonitorStatus.permissionDenied);
    expect(denied.startCount, 0);
    expect(m.level.value, isNull);
    await m.dispose();
  });

  test('stop closes the microphone and clears every reading', () async {
    await monitor.start();
    mic.emit(_window(1000));
    await Future<void>.delayed(Duration.zero);

    await monitor.stop();

    expect(mic.stopCount, greaterThanOrEqualTo(1));
    expect(mic.isRecording, isFalse);
    expect(monitor.status.value, MonitorStatus.idle);
    expect(monitor.level.value, isNull);
    expect(monitor.backgroundDbFs.value, isNull);
  });

  group('calibrate', () {
    test('steady ambient noise produces a suggestion, not an applied value',
        () async {
      final Timer feed = Timer.periodic(
          const Duration(milliseconds: 20), (_) => mic.emit(_window(1000)));
      addTearDown(feed.cancel);

      final CalibrationOutcome o =
          await monitor.calibrate(duration: const Duration(milliseconds: 500));

      expect(o.issue, isNull);
      // 1000 / 32768 is about -30.3 dBFS; the suggestion adds 10 dB.
      expect(o.suggestedDbFs, closeTo(-20.3, 0.1));
      expect(monitor.isRunning, isFalse, reason: 'calibration stops its own run');
      expect(monitor.status.value, MonitorStatus.idle);
    });

    test('silent microphone is reported as no signal', () async {
      final Timer feed = Timer.periodic(
          const Duration(milliseconds: 20), (_) => mic.emit(_window(0)));
      addTearDown(feed.cancel);

      final CalibrationOutcome o =
          await monitor.calibrate(duration: const Duration(milliseconds: 500));

      expect(o.issue, CalibrationIssue.noSignal);
      expect(o.hasSuggestion, isFalse);
    });

    test('no audio arriving is reported as no input', () async {
      final CalibrationOutcome o =
          await monitor.calibrate(duration: const Duration(milliseconds: 300));

      expect(o.issue, CalibrationIssue.noInput);
      expect(o.hasSuggestion, isFalse);
    });

    test('permission refusal is reported instead of a bogus result', () async {
      final FakeAudioService denied = FakeAudioService(permission: false);
      final AudioLevelMonitor m = AudioLevelMonitor(createAudio: () => denied);

      final CalibrationOutcome o =
          await m.calibrate(duration: const Duration(milliseconds: 100));

      expect(o.issue, CalibrationIssue.permissionDenied);
      expect(m.status.value, MonitorStatus.permissionDenied);
      await m.dispose();
    });
  });
}
