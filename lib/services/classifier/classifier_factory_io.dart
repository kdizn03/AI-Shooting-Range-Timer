import 'audio_classifier.dart';
import 'tflite_audio_classifier.dart';

/// Returns a TFLite-based classifier for native platforms (Android, iOS, Windows, macOS, Linux).
AudioClassifier getAudioClassifier() => TFLiteAudioClassifier();

