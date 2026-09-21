import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/constants.dart';
import '../../core/errors/failures.dart';
import 'audio_service.dart';

/// Implementation of [AudioService] using the `record` package.
class RecordAudioService implements AudioService {
  final AudioRecorder _recorder = AudioRecorder();
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

    try {
      _audioStreamController = StreamController<Uint8List>.broadcast();
      
      const recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AudioConstants.sampleRate,
        numChannels: AudioConstants.channels,
        echoCancel: false,
        autoGain: false,
        noiseSuppress: false,
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
