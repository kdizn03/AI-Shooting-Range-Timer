import 'audio_classifier.dart';
import 'energy_classifier.dart';

/// Returns an EnergyClassifier fallback for web environments where TFLite FFI is unavailable.
AudioClassifier getAudioClassifier() => EnergyClassifier();

