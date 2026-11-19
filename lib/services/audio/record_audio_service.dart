import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/constants.dart';
import '../../core/errors/failures.dart';
import '../../models/microphone.dart';
import 'audio_service.dart';
import 'microphone_manager.dart';

/// Implementation of [AudioService] using the `record` package.
///
/// Records from [selection] when it is connected. When it is not, the OS
/// default input is used and [route] says so (`selectedMissing`), so
/// callers can tell the user instead of pretending.
class RecordAudioService implements AudioService {
  /// Creates a service for [selection] (the OS default when omitted).
  RecordAudioService({
    this.selection = MicSelection.systemDefault,
    MicrophoneManager? microphones,
  }) : _microphones = microphones;

  /// The input the user chose.
  final MicSelection selection;

  final MicrophoneManager? _microphones;
  final AudioRecorder _recorder = AudioRecorder();
  MicRoute? _route;

  @override
  MicRoute? get route => _route;
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription<Uint8List>? _recordSubscription;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<Uint8List> get audioStream {
    if (_audioStreamController == null) {
      throw const AudioStreamException('Audio stream has not been initialized. Call startRecording first.');
    }
    return _audioStreamController!.stream;
  }

  @override
  Future<bool> hasPermission() async {
    if (kIsWeb) return true;
    return Permission.microphone.isGranted;
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  @override
  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPerm = await requestPermission();
    if (!hasPerm) {
      throw const MicrophonePermissionDeniedException('Microphone permission denied.');
    }

    final MicDevice? device = await _resolveDevice();

    try {
      _audioStreamController = StreamController<Uint8List>.broadcast();

      final recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AudioConstants.sampleRate,
        numChannels: AudioConstants.channels,
        echoCancel: false,
        autoGain: false,
        noiseSuppress: false,
        device: device == null
            ? null
            : InputDevice(id: device.id, label: device.label),
      );

      final stream = await _recorder.startStream(recordConfig);
      _recordSubscription = stream.listen(
        (Uint8List data) {
          _audioStreamController?.add(data);
        },
        onError: (Object error) {
          _audioStreamController?.addError(AudioStreamException(error.toString()));
        },
        onDone: () {
          _audioStreamController?.close();
        },
      );
      
      _isRecording = true;
    } catch (e) {
      throw MicrophoneUnavailableException('Failed to start microphone recording: $e');
    }
  }

  /// Finds [selection] among the connected inputs and records the route.
  Future<MicDevice?> _resolveDevice() async {
    if (selection.isSystemDefault) {
      _route = MicRoute(selection: selection);
      return null;
    }
    List<MicDevice> devices = const [];
    try {
      final MicrophoneManager m =
          _microphones ?? MicrophoneManager(lister: _recorder.listInputDevices);
      devices = await m.listInputs();
    } catch (e) {
      debugPrint('Could not list audio inputs: $e');
    }
    final MicDevice? device = selection.resolve(devices);
    _route = MicRoute(
      selection: selection,
      device: device,
      selectedMissing: device == null,
    );
    return device;
  }

  @override
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    await _recordSubscription?.cancel();
    _recordSubscription = null;
    await _recorder.stop();
    await _audioStreamController?.close();
    _audioStreamController = null;
    _isRecording = false;
  }

  @override
  Future<void> dispose() async {
    await stopRecording();
    await _recorder.dispose();
  }
}
