import 'audio_classification.dart';

/// YAMNet model facts and how its 521 AudioSet classes map to [AudioLabel].
///
/// Indices come from assets/models/yamnet_class_map.csv (Google's class map,
/// bundled with the model).
abstract final class Yamnet {
  /// Bundled model asset (MediaPipe's float32 YAMNet, Apache 2.0).
  static const String modelAssetPath = 'assets/models/yamnet.tflite';

  /// Number of classes the model scores.
  static const int classCount = 521;

  /// Samples per inference: 0.975 s of 16 kHz mono audio.
  static const int inputSamples = 15600;

  /// Samples kept before a sound's peak, so the clip holds its onset.
  /// The remaining ~0.575 s after the peak holds its decay and echo.
  static const int preRollSamples = 6400;

  /// Explosion, Gunshot/gunfire, Machine gun, Fusillade, Artillery fire,
  /// Cap gun. Close-range shots often score highest on Explosion or Cap gun.
  static const List<int> gunshot = [420, 421, 422, 423, 424, 425];

  /// Speech, shouting, laughter and crowd babble.
  static const List<int> voice = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 65, //
  ];

  /// Beeps, tones, buzzers and alarms, including timer beeps.
  static const List<int> beep = [313, 382, 389, 392, 475, 476, 477, 495, 497];

  /// Other sharp sounds: claps, hands, slaps, knocks, slams, bangs,
  /// fireworks, pops. In testing, real shots also scored high here
  /// ("Slap, smack", "Hands"), so this group never overrides a gunshot.
  static const List<int> otherLoud = [
    56, 57, 58, 62, 348, 352, 353, 354, 413, 426, 427, 428, 434, 454, 460, //
    461, 462, 463, 464,
  ];

  /// Silence and noise classes.
  static const List<int> background = [
    494, 507, 508, 509, 510, 514, 515, //
  ];
}

double _maxOf(List<double> scores, List<int> indices) {
  double best = 0;
  for (final int i in indices) {
    if (i < scores.length && scores[i] > best) best = scores[i];
  }
  return best;
}

/// Converts YAMNet's per-class scores into an [AudioClassification].
///
/// Each group's score is its strongest class. YAMNet's scores are
/// independent (they do not sum to 1), so the gunshot score is reported as
/// is and compared against the YAMNet threshold.
///
/// The label is gunshot when the gunshot score is above zero and at least as
/// strong as voice and beep. The other-loud group does not compete, because
/// YAMNet confuses close-range shots with slaps and claps. Otherwise the
/// strongest remaining group wins.
AudioClassification classificationFromYamnetScores(
  List<double> scores, {
  required DateTime timestamp,
  double peakDbFs = 0.0,
  double estimatedDbSpl = 160.0,
}) {
  final Map<AudioLabel, double> groups = {
    AudioLabel.gunshot: _maxOf(scores, Yamnet.gunshot),
    AudioLabel.voice: _maxOf(scores, Yamnet.voice),
    AudioLabel.beep: _maxOf(scores, Yamnet.beep),
    AudioLabel.otherLoudSound: _maxOf(scores, Yamnet.otherLoud),
    AudioLabel.backgroundNoise: _maxOf(scores, Yamnet.background),
  };

  final double g = groups[AudioLabel.gunshot]!;
  AudioLabel label;
  if (g > 0 && g >= groups[AudioLabel.voice]! && g >= groups[AudioLabel.beep]!) {
    label = AudioLabel.gunshot;
  } else {
    // Background wins ties, so all-zero scores never name a sound.
    label = AudioLabel.backgroundNoise;
    double best = groups[AudioLabel.backgroundNoise]!;
    for (final AudioLabel l in const [
      AudioLabel.voice,
      AudioLabel.beep,
      AudioLabel.otherLoudSound,
    ]) {
      if (groups[l]! > best) {
        best = groups[l]!;
        label = l;
      }
    }
  }

  return AudioClassification(
    label: label,
    confidence: groups[label]!,
    scores: groups,
    timestamp: timestamp,
    peakDbFs: peakDbFs,
    estimatedDbSpl: estimatedDbSpl,
  );
}
