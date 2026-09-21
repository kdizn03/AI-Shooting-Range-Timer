import 'dart:typed_data';

/// Abstract interface for audio preprocessing.
///
/// Converts raw PCM audio data into the feature representation
/// expected by the AI classifier (log-Mel spectrogram).
abstract class AudioPreprocessor {
  /// Converts raw PCM16 audio bytes into a normalized feature vector.
  ///
  /// [pcmData] is a [Uint8List] of signed 16-bit PCM samples.
  ///
  /// Returns a [Float32List] containing the log-Mel spectrogram
  /// features ready for model inference.
  ///
  /// Throws [InvalidAudioFrameException] if [pcmData] is too short
  /// or contains invalid samples.
  Float32List processAudioFrame(Uint8List pcmData);

  /// Converts raw PCM16 bytes to normalized float samples (-1.0 to 1.0).
  ///
  /// [pcmData] is a [Uint8List] of signed 16-bit little-endian PCM samples.
  Float32List pcmToFloat(Uint8List pcmData);

  /// Computes the log-Mel spectrogram from float audio samples.
  ///
  /// [samples] is a [Float32List] of normalized audio samples.
  ///
  /// Returns a [Float32List] of log-Mel spectrogram values with
  /// shape [nMels × nFrames], flattened in row-major order.
  Float32List computeLogMelSpectrogram(Float32List samples);
}

