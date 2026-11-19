import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/app_settings.dart';
import 'package:shot_timer_ai/models/sensitivity.dart';
import 'package:shot_timer_ai/providers/audio_input_provider.dart';
import 'package:shot_timer_ai/providers/settings_provider.dart';
import 'package:shot_timer_ai/services/persistence/settings_repository.dart';
import 'package:shot_timer_ai/ui/theme/app_theme.dart';
import 'package:shot_timer_ai/ui/widgets/sensitivity_section.dart';

import '../support/fake_audio_service.dart';

Future<(ProviderContainer, InMemorySettingsRepository)> _pump(
    WidgetTester tester, {AppSettings settings = const AppSettings()}) async {
  tester.view.physicalSize = const Size(390, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final InMemorySettingsRepository repo = InMemorySettingsRepository(settings);
  final ProviderContainer c = ProviderContainer(overrides: [
    settingsRepositoryProvider.overrideWithValue(repo),
    // The microphone is never opened in these tests.
    audioServiceFactoryProvider.overrideWithValue(FakeAudioService.new),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(
        body: SingleChildScrollView(child: SensitivitySection()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return (c, repo);
}

Finder _field() => find.byType(TextField);

/// Whether the Save button is currently enabled.
bool _saveEnabled(WidgetTester tester) {
  final FilledButton b =
      tester.widget(find.widgetWithText(FilledButton, 'Save'));
  return b.onPressed != null;
}

void main() {
  testWidgets('starts in firearm preset mode with the preset gate shown',
      (tester) async {
    await _pump(tester);
    expect(find.textContaining('Using the firearm preset'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(_saveEnabled(tester), isFalse, reason: 'nothing changed yet');
  });

  testWidgets('custom mode shows presets, slider and numeric input',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Custom sensitivity'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(_field(), findsOneWidget);
    expect(find.text('Medium -30'), findsOneWidget);
    expect(find.text('Very Low -15'), findsOneWidget);
  });

  testWidgets('invalid numeric input shows an error and blocks saving',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Custom sensitivity'));
    await tester.pumpAndSettle();

    await tester.enterText(_field(), '-70');
    await tester.pumpAndSettle();
    expect(find.text('Must be between -60.0 and -1.0 dBFS.'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);

    await tester.enterText(_field(), 'loud');
    await tester.pumpAndSettle();
    expect(find.text('Enter a number, for example -30.'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('a valid value saves to settings storage and survives reload',
      (tester) async {
    final (ProviderContainer c, InMemorySettingsRepository repo) =
        await _pump(tester);
    await tester.tap(find.text('Custom sensitivity'));
    await tester.pumpAndSettle();

    await tester.enterText(_field(), '-22');
    await tester.pumpAndSettle();
    expect(_saveEnabled(tester), isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final AppSettings saved = c.read(settingsProvider);
    expect(saved.sensitivityMode, SensitivityMode.custom);
    expect(saved.customThresholdDbFs, -22);
    expect((await repo.load()).customThresholdDbFs, -22);
    expect(saved.firearmProfile.minPeakDbFs, -22);
  });

  testWidgets('preset chips and reset set the draft threshold', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Custom sensitivity'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Very Low -15'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_field()).controller!.text, '-15.0');

    await tester.tap(find.textContaining('Reset to default'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_field()).controller!.text, '-30.0');
  });

  testWidgets('discard restores the saved values', (tester) async {
    await _pump(tester,
        settings: const AppSettings(
            sensitivityMode: SensitivityMode.custom, customThresholdDbFs: -40));
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.text('Very High -45'));
    await tester.pumpAndSettle();
    expect(_saveEnabled(tester), isTrue);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_field()).controller!.text, '-40.0');
    expect(_saveEnabled(tester), isFalse);
  });
}
