import 'dart:async';
import 'dart:typed_data';

import 'package:shot_timer_ai/models/microphone.dart';
import 'package:shot_timer_ai/services/audio/audio_service.dart';

/// In-memory microphone. Tests push PCM in; the monitor reads it as it
/// would from the real recorder.
class FakeAudioService implements AudioService {
  FakeAudioService({this.permission = true, this.fakeRoute});

  final bool permission;

  /// Route reported after [startRecording]; the system default if null.
  final MicRoute? fakeRoute;

  @override
  MicRoute? route;
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  bool _recording = false;
  int startCount = 0;
  int stopCount = 0;

  void emit(Uint8List bytes) => _controller.add(bytes);

  @override
  bool get isRecording => _recording;

  @override
  Stream<Uint8List> get audioStream => _controller.stream;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> startRecording() async {
    startCount++;
    _recording = true;
    route = fakeRoute ?? const MicRoute(selection: MicSelection.systemDefault);
  }

  @override
  Future<void> stopRecording() async {
    stopCount++;
    _recording = false;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

