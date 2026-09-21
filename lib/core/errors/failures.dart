/// Custom exception and failure classes for Shot Timer AI.
///
/// Provides a structured error hierarchy for the application's
/// various failure modes across audio, ML, and persistence layers.
library;

/// Base class for all application-specific exceptions.
sealed class AppException implements Exception {
  /// Creates an [AppException] with an error [message] and optional [cause].
  const AppException(this.message, [this.cause]);

  /// Human-readable error description.
  final String message;

  /// The original exception that caused this failure, if any.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the microphone permission is denied by the user.
class MicrophonePermissionDeniedException extends AppException {
  /// Creates a [MicrophonePermissionDeniedException].
  const MicrophonePermissionDeniedException([
    super.message = 'Microphone permission denied',
    super.cause,
  ]);
}

/// Thrown when the microphone hardware is unavailable.
class MicrophoneUnavailableException extends AppException {
  /// Creates a [MicrophoneUnavailableException].
  const MicrophoneUnavailableException([
    super.message = 'Microphone hardware unavailable',
    super.cause,
  ]);
}

/// Thrown when the audio stream fails unexpectedly.
class AudioStreamException extends AppException {
  /// Creates an [AudioStreamException].
  const AudioStreamException([
    super.message = 'Audio stream failure',
    super.cause,
  ]);
}

/// Thrown when the TFLite model fails to load.
class ModelLoadException extends AppException {
  /// Creates a [ModelLoadException].
  const ModelLoadException([
    super.message = 'Failed to load AI model',
    super.cause,
  ]);
}

/// Thrown when inference receives an invalid audio frame.
class InvalidAudioFrameException extends AppException {
  /// Creates an [InvalidAudioFrameException].
  const InvalidAudioFrameException([
    super.message = 'Invalid audio frame for inference',
    super.cause,
  ]);
}

/// Thrown when a session operation fails.
class SessionException extends AppException {
  /// Creates a [SessionException].
  const SessionException([
    super.message = 'Session operation failed',
    super.cause,
  ]);
}

/// Thrown when data persistence fails.
class PersistenceException extends AppException {
  /// Creates a [PersistenceException].
  const PersistenceException([
    super.message = 'Data persistence failure',
    super.cause,
  ]);
}

