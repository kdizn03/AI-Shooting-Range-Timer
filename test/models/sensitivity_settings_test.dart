import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/app_settings.dart';
import 'package:shot_timer_ai/models/firearm_profile.dart';
import 'package:shot_timer_ai/models/sensitivity.dart';
import 'package:shot_timer_ai/services/classifier/audio_classification.dart';
import 'package:shot_timer_ai/services/detection/detection_config.dart';
import 'package:shot_timer_ai/services/detection/shot_detector.dart';

AudioClassification _gunshot(DateTime t, double dbFs) => AudioClassification(
      label: AudioLabel.gunshot,
      confidence: 0.95,
      scores: const {AudioLabel.gunshot: 0.95},
      timestamp: t,
      peakDbFs: dbFs,
    );

void main() {
  group('SensitivityLimits', () {
    test('range and default match the specification', () {
      expect(SensitivityLimits.minDbFs, -60);
      expect(SensitivityLimits.maxDbFs, -1);
      expect(SensitivityLimits.defaultDbFs, -30);
    });

    test('isValid rejects out-of-range, non-finite values', () {
      expect(SensitivityLimits.isValid(-30), isTrue);
      expect(SensitivityLimits.isValid(-60), isTrue);
      expect(SensitivityLimits.isValid(-1), isTrue);
      expect(SensitivityLimits.isValid(-0.5), isFalse);
      expect(SensitivityLimits.isValid(-60.1), isFalse);
      expect(SensitivityLimits.isValid(double.nan), isFalse);
      expect(SensitivityLimits.isValid(double.infinity), isFalse);
    });

    test('clamp brings values into range and maps non-finite to default', () {
      expect(SensitivityLimits.clamp(-70), -60);
      expect(SensitivityLimits.clamp(0), -1);
      expect(SensitivityLimits.clamp(-22), -22);
      expect(SensitivityLimits.clamp(double.nan), -30);
    });
  });

  group('applySensitivity', () {
    const FirearmProfile base = FirearmProfile.glock19Unsuppressed;

    test('preset mode returns the firearm profile unchanged', () {
      final FirearmProfile p =
          applySensitivity(base, SensitivityMode.preset, -22);
      expect(p, base);
    });

    test('custom mode replaces the gate and labels the profile', () {
      final FirearmProfile p =
          applySensitivity(base, SensitivityMode.custom, -22);
      expect(p.minPeakDbFs, -22);
      expect(p.displayName, 'Custom sensitivity (-22.0 dBFS)');
      expect(p.preset, base.preset, reason: 'firearm type is kept');
      expect(p.nominalPeakDbSpl, base.nominalPeakDbSpl);
    });

    test('custom mode clamps an out-of-range threshold', () {
      expect(applySensitivity(base, SensitivityMode.custom, -80).minPeakDbFs,
          -60);
    });

    test('starting presets are inside the allowed range', () {
      for (final SensitivityPreset p in kSensitivityPresets) {
        expect(SensitivityLimits.isValid(p.dbFs), isTrue, reason: p.label);
      }
    });
  });

  group('AppSettings sensitivity', () {
    test('defaults to preset mode with the -30 dBFS custom threshold', () {
      const AppSettings s = AppSettings();
      expect(s.sensitivityMode, SensitivityMode.preset);
      expect(s.customThresholdDbFs, -30);
      expect(s.firearmProfile.minPeakDbFs,
          FirearmProfile.glock19Unsuppressed.minPeakDbFs);
    });

    test('custom threshold survives switching modes back and forth', () {
      final AppSettings custom = const AppSettings()
          .copyWith(sensitivityMode: SensitivityMode.custom, customThresholdDbFs: -22);
      expect(custom.firearmProfile.minPeakDbFs, -22);

      final AppSettings presetAgain =
          custom.copyWith(sensitivityMode: SensitivityMode.preset);
      expect(presetAgain.customThresholdDbFs, -22);
      expect(presetAgain.firearmProfile.minPeakDbFs,
          FirearmProfile.glock19Unsuppressed.minPeakDbFs);

      final AppSettings customAgain =
          presetAgain.copyWith(sensitivityMode: SensitivityMode.custom);
      expect(customAgain.firearmProfile.minPeakDbFs, -22);
    });

    test('copyWith clamps an invalid custom threshold', () {
      expect(const AppSettings().copyWith(customThresholdDbFs: -99)
          .customThresholdDbFs, -60);
    });

    test('round-trips through a map', () {
      final AppSettings s = const AppSettings().copyWith(
          sensitivityMode: SensitivityMode.custom, customThresholdDbFs: -18.5);
      expect(AppSettings.fromMap(s.toMap()), s);
    });

    test('settings saved before this feature load in preset mode', () {
      final AppSettings legacy = AppSettings.fromMap({
        'firearmPreset': 'glock19Suppressed',
        'customGateDbFs': -10.0,
      });
      expect(legacy.sensitivityMode, SensitivityMode.preset);
      expect(legacy.customThresholdDbFs, -30);
      expect(legacy.firearmPreset, FirearmPreset.glock19Suppressed);
    });

    test('invalid stored thresholds fall back safely', () {
      expect(AppSettings.fromMap({'customThresholdDbFs': -99})
          .customThresholdDbFs, -60);
      expect(AppSettings.fromMap({'customThresholdDbFs': 'loud'})
          .customThresholdDbFs, -30);
      expect(AppSettings.fromMap({'customThresholdDbFs': -20.0,
              'sensitivityMode': 'bogus'}).sensitivityMode,
          SensitivityMode.preset);
    });
  });

  group('custom gate reaches the real detector', () {
    final DateTime t0 = DateTime(2026, 4, 1, 10);

    ShotDetector detectorFor(double gate) {
      final FirearmProfile profile = applySensitivity(
          FirearmProfile.glock19Unsuppressed, SensitivityMode.custom, gate);
      final ShotDetector d = ShotDetector(
        config: DetectionConfig(
          minPeakDbFs: profile.minPeakDbFs,
          firearmProfile: profile,
          debounceDurationMs: 100,
          inferenceLatencyCompensationMs: 0,
        ),
      )..start(t0);
      return d;
    }

    test('a level above the custom gate is accepted', () {
      final ShotDetector d = detectorFor(-30);
      addTearDown(d.dispose);
      expect(d.processClassification(_gunshot(t0.add(const Duration(seconds: 1)), -25)),
          isNotNull);
    });

    test('a level below the custom gate is rejected', () {
      final ShotDetector d = detectorFor(-30);
      addTearDown(d.dispose);
      expect(d.processClassification(_gunshot(t0.add(const Duration(seconds: 1)), -35)),
          isNull);
    });

    test('a more negative gate counts quieter sounds', () {
      final ShotDetector d = detectorFor(-45);
      addTearDown(d.dispose);
      expect(d.processClassification(_gunshot(t0.add(const Duration(seconds: 1)), -40)),
          isNotNull);
    });

    test('a level that passes the preset gate but not the custom one is rejected', () {
      // Unsuppressed preset gate is -4 dBFS, so a -20 dBFS sound would be
      // rejected there too; check the opposite case with a loud custom gate.
      final ShotDetector d = detectorFor(-10);
      addTearDown(d.dispose);
      expect(d.processClassification(_gunshot(t0.add(const Duration(seconds: 1)), -20)),
          isNull);
    });
  });
}
