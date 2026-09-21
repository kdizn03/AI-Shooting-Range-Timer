import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/firearm_profile.dart';

void main() {
  group('FirearmProfile', () {
    test('Glock 19 Unsuppressed preset has correct acoustic properties', () {
      const profile = FirearmProfile.glock19Unsuppressed;
      expect(profile.preset, FirearmPreset.glock19Unsuppressed);
      expect(profile.displayName, 'Glock 19 (Unsuppressed)');
      expect(profile.typicalDbRange, '155–167 dB');
      expect(profile.nominalPeakDbSpl, 162.0);
      expect(profile.minPeakDbFs, -4.0);
      expect(profile.isSuppressed, isFalse);
    });

    test('Glock 19 Suppressed preset has correct acoustic properties', () {
      const profile = FirearmProfile.glock19Suppressed;
      expect(profile.preset, FirearmPreset.glock19Suppressed);
      expect(profile.displayName, 'Glock 19 (Suppressed)');
      expect(profile.typicalDbRange, '134–140 dB');
      expect(profile.nominalPeakDbSpl, 137.0);
      expect(profile.minPeakDbFs, -14.0);
      expect(profile.isSuppressed, isTrue);
    });

    test('allPresets list contains all expected profiles', () {
      expect(FirearmProfile.allPresets.length, 6);
      expect(
        FirearmProfile.allPresets.map((p) => p.preset).toSet(),
        {
          FirearmPreset.glock19Unsuppressed,
          FirearmPreset.glock19Suppressed,
          FirearmPreset.centerfireRifle,
          FirearmPreset.rimfire22,
          FirearmPreset.airsoftDryFire,
          FirearmPreset.custom,
        },
      );
    });

    test('fromPreset maps all enum values correctly', () {
      for (final preset in FirearmPreset.values) {
        final profile = FirearmProfile.fromPreset(preset);
        expect(profile.preset, preset);
      }
    });

    test('toMap and fromMap serialization round-trip', () {
      const original = FirearmProfile.glock19Suppressed;
      final map = original.toMap();
      final restored = FirearmProfile.fromMap(map);

      expect(restored.preset, original.preset);
      expect(restored.displayName, original.displayName);
      expect(restored.typicalDbRange, original.typicalDbRange);
      expect(restored.nominalPeakDbSpl, original.nominalPeakDbSpl);
      expect(restored.minPeakDbFs, original.minPeakDbFs);
      expect(restored.isSuppressed, original.isSuppressed);
    });

    test('copyWith updates properties', () {
      const original = FirearmProfile.glock19Unsuppressed;
      final modified = original.copyWith(minPeakDbFs: -6.0);

      expect(modified.minPeakDbFs, -6.0);
      expect(modified.displayName, original.displayName);
    });
  });
}
