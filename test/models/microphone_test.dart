import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/app_settings.dart';
import 'package:shot_timer_ai/models/detection_zone.dart';
import 'package:shot_timer_ai/models/firearm_profile.dart';
import 'package:shot_timer_ai/models/microphone.dart';
import 'package:shot_timer_ai/models/sensitivity.dart';

MicCalibration _cal(double floor) => MicCalibration(
      noiseFloorDbFs: floor,
      ambientPeakDbFs: floor + 8,
      windowCount: 24,
      measuredAt: DateTime(2026, 11, 19),
    );

void main() {
  group('classifyMicLabel', () {
    test('Android labels carry the device type', () {
      // Format produced by the record plugin's DeviceUtils on Android.
      expect(classifyMicLabel('Pixel 8 (built-in microphone, bottom)',
          MicPlatform.android), MicKind.builtIn);
      expect(classifyMicLabel('RØDE VideoMic (USB device, card=1)',
          MicPlatform.android), MicKind.external);
      expect(classifyMicLabel('Headset (wired headset)', MicPlatform.android),
          MicKind.external);
      expect(classifyMicLabel('Buds (Bluetooth telephony SCO, 00:11)',
          MicPlatform.android), MicKind.external);
      expect(classifyMicLabel('Mystery (FM tuner)', MicPlatform.android),
          MicKind.unknown);
    });

    test('iOS: the device microphone is built-in, anything else attached', () {
      expect(classifyMicLabel('iPhone Microphone', MicPlatform.ios),
          MicKind.builtIn);
      expect(classifyMicLabel('USB Audio CODEC', MicPlatform.ios),
          MicKind.external);
      expect(classifyMicLabel('', MicPlatform.ios), MicKind.unknown);
    });

    test('web and desktop only trust explicit wording', () {
      expect(classifyMicLabel('MacBook Pro Microphone (Built-in)',
          MicPlatform.web), MicKind.builtIn);
      expect(classifyMicLabel('Yeti Stereo Microphone (USB)',
          MicPlatform.desktop), MicKind.external);
      expect(classifyMicLabel('Microphone Array (Realtek(R) Audio)',
          MicPlatform.desktop), MicKind.unknown);
      expect(classifyMicLabel('', MicPlatform.web), MicKind.unknown);
    });
  });

  group('MicSelection', () {
    const List<MicDevice> devices = [
      MicDevice(id: '7', label: 'Phone (built-in microphone)', kind: MicKind.builtIn),
      MicDevice(id: '12', label: 'RØDE (USB device)', kind: MicKind.external),
    ];

    test('system default resolves to no specific device', () {
      expect(MicSelection.systemDefault.resolve(devices), isNull);
      expect(MicSelection.systemDefault.calibrationKey, 'default');
    });

    test('resolves by ID, then by label when Android reassigns the ID', () {
      expect(const MicSelection(id: '12', label: 'x').resolve(devices)!.id, '12');
      expect(
          const MicSelection(id: '99', label: 'RØDE (USB device)')
              .resolve(devices)!
              .id,
          '12');
    });

    test('a disconnected input does not resolve', () {
      expect(const MicSelection(id: '5', label: 'Gone').resolve(devices),
          isNull);
    });

    test('calibration key uses the stable label when there is one', () {
      expect(const MicSelection(id: '12', label: 'RØDE (USB device)')
          .calibrationKey, 'label:RØDE (USB device)');
      expect(const MicSelection(id: 'abc', label: '').calibrationKey, 'id:abc');
    });
  });

  group('MicCalibration.tryParse', () {
    test('round-trips', () {
      expect(MicCalibration.tryParse(_cal(-52).toMap()), _cal(-52));
    });

    test('rejects missing, non-finite and out-of-range values', () {
      expect(MicCalibration.tryParse(null), isNull);
      expect(MicCalibration.tryParse({'noiseFloorDbFs': -50}), isNull);
      expect(MicCalibration.tryParse({..._cal(-50).toMap(), 'noiseFloorDbFs': 5}),
          isNull);
      expect(
          MicCalibration.tryParse(
              {..._cal(-50).toMap(), 'ambientPeakDbFs': double.nan}),
          isNull);
    });
  });

  group('AppSettings microphone and zone', () {
    const MicSelection usb = MicSelection(id: '12', label: 'RØDE (USB device)');

    test('defaults: system input, standard detection, no calibrations', () {
      const AppSettings s = AppSettings();
      expect(s.micSelection, MicSelection.systemDefault);
      expect(s.detectionZone, DetectionZone.standard);
      expect(s.activeCalibration, isNull);
    });

    test('calibrations are kept per microphone across switches', () {
      final AppSettings s = const AppSettings()
          .withCalibration(MicSelection.systemDefault, _cal(-55))
          .withCalibration(usb, _cal(-48));
      expect(s.activeCalibration, _cal(-55));
      final AppSettings onUsb = s.copyWith(micSelection: usb);
      expect(onUsb.activeCalibration, _cal(-48));
      expect(onUsb.copyWith(micSelection: MicSelection.systemDefault)
          .activeCalibration, _cal(-55));
    });

    test('switching microphone or zone keeps preset and custom gate', () {
      final AppSettings s = const AppSettings(
        firearmPreset: FirearmPreset.custom,
        sensitivityMode: SensitivityMode.custom,
        customThresholdDbFs: -42,
      ).copyWith(micSelection: usb, detectionZone: DetectionZone.nearField);
      expect(s.firearmPreset, FirearmPreset.custom);
      expect(s.sensitivityMode, SensitivityMode.custom);
      expect(s.customThresholdDbFs, -42);
      expect(s.copyWith(detectionZone: DetectionZone.standard).firearmProfile
          .minPeakDbFs, -42);
    });

    test('directional cannot be stored while it is unsupported', () {
      expect(const AppSettings()
          .copyWith(detectionZone: DetectionZone.directional)
          .detectionZone, DetectionZone.standard);
      expect(AppSettings.fromMap(const {'detectionZone': 'directional'})
          .detectionZone, DetectionZone.standard);
    });

    test('round-trips; invalid stored entries are dropped individually', () {
      final AppSettings s = const AppSettings()
          .copyWith(micSelection: usb, detectionZone: DetectionZone.nearField)
          .withCalibration(usb, _cal(-48));
      expect(AppSettings.fromMap(s.toMap()), s);

      final Map<String, dynamic> raw = s.toMap()
        ..['micCalibrations'] = {
          'label:RØDE (USB device)': _cal(-48).toMap(),
          'broken': {'noiseFloorDbFs': 'loud'},
        }
        ..['micSelection'] = {'id': ''};
      final AppSettings parsed = AppSettings.fromMap(raw);
      expect(parsed.micCalibrations.keys, ['label:RØDE (USB device)']);
      expect(parsed.micSelection, MicSelection.systemDefault);
    });
  });
}
