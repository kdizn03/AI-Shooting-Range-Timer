import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/session.dart';
import 'package:shot_timer_ai/providers/app_status_provider.dart';
import 'package:shot_timer_ai/ui/screens/results_screen.dart';
import 'package:shot_timer_ai/ui/screens/session_setup_screen.dart';

import 'test_harness.dart';

/// Renders every primary screen at each viewport. Any RenderFlex overflow
/// or layout exception fails the test.
void main() {
  for (final MapEntry<String, Size> vp in kViewports.entries) {
    group(vp.key, () {
      testWidgets('all tabs lay out without overflow (with data)', (tester) async {
        setViewport(tester, vp.value);
        final container = await pumpApp(tester, sessions: sampleSessions());

        for (final AppTab tab in AppTab.values) {
          container.read(selectedTabProvider.notifier).state = tab;
          await tester.pumpAndSettle();
          // Layout errors are reported by the framework and fail the test.
        }
      });

      testWidgets('all tabs lay out without overflow (empty)', (tester) async {
        setViewport(tester, vp.value);
        final container = await pumpApp(tester);
        for (final AppTab tab in AppTab.values) {
          container.read(selectedTabProvider.notifier).state = tab;
          await tester.pumpAndSettle();
          // Layout errors are reported by the framework and fail the test.
        }
      });

      testWidgets('navigation pattern matches size class', (tester) async {
        setViewport(tester, vp.value);
        await pumpApp(tester);
        final double w = vp.value.width;
        expect(find.byType(NavigationBar), w < 768 ? findsOneWidget : findsNothing);
        expect(find.byType(NavigationRail),
            w >= 768 && w < 1024 ? findsOneWidget : findsNothing);
        // Sidebar exposes the brand wordmark and a labelled start action.
        if (w >= 1024) {
          expect(find.text('NAVIGATION'), findsOneWidget);
        }
      });

      testWidgets('results and setup screens lay out', (tester) async {
        setViewport(tester, vp.value);
        await pumpApp(tester, sessions: sampleSessions());
        final NavigatorState nav = tester.state(find.byType(Navigator).first);

        // Results for a reviewed session (has confirmed + rejected events).
        final Session session = sampleSessions().first;
        nav.push(MaterialPageRoute<void>(
            builder: (_) => ResultsScreen(session: session)));
        await tester.pumpAndSettle();
        expect(find.text('Session results'), findsOneWidget);
        // Body content must render (guards against a bottom bar filling the
        // screen and collapsing the body).
        expect(find.text('SESSION'), findsOneWidget);
        expect(tester.getSize(find.byType(ListView).first).height,
            greaterThan(vp.value.height * 0.3));
        // Scroll the whole page to build and lay out every section.
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -4000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        nav.push(MaterialPageRoute<void>(builder: (_) => const SessionSetupScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Continue to timer'), findsOneWidget);
        expect(find.text('Configure this session'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
