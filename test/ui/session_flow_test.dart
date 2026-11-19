import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/app_settings.dart';
import 'package:shot_timer_ai/models/session.dart';
import 'package:shot_timer_ai/models/shot_event.dart';
import 'package:shot_timer_ai/models/start_delay_mode.dart';
import 'package:shot_timer_ai/providers/session_history_provider.dart';
import 'package:shot_timer_ai/providers/session_provider.dart';

import 'test_harness.dart';

/// Simulation mode avoids the microphone plugin; the beep is disabled so
/// no audio player channel is invoked during tests.
const AppSettings _sim = AppSettings(
  useSimulation: true,
  startDelay: StartDelayMode.instant,
  playStartBeep: false,
  hapticOnDetection: false,
);

Future<ProviderContainer> _startSimulatedSession(
    WidgetTester tester, Size size) async {
  setViewport(tester, size);
  final ProviderContainer c = await pumpApp(tester, settings: _sim);

  await tester.tap(find.text('Start new session').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue to timer'));
  await tester.pumpAndSettle();

  // Ready state: nothing has started yet.
  expect(find.text('START'), findsOneWidget);
  expect(c.read(sessionProvider).session, isNull);

  await tester.tap(find.text('START'));
  await tester.pump(); // beep phase
  await tester.pump(const Duration(milliseconds: 350)); // running
  return c;
}

void main() {
  for (final Size size in const [Size(360, 780), Size(1280, 800)]) {
    testWidgets('full simulated session flow @ ${size.width.toInt()}w',
        (tester) async {
      final ProviderContainer c = await _startSimulatedSession(tester, size);
      expect(find.text('RUNNING'), findsOneWidget);
      expect(c.read(sessionProvider).session!.isSimulated, isTrue);

      // Simulated events arrive every 1–3 s.
      await tester.pump(const Duration(seconds: 4));
      final int before = c.read(sessionProvider).shots.length;
      expect(before, greaterThan(0));
      expect(find.text('Simulated'), findsWidgets);

      // Pause: no events while paused.
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);
      expect(c.read(sessionProvider).isPaused, isTrue);
      await tester.pump(const Duration(seconds: 6));
      expect(c.read(sessionProvider).shots.length, before);

      // Resume.
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(find.text('RUNNING'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(c.read(sessionProvider).shots.length, greaterThan(before));

      // End requires confirmation; cancelling keeps the session running.
      // (The timer ticker runs continuously, so use fixed pumps, not settle.)
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('End session?'), findsOneWidget);
      await tester.tap(find.text('Keep running'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('End session?'), findsNothing);
      expect(c.read(sessionProvider).isRunning, isTrue);

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(FilledButton, 'End session').last);
      await tester.pumpAndSettle();

      // Results show the saved session with real recorded events.
      expect(find.text('Session results'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final List<Session> saved =
          await c.read(sessionRepositoryProvider).getAllSessions();
      expect(saved, hasLength(1));
      expect(saved.single.shots.length, c.read(sessionProvider).shots.length);
      expect(saved.single.pausedDuration, greaterThan(Duration.zero));

      // Review: reject the first event and confirm persistence.
      final Finder reject = find.byTooltip('Reject as false detection').first;
      await tester.ensureVisible(reject);
      await tester.pumpAndSettle();
      await tester.tap(reject);
      await tester.pumpAndSettle();
      final Session reviewed =
          (await c.read(sessionRepositoryProvider).getAllSessions()).single;
      expect(reviewed.shots.first.reviewStatus, ReviewStatus.rejected);
    });
  }

  testWidgets('cancelling standby does not create a session', (tester) async {
    setViewport(tester, const Size(360, 780));
    final ProviderContainer c = await pumpApp(
      tester,
      settings: _sim.copyWith(startDelay: StartDelayMode.fixed3s),
    );
    await tester.tap(find.text('Start new session').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to timer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await tester.pump();
    expect(find.text('STANDBY'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('START'), findsOneWidget);
    expect(c.read(sessionProvider).session, isNull);
  });

  testWidgets('history delete requires confirmation', (tester) async {
    setViewport(tester, const Size(1280, 800));
    final ProviderContainer c =
        await pumpApp(tester, sessions: sampleSessions());
    await tester.tap(find.text('History').first);
    await tester.pumpAndSettle();
    final int count =
        (await c.read(sessionRepositoryProvider).getAllSessions()).length;

    await tester.tap(find.byTooltip('Delete session').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await c.read(sessionRepositoryProvider).getAllSessions()).length, count);

    await tester.tap(find.byTooltip('Delete session').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect((await c.read(sessionRepositoryProvider).getAllSessions()).length,
        count - 1);
  });

  testWidgets('history search and simulated filter', (tester) async {
    setViewport(tester, const Size(360, 780));
    await pumpApp(tester, sessions: sampleSessions());
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simulated').first);
    await tester.pumpAndSettle();
    // Only the simulated session remains (its card carries the tag).
    expect(find.text('Glock 19 (Suppressed)'), findsNothing);

    await tester.tap(find.text('All').first);
    await tester.enterText(find.byType(TextField), 'suppressed');
    await tester.pumpAndSettle();
    expect(find.text('Glock 19 (Suppressed)'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
