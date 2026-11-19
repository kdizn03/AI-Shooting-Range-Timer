import 'dart:typed_data';

import 'audio_classification.dart';
import 'audio_classifier.dart';

/// A classifier that works on raw audio around a sound instead of on each
/// 250 ms window's spectrogram.
///
/// The [AudioPipeline] runs it only on windows whose peak passes the
/// decibel gate. It waits until [inputSamples] of audio are available
/// around the peak ([preRollSamples] before it), then calls
/// [classifyWaveform]. Windows that are not examined are reported as
/// [AudioClassification.levelOnly].
///
/// [classify] (spectrogram input) is not used for these classifiers.
abstract class WaveformClassifier implements AudioClassifier {
  /// Samples per inference at 16 kHz.
  int get inputSamples;

  /// Samples taken before the peak.
  int get preRollSamples;

  /// Classifies [samples]: mono 16 kHz audio scaled to -1..1, exactly
  /// [inputSamples] long.
  ///
  /// The returned timestamp and levels are placeholders; the pipeline
  /// replaces them with the peak's time and level.
  Future<AudioClassification> classifyWaveform(Float32List samples);
}
