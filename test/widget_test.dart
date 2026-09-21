import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/app.dart';

void main() {
  testWidgets('Shot Timer AI app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ShotTimerApp(),
      ),
    );

    // Verify home screen renders title
    expect(find.text('Shot Timer AI'), findsOneWidget);
    expect(find.text('Start Session'), findsOneWidget);
    expect(find.text('Session History'), findsOneWidget);
  });
}
