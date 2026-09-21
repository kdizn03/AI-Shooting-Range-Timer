import 'audio_classifier.dart';
import 'classifier_factory_web.dart'
    if (dart.library.io) 'classifier_factory_io.dart';

/// Creates the appropriate [AudioClassifier] depending on platform capabilities:
/// - Native (Android, iOS, Windows, etc.): [TFLiteAudioClassifier]
/// - Web: [EnergyClassifier] (since `dart:ffi` is unsupported on web)
AudioClassifier createAudioClassifier() => getAudioClassifier();

