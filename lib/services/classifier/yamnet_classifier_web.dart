import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import '../../core/constants.dart';
import '../../core/errors/failures.dart';
import 'audio_classification.dart';
import 'waveform_classifier.dart';
import 'yamnet_labels.dart';

/// The functions exported by web/mediapipe/yamnet_bridge.js.
extension type _Bridge._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> load(JSString modelUrl);
  external JSFloat32Array classify(JSFloat32Array samples, JSNumber sampleRate);
  external void close();
}

/// YAMNet in the browser, through MediaPipe's audio classifier (WebAssembly).
///
/// The runtime and bridge are self-hosted under web/mediapipe/, and the
/// model is the same bundled asset the native build uses. Inference runs on
/// the page's thread, but only for sounds that pass the decibel gate
/// (about 18 ms per check on a laptop).
class YamnetClassifier implements WaveformClassifier {
  _Bridge? _bridge;

  @override
  bool get isReady => _bridge != null;

  @override
  String get engineLabel => 'YAMNet AI';

  @override
  int get inputSamples => Yamnet.inputSamples;

  @override
  int get preRollSamples => Yamnet.preRollSamples;

  static Uri _resolve(String path) {
    final Object? base =
        (globalContext['document'] as JSObject?)?['baseURI']?.dartify();
    return (base is String ? Uri.parse(base) : Uri.base).resolve(path);
  }

  @override
  Future<void> loadModel() async {
    if (_bridge != null) return;
    try {
      final JSObject module = await importModule(
              _resolve('mediapipe/yamnet_bridge.js').toString().toJS)
          .toDart;
      final _Bridge bridge = module as _Bridge;
      // Flutter web serves assets under assets/<asset path>.
      await bridge
          .load(_resolve('assets/${Yamnet.modelAssetPath}').toString().toJS)
          .toDart;
      _bridge = bridge;
    } catch (e) {
      throw ModelLoadException('Could not load YAMNet in the browser: $e');
    }
  }

  @override
  Future<AudioClassification> classifyWaveform(Float32List samples) async {
    final _Bridge? bridge = _bridge;
    if (bridge == null) {
      throw const ModelLoadException('YAMNet is not loaded.');
    }
    if (samples.length != Yamnet.inputSamples) {
      throw InvalidAudioFrameException(
          'YAMNet needs ${Yamnet.inputSamples} samples, got ${samples.length}.');
    }
    final Float32List scores = bridge
        .classify(samples.toJS, AudioConstants.sampleRate.toJS)
        .toDart;
    return classificationFromYamnetScores(scores, timestamp: DateTime.now());
  }

  @override
  Future<AudioClassification> classify(Float32List features) {
    throw UnsupportedError('YAMNet classifies waveforms; use classifyWaveform.');
  }

  @override
  Future<void> dispose() async {
    _bridge?.close();
    _bridge = null;
  }
}
