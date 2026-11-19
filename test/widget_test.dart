import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/app.dart';
import 'package:shot_timer_ai/providers/app_status_provider.dart';
import 'package:shot_timer_ai/providers/session_history_provider.dart';
import 'package:shot_timer_ai/providers/settings_provider.dart';
import 'package:shot_timer_ai/services/persistence/settings_repository.dart';

void main() {
  testWidgets('RangePulse app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider
              .overrideWithValue(InMemorySessionRepository()),
          settingsRepositoryProvider
              .overrideWithValue(InMemorySettingsRepository()),
          micPermissionProvider
              .overrideWith((ref) async => MicPermission.granted),
          modelBundledProvider.overrideWith((ref) async => false),
        ],
        child: const ShotTimerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Dashboard renders brand, primary action, and navigation.
    expect(find.text('RangePulse'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Start new session'), findsWidgets);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Start a timed session'), findsOneWidget);
  });
}
