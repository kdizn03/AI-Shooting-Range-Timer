import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../models/microphone.dart';

/// Lists the inputs the platform reports, as raw `record` devices.
typedef InputLister = Future<List<InputDevice>> Function();

/// The platform family this build runs on.
MicPlatform get currentMicPlatform {
  if (kIsWeb) return MicPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => MicPlatform.android,
    TargetPlatform.iOS => MicPlatform.ios,
    _ => MicPlatform.desktop,
  };
}

/// Whether the selected input is still reported by the platform.
enum MicPresence {
  /// Listed by the platform.
  connected,

  /// Not listed: unplugged, switched off or out of range.
  missing,

  /// The platform's device list could not be read.
  unknown,
}

/// Lists audio inputs and watches whether the selected one is connected.
///
/// Uses only what the `record` plugin exposes: an ID and a label per input.
/// There is no connection-change event, so [watch] re-reads the list on a
/// timer.
class MicrophoneManager {
  MicrophoneManager({InputLister? lister, MicPlatform? platform})
      : platform = platform ?? currentMicPlatform,
        _lister = lister;

  final MicPlatform platform;
  final InputLister? _lister;
  AudioRecorder? _recorder;

  /// Whether the input list can be polled during a session without
  /// disturbing recording. On iOS, listing inputs reconfigures the shared
  /// audio session, so it is not done while recording.
  bool get canMonitorDuringSession => platform != MicPlatform.ios;

  /// Whether input names are hidden until microphone permission is granted
  /// (browsers do this).
  bool get labelsNeedPermission => platform == MicPlatform.web;

  Future<List<InputDevice>> _listRaw() {
    final InputLister? l = _lister;
    if (l != null) return l();
    return (_recorder ??= AudioRecorder()).listInputDevices();
  }

  /// Inputs the platform reports now, classified by kind.
  Future<List<MicDevice>> listInputs() async {
    final List<InputDevice> raw = await _listRaw();
    final Set<String> seen = <String>{};
    return [
      for (final InputDevice d in raw)
        if (seen.add(d.id))
          MicDevice(
            id: d.id,
            label: d.label,
            kind: classifyMicLabel(d.label, platform),
          ),
    ];
  }

  /// Presence of [selection] now. The system default is always connected.
  Future<MicPresence> presenceOf(MicSelection selection) async {
    if (selection.isSystemDefault) return MicPresence.connected;
    try {
      return selection.resolve(await listInputs()) != null
          ? MicPresence.connected
          : MicPresence.missing;
    } catch (e) {
      debugPrint('Could not list audio inputs: $e');
      return MicPresence.unknown;
    }
  }

  /// Emits [selection]'s presence every [interval], and once immediately.
  /// Only changes are emitted after the first value.
  Stream<MicPresence> watch(MicSelection selection,
      {Duration interval = const Duration(seconds: 3)}) {
    // Closed in onCancel, when the listener goes away.
    // ignore: close_sinks
    late final StreamController<MicPresence> controller;
    Timer? timer;
    MicPresence? last;
    Future<void> check() async {
      final MicPresence p = await presenceOf(selection);
      if (controller.isClosed || p == last) return;
      last = p;
      controller.add(p);
    }

    controller = StreamController<MicPresence>(
      onListen: () {
        unawaited(check());
        timer = Timer.periodic(interval, (_) => unawaited(check()));
      },
      onCancel: () {
        timer?.cancel();
        return controller.close();
      },
    );
    return controller.stream;
  }

  Future<void> dispose() async {
    await _recorder?.dispose();
    _recorder = null;
  }
}
