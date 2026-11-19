import 'package:flutter/foundation.dart';

import '../../models/detection_engine.dart';
import 'audio_classifier.dart';
import 'energy_classifier.dart';
import 'yamnet_classifier_web.dart'
    if (dart.library.io) 'yamnet_classifier_io.dart';

/// A loaded classifier, plus why it is not the one requested (if so).
class LoadedClassifier {
  /// Creates a [LoadedClassifier].
  const LoadedClassifier(this.classifier, {this.fallbackReason});

  /// Ready to use: [AudioClassifier.loadModel] has completed.
  final AudioClassifier classifier;

  /// Set when the requested engine failed to load and the energy heuristic
  /// is used instead.
  final String? fallbackReason;

  /// Label for status displays, including the fallback when there is one.
  String get engineLabel => fallbackReason == null
      ? classifier.engineLabel
      : '${classifier.engineLabel} (YAMNet unavailable)';
}

/// Creates and loads the classifier for [engine].
///
/// YAMNet runs through TFLite on Android, iOS and desktop, and through
/// MediaPipe (WebAssembly) on the web. If it fails to load, this falls back
/// to [EnergyClassifier] and says why, so a session can still run.
///
/// [createYamnet] replaces the YAMNet classifier in tests.
Future<LoadedClassifier> loadAudioClassifier(
  DetectionEngine engine, {
  AudioClassifier Function()? createYamnet,
}) async {
  if (engine == DetectionEngine.yamnet) {
    final AudioClassifier yamnet = (createYamnet ?? YamnetClassifier.new)();
    try {
      await yamnet.loadModel();
      return LoadedClassifier(yamnet);
    } catch (e) {
      debugPrint('YAMNet failed to load, using energy heuristic: $e');
      await yamnet.dispose();
      final EnergyClassifier energy = EnergyClassifier();
      await energy.loadModel();
      return LoadedClassifier(energy, fallbackReason: '$e');
    }
  }
  final EnergyClassifier energy = EnergyClassifier();
  await energy.loadModel();
  return LoadedClassifier(energy);
}
