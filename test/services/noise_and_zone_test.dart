import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/detection_zone.dart';
import 'package:shot_timer_ai/services/audio/level_analysis.dart';
import 'package:shot_timer_ai/services/audio/noise_estimator.dart';

/// An impulse at [peak] followed by an exponential decay, with the tail
/// level [tailDb] relative to the impulse.
List<double> _impulse({int length = 6000, int peak = 1000, double tailDb = -30}) {
  final List<double> x = List<double>.filled(length, 0);
  x[peak] = 0.9;
  for (int i = 1; i < 160; i++) {
    x[peak + i] = 0.9 * math.exp(-i / 30);
  }
  final double tail = 0.9 * math.pow(10, tailDb / 20).toDouble();
  final math.Random r = math.Random(1);
  for (int i = peak + 480; i < length; i++) {
    x[i] += (r.nextDouble() * 2 - 1) * tail;
  }
  return x;
}

void main() {
  group('BackgroundNoiseEstimator', () {
    test('uses the seed until enough ambient windows arrive', () {
      final BackgroundNoiseEstimator e = BackgroundNoiseEstimator(seed: -55);
      expect(e.estimate, -55);
      expect(e.isLive, isFalse);
      for (int i = 0; i < 8; i++) {
        e.add(-48);
      }
      expect(e.estimate, -48);
      expect(e.isLive, isTrue);
    });

    test('no seed and no audio means unknown, never a made-up value', () {
      expect(BackgroundNoiseEstimator().estimate, isNull);
    });

    test('shots and their echo do not move the estimate', () {
      final BackgroundNoiseEstimator e = BackgroundNoiseEstimator();
      for (int i = 0; i < 20; i++) {
        e.add(-50);
      }
      // A shot (candidate), its echo, and a loud non-candidate bang.
      e.add(-3, isCandidate: true);
      e.add(-20);
      e.add(-30);
      e.add(-10);
      for (int i = 0; i < 5; i++) {
        e.add(-50);
      }
      expect(e.estimate, closeTo(-50, 1e-9));
    });

    test('follows the surroundings when they stay louder', () {
      final BackgroundNoiseEstimator e = BackgroundNoiseEstimator();
      for (int i = 0; i < 20; i++) {
        e.add(-60);
      }
      // A generator starts: 30 s at -30 dBFS.
      for (int i = 0; i < 120; i++) {
        e.add(-30);
      }
      expect(e.estimate, closeTo(-30, 1e-9));
    });

    test('a long run of candidates never enters the estimate', () {
      final BackgroundNoiseEstimator e = BackgroundNoiseEstimator();
      for (int i = 0; i < 20; i++) {
        e.add(-55);
      }
      for (int i = 0; i < 200; i++) {
        e.add(-2, isCandidate: true);
      }
      expect(e.estimate, closeTo(-55, 1e-9));
    });

    test('ignores non-finite input', () {
      final BackgroundNoiseEstimator e = BackgroundNoiseEstimator();
      for (int i = 0; i < 8; i++) {
        e.add(-45);
      }
      e.add(double.nan);
      e.add(double.negativeInfinity);
      expect(e.estimate, -45);
    });
  });

  group('directToTailRatioDb', () {
    test('a clean nearby impulse has a high ratio', () {
      expect(directToTailRatioDb(_impulse(tailDb: -40), 1000)!,
          greaterThan(20));
    });

    test('more echo lowers the ratio', () {
      final double dry = directToTailRatioDb(_impulse(tailDb: -35), 1000)!;
      final double wet = directToTailRatioDb(_impulse(tailDb: -12), 1000)!;
      expect(wet, lessThan(dry));
    });

    test('needs at least 70 ms of tail', () {
      // 1000 + 30 ms + 60 ms of tail only.
      expect(directToTailRatioDb(_impulse(length: 1000 + 480 + 960), 1000),
          isNull);
    });

    test('silence and a silent tail stay finite', () {
      expect(directToTailRatioDb(List<double>.filled(6000, 0), 1000), isNull);
      final List<double> x = List<double>.filled(6000, 0)..[1000] = 0.5;
      expect(directToTailRatioDb(x, 1000)!.isFinite, isTrue);
    });
  });

  group('NearFieldPolicy', () {
    ZoneVerdict v(double? bg, double? dtr, {double peak = -2}) =>
        NearFieldPolicy.evaluate(ZoneFeatures(
                peakDbFs: peak, backgroundDbFs: bg, directRatioDb: dtr))
            .verdict;

    test('measured near shot (SNR ~40, ratio ~14) is accepted', () {
      expect(v(-42, 14), ZoneVerdict.accepted);
    });

    test('controlled mid-distance version (SNR ~29, ratio ~9) is uncertain', () {
      expect(v(-31, 9.2), ZoneVerdict.uncertain);
    });

    test('controlled distant versions (ratio 4–6, SNR 15–20) are rejected', () {
      expect(v(-22, 5.8), ZoneVerdict.rejected);
      expect(v(-17, 4.2), ZoneVerdict.rejected);
    });

    test('too little above background is rejected even with a dry onset', () {
      expect(v(-12, 14), ZoneVerdict.rejected);
    });

    test('missing measurements never accept by default', () {
      expect(v(null, null), ZoneVerdict.uncertain);
      expect(v(null, 14), ZoneVerdict.uncertain);
      expect(v(-26, null), ZoneVerdict.uncertain); // SNR 24 < 30
      expect(v(-40, null), ZoneVerdict.accepted); // SNR 38 ≥ 30
    });

    test('reasons describe the measurements', () {
      final ZoneDecision d = NearFieldPolicy.evaluate(const ZoneFeatures(
          peakDbFs: -2, backgroundDbFs: -22, directRatioDb: 5.8));
      expect(d.reason, contains('5.8'));
    });
  });

  test('directional priority is not offered with mono capture', () {
    expect(DetectionZone.directional.isSupported, isFalse);
    expect(DirectionalSupport.current.available, isFalse);
    expect(DetectionZone.nearField.isSupported, isTrue);
    expect(DetectionZone.standard.isSupported, isTrue);
  });
}
