import 'dart:async';
import 'dart:typed_data';

/// Abstract interface for microphone audio acquisition.
///
/// Implementations handle platform-specific microphone access,
/// permission requests, and real-time PCM audio streaming.
///
/// The audio service does NOT perform classification — it only
/// provides raw audio data to downstream consumers.
abstract class AudioService {
  /// Whether the microphone is currently streaming audio.
  bool get isRecording;

  /// Stream of raw PCM audio data chunks.
  ///
  /// Each chunk is a [Uint8List] of PCM16 samples at the configured
  /// sample rate. The stream emits data continuously while recording.
  Stream<Uint8List> get audioStream;

  /// Checks if microphone permission has been granted.
  ///
  /// Returns `true` if the app has permission to record audio.
  Future<bool> hasPermission();

  /// Requests microphone permission from the user.
  ///
  /// Returns `true` if permission was granted.
  Future<bool> requestPermission();

  /// Starts streaming audio from the device microphone.
  ///
  /// Throws [MicrophonePermissionDeniedException] if permission
  /// has not been granted.
  /// Throws [MicrophoneUnavailableException] if the microphone
  /// hardware is not available.
  Future<void> startRecording();

  /// Stops the audio stream and releases microphone resources.
  Future<void> stopRecording();

  /// Releases all resources held by this service.
  Future<void> dispose();
}

