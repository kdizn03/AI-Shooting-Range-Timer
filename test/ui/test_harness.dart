import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:shot_timer_ai/app.dart';
import 'package:shot_timer_ai/models/app_settings.dart';
import 'package:shot_timer_ai/models/firearm_profile.dart';
import 'package:shot_timer_ai/models/microphone.dart';
import 'package:shot_timer_ai/models/session.dart';
import 'package:shot_timer_ai/models/shot_event.dart';
import 'package:shot_timer_ai/providers/app_status_provider.dart';
import 'package:shot_timer_ai/providers/audio_input_provider.dart';
import 'package:shot_timer_ai/providers/session_history_provider.dart';
import 'package:shot_timer_ai/providers/settings_provider.dart';
import 'package:shot_timer_ai/services/audio/microphone_manager.dart';
import 'package:shot_timer_ai/services/persistence/settings_repository.dart';

import '../support/fake_audio_service.dart';

/// Inputs reported in UI tests: Android-style labels for one built-in and
/// one USB microphone.
const List<InputDevice> kTestInputs = [
  InputDevice(id: '1', label: 'Pixel (built-in microphone)'),
  InputDevice(id: '9', label: 'RØDE VideoMic NTG (USB device)'),
];

/// A manager that reports [inputs] instead of asking the platform.
MicrophoneManager fakeMicrophones([List<InputDevice> inputs = kTestInputs]) =>
    MicrophoneManager(platform: MicPlatform.android, lister: () async => inputs);

/// Viewports covering every size class, including phone landscape.
const Map<String, Size> kViewports = {
  'phone 360x780': Size(360, 780),
  'phone-landscape 780x360': Size(780, 360),
  'large-phone 700x1000': Size(700, 1000),
  'tablet 900x1180': Size(900, 1180),
  'desktop 1280x800': Size(1280, 800),
  'large-desktop 1600x1000': Size(1600, 1000),
};

/// Sets the physical window size for a test and resets it afterwards.
void setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Realistic stored sessions: live and simulated, reviewed and not.
List<Session> sampleSessions() {
  final DateTime now = DateTime.now();
  ShotEvent shot(int n, int ms, double conf, [ReviewStatus r = ReviewStatus.unreviewed]) =>
      ShotEvent(
        shotNumber: n,
        elapsedTime: Duration(milliseconds: ms),
        confidence: conf,
        detectionTimestamp: now,
        peakDecibels: 158,
        reviewStatus: r,
      );
  return [
    for (int d = 0; d < 9; d++)
      Session(
        id: 'live-$d',
        startTime: now.subtract(Duration(days: d * 2, hours: 1)),
        endTime: now.subtract(Duration(days: d * 2, hours: 1)).add(Duration(seconds: 25 + d * 7)),
        status: SessionStatus.completed,
        confidenceThreshold: 0.7,
        firearmProfile: d.isEven
            ? FirearmProfile.glock19Unsuppressed
            : FirearmProfile.glock19Suppressed,
        pausedDuration: d == 1 ? const Duration(seconds: 4) : Duration.zero,
        shots: [
          shot(1, 1420 + d * 40, 0.93, ReviewStatus.confirmed),
          shot(2, 2870 + d * 60, 0.74),
          shot(3, 4310 + d * 30, 0.88, d == 0 ? ReviewStatus.rejected : ReviewStatus.unreviewed),
          shot(4, 5600 + d * 90, 0.91),
        ],
      ),
    Session(
      id: 'sim-0',
      startTime: now.subtract(const Duration(hours: 3)),
      endTime: now.subtract(const Duration(hours: 3)).add(const Duration(seconds: 12)),
      status: SessionStatus.completed,
      isSimulated: true,
      shots: [shot(1, 1800, 0.9), shot(2, 3400, 0.95)],
    ),
  ];
}

/// Pumps the full app with in-memory storage and deterministic platform
/// status. Returns the provider container for state inspection.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  List<Session> sessions = const [],
  AppSettings settings = const AppSettings(),
}) async {
  final InMemorySessionRepository repo = InMemorySessionRepository();
  for (final Session s in sessions) {
    await repo.saveSession(s);
  }
  final ProviderContainer container = ProviderContainer(overrides: [
    sessionRepositoryProvider.overrideWithValue(repo),
    settingsRepositoryProvider
        .overrideWithValue(InMemorySettingsRepository(settings)),
    micPermissionProvider.overrideWith((ref) async => MicPermission.granted),
    modelBundledProvider.overrideWith((ref) async => false),
    microphoneManagerProvider.overrideWithValue(fakeMicrophones()),
    audioServiceFactoryProvider.overrideWithValue(FakeAudioService.new),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ShotTimerApp()),
  );
  await tester.pumpAndSettle();
  return container;
}
