import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:shot_timer_ai/models/app_settings.dart';
import 'package:shot_timer_ai/models/detection_zone.dart';
import 'package:shot_timer_ai/models/microphone.dart';
import 'package:shot_timer_ai/providers/app_status_provider.dart';
import 'package:shot_timer_ai/providers/audio_input_provider.dart';
import 'package:shot_timer_ai/providers/settings_provider.dart';
import 'package:shot_timer_ai/services/persistence/settings_repository.dart';
import 'package:shot_timer_ai/ui/theme/app_theme.dart';
import 'package:shot_timer_ai/ui/widgets/detection_status_card.dart';
import 'package:shot_timer_ai/ui/widgets/detection_zone_section.dart';
import 'package:shot_timer_ai/ui/widgets/microphone_section.dart';

import '../support/fake_audio_service.dart';
import 'test_harness.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child, {
  AppSettings settings = const AppSettings(),
  List<InputDevice> inputs = kTestInputs,
}) async {
  tester.view.physicalSize = const Size(360, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ProviderContainer c = ProviderContainer(overrides: [
    settingsRepositoryProvider
        .overrideWithValue(InMemorySettingsRepository(settings)),
    microphoneManagerProvider.overrideWithValue(fakeMicrophones(inputs)),
    audioServiceFactoryProvider.overrideWithValue(FakeAudioService.new),
    micPermissionProvider.overrideWith((ref) async => MicPermission.granted),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ));
  await tester.pumpAndSettle();
  return c;
}

const MicSelection _usb =
    MicSelection(id: '9', label: 'RØDE VideoMic NTG (USB device)');

void main() {
  group('MicrophoneSection', () {
    testWidgets('shows the default input, permission and the listed inputs',
        (tester) async {
      await _pump(tester, const MicrophoneSection());
      expect(find.text('System default input'), findsWidgets);
      expect(find.text('Chosen by the operating system'), findsOneWidget);
      expect(find.text('Granted'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Pixel (built-in microphone) · Built-in'), findsWidgets);
      expect(find.text('RØDE VideoMic NTG (USB device) · External'),
          findsWidgets);
    });

    testWidgets('selecting an external input saves it and shows its type',
        (tester) async {
      final ProviderContainer c = await _pump(tester, const MicrophoneSection());
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RØDE VideoMic NTG (USB device) · External').last);
      await tester.pumpAndSettle();

      expect(c.read(settingsProvider).micSelection, _usb);
      expect(find.text('External'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('a selected input that is not connected is reported',
        (tester) async {
      await _pump(
        tester,
        const MicrophoneSection(),
        settings: const AppSettings(micSelection: _usb),
        inputs: const [InputDevice(id: '1', label: 'Pixel (built-in microphone)')],
      );
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.textContaining('Sessions will record from the system default'),
          findsOneWidget);
    });
  });

  group('DetectionZoneSection', () {
    testWidgets('offers standard and near-field; directional is unavailable',
        (tester) async {
      final ProviderContainer c =
          await _pump(tester, const DetectionZoneSection());
      expect(find.text('Standard detection'), findsOneWidget);
      expect(find.text('Near-field priority'), findsOneWidget);
      expect(find.text('Directional priority'), findsOneWidget);
      expect(find.text('Unavailable'), findsNWidgets(2),
          reason: 'directional and detection radius');
      // Only two selectable options.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

      await tester.tap(find.text('Directional priority'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).detectionZone, DetectionZone.standard);
    });

    testWidgets('choosing near-field saves it and explains the rules',
        (tester) async {
      final ProviderContainer c =
          await _pump(tester, const DetectionZoneSection());
      await tester.tap(find.text('Near-field priority'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).detectionZone, DetectionZone.nearField);
      expect(find.textContaining('Accepted: at least 25 dB'), findsOneWidget);
      expect(find.textContaining('No noise floor saved'), findsOneWidget);
    });

    testWidgets('switching zones keeps the firearm preset and custom gate',
        (tester) async {
      final ProviderContainer c = await _pump(
        tester,
        const DetectionZoneSection(),
        settings: const AppSettings().copyWith(customThresholdDbFs: -41),
      );
      await tester.tap(find.text('Near-field priority'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Standard detection'));
      await tester.pumpAndSettle();
      final AppSettings s = c.read(settingsProvider);
      expect(s.customThresholdDbFs, -41);
      expect(s.firearmPreset, const AppSettings().firearmPreset);
    });
  });

  group('DetectionStatusCard', () {
    testWidgets('warns about a missing microphone and missing calibration',
        (tester) async {
      await _pump(
        tester,
        const DetectionStatusCard(),
        settings: const AppSettings(
            micSelection: _usb, detectionZone: DetectionZone.nearField),
        inputs: const [],
      );
      expect(find.textContaining('(not connected)'), findsOneWidget);
      expect(find.textContaining('is not connected. Sessions will use'),
          findsOneWidget);
      expect(find.textContaining('no saved noise floor'), findsOneWidget);
    });

    testWidgets('no warnings for a connected, calibrated setup', (tester) async {
      await _pump(
        tester,
        const DetectionStatusCard(),
        settings: const AppSettings(micSelection: _usb).withCalibration(
          _usb,
          MicCalibration(
            noiseFloorDbFs: -52,
            ambientPeakDbFs: -44,
            windowCount: 24,
            measuredAt: DateTime(2026, 11, 19),
          ),
        ),
      );
      expect(find.text('No warnings'), findsOneWidget);
      expect(find.textContaining('Noise floor -52.0 dBFS'), findsOneWidget);
    });
  });
}
