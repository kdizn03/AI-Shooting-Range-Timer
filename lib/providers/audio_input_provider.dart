import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/microphone.dart';
import '../services/audio/audio_level_monitor.dart';
import '../services/audio/audio_service.dart';
import '../services/audio/microphone_manager.dart';
import '../services/audio/record_audio_service.dart';
import 'settings_provider.dart';

/// Lists inputs and watches the selected one. Override in tests.
final microphoneManagerProvider = Provider<MicrophoneManager>((ref) {
  final MicrophoneManager m = MicrophoneManager();
  ref.onDispose(m.dispose);
  return m;
});

/// The microphone the user selected in Settings.
final micSelectionProvider = Provider<MicSelection>(
  (ref) => ref.watch(settingsProvider.select((s) => s.micSelection)),
);

/// Creates the microphone source used by sessions, the Settings level
/// monitor and calibration, for the selected input. Override in tests to
/// supply a fake, so no real microphone is opened.
final audioServiceFactoryProvider = Provider<AudioService Function()>((ref) {
  final MicSelection selection = ref.watch(micSelectionProvider);
  final MicrophoneManager manager = ref.watch(microphoneManagerProvider);
  return () => RecordAudioService(selection: selection, microphones: manager);
});

/// One live level monitor shared by the Settings sections, so the
/// microphone is opened once. It is rebuilt (and the old one closed) when
/// the selected input changes.
final levelMonitorProvider = Provider.autoDispose<AudioLevelMonitor>((ref) {
  final AudioLevelMonitor monitor = AudioLevelMonitor(
    createAudio: ref.watch(audioServiceFactoryProvider),
  );
  ref.onDispose(monitor.dispose);
  return monitor;
});

/// Inputs the platform reports. Refresh with `ref.invalidate`.
final micDevicesProvider = FutureProvider.autoDispose<List<MicDevice>>(
  (ref) => ref.watch(microphoneManagerProvider).listInputs(),
);
