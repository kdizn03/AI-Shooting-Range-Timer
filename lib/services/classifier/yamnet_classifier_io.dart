import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/errors/failures.dart';
import 'audio_classification.dart';
import 'waveform_classifier.dart';
import 'yamnet_labels.dart';

/// YAMNet on Android, iOS and desktop, through `tflite_flutter`.
///
/// The bundled model takes a flat `[15600]` float32 waveform and returns
/// `[1, 521]` class scores.
class YamnetClassifier implements WaveformClassifier {
  Interpreter? _interpreter;

  @override
  bool get isReady => _interpreter != null;

  @override
  String get engineLabel => 'YAMNet AI';

  @override
  int get inputSamples => Yamnet.inputSamples;

  @override
  int get preRollSamples => Yamnet.preRollSamples;

  @override
  Future<void> loadModel() async {
    if (_interpreter != null) return;
    try {
      final Interpreter interpreter =
          await Interpreter.fromAsset(Yamnet.modelAssetPath);
      final int inputLength =
          interpreter.getInputTensor(0).shape.fold(1, (a, b) => a * b);
      final List<int> outShape = interpreter.getOutputTensor(0).shape;
      if (inputLength != Yamnet.inputSamples ||
          outShape.isEmpty ||
          outShape.last != Yamnet.classCount) {
        interpreter.close();
        throw ModelLoadException(
            'Unexpected YAMNet tensors: input $inputLength, output $outShape');
      }
      _interpreter = interpreter;
    } on ModelLoadException {
      rethrow;
    } catch (e) {
      throw ModelLoadException('Could not load YAMNet: $e');
    }
  }

  @override
  Future<AudioClassification> classifyWaveform(Float32List samples) async {
    final Interpreter? interpreter = _interpreter;
    if (interpreter == null) {
      throw const ModelLoadException('YAMNet is not loaded.');
    }
    if (samples.length != Yamnet.inputSamples) {
      throw InvalidAudioFrameException(
          'YAMNet needs ${Yamnet.inputSamples} samples, got ${samples.length}.');
    }
    final int outLength =
        interpreter.getOutputTensor(0).shape.fold(1, (a, b) => a * b);
    final Float32List out = Float32List(outLength);
    interpreter.run(
      samples.buffer.asUint8List(samples.offsetInBytes, samples.lengthInBytes),
      out.buffer,
    );
    // Several frames would come back as consecutive rows; keep each class's
    // highest score.
    final List<double> scores = List<double>.filled(Yamnet.classCount, 0);
    for (int i = 0; i < out.length; i++) {
      final int c = i % Yamnet.classCount;
      if (out[i] > scores[c]) scores[c] = out[i];
    }
    return classificationFromYamnetScores(scores, timestamp: DateTime.now());
  }

  @override
  Future<AudioClassification> classify(Float32List features) {
    throw UnsupportedError('YAMNet classifies waveforms; use classifyWaveform.');
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}
