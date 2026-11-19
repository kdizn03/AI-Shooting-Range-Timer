import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/services/classifier/audio_classification.dart';
import 'package:shot_timer_ai/ui/theme/app_theme.dart';
import 'package:shot_timer_ai/ui/widgets/audio_status.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
  ));
}

void main() {
  final AudioClassification loud = AudioClassification(
    label: AudioLabel.gunshot,
    confidence: 0.91,
    scores: const {AudioLabel.gunshot: 0.91},
    timestamp: DateTime(2026),
    peakDbFs: -2.5,
  );

  testWidgets('listening shows engine, live label and level vs gate',
      (tester) async {
    final ValueNotifier<AudioClassification?> c = ValueNotifier(null);
    addTearDown(c.dispose);
    await _pump(
      tester,
      AudioStatus(
        state: MonitorState.listening,
        classification: c,
        gateDbFs: -4,
        engineLabel: 'Energy heuristic (model not bundled)',
      ),
    );
    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('Waiting for audio…'), findsOneWidget);

    c.value = loud;
    await tester.pump();
    expect(find.text('-2.5 dBFS'), findsOneWidget);
    expect(find.textContaining('Impulse (gunshot class) · 91%'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('above gate')), findsOneWidget);
  });

  testWidgets('permission denied shows error detail and no meter',
      (tester) async {
    final ValueNotifier<AudioClassification?> c = ValueNotifier(loud);
    addTearDown(c.dispose);
    await _pump(
      tester,
      AudioStatus(
        state: MonitorState.permissionDenied,
        classification: c,
        gateDbFs: -4,
        detail: 'No audio is being captured. Allow microphone access.',
      ),
    );
    expect(find.text('Microphone permission denied'), findsOneWidget);
    expect(find.textContaining('No audio is being captured'), findsOneWidget);
    expect(find.text('INPUT'), findsNothing);
  });

  testWidgets('simulation never shows a level meter, even when paused',
      (tester) async {
    final ValueNotifier<AudioClassification?> c = ValueNotifier(null);
    addTearDown(c.dispose);
    await _pump(
      tester,
      AudioStatus(
        state: MonitorState.paused,
        classification: c,
        gateDbFs: -4,
        hasAudioInput: false,
      ),
    );
    expect(find.text('INPUT'), findsNothing);
  });

  testWidgets('level-only readings show the gate state, then the verdict',
      (tester) async {
    final DateTime t0 = DateTime(2026, 1, 1, 12);
    final ValueNotifier<AudioClassification?> c = ValueNotifier(
        AudioClassification.levelOnly(timestamp: t0, peakDbFs: -50));
    final ValueNotifier<AudioClassification?> verdict = ValueNotifier(null);
    addTearDown(c.dispose);
    addTearDown(verdict.dispose);
    await _pump(
      tester,
      AudioStatus(
        state: MonitorState.listening,
        classification: c,
        verdict: verdict,
        gateDbFs: -30,
        engineLabel: 'YAMNet AI',
      ),
    );
    expect(find.text('Below gate'), findsOneWidget);

    c.value = AudioClassification.levelOnly(timestamp: t0, peakDbFs: -5);
    await tester.pump();
    expect(find.text('Checking sound…'), findsOneWidget);

    verdict.value = AudioClassification(
      label: AudioLabel.gunshot,
      confidence: 0.37,
      scores: const {AudioLabel.gunshot: 0.37},
      timestamp: t0,
      peakDbFs: -5,
    );
    c.value = AudioClassification.levelOnly(
        timestamp: t0.add(const Duration(seconds: 1)), peakDbFs: -50);
    await tester.pump();
    expect(find.textContaining('Last check:'), findsOneWidget);
    expect(find.textContaining('37%'), findsOneWidget);

    // The verdict is dropped a few seconds after its sound.
    c.value = AudioClassification.levelOnly(
        timestamp: t0.add(const Duration(seconds: 5)), peakDbFs: -50);
    await tester.pump();
    expect(find.text('Below gate'), findsOneWidget);
  });
}
