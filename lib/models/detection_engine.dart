/// Which classifier decides whether a loud sound is a gunshot.
///
/// Each engine has its own threshold scale, because their scores mean
/// different things:
/// - [yamnet] reports YAMNet's independent "gunshot" class score. Real shots
///   in testing scored roughly 0.2–0.7, so its range sits low.
/// - [energy] reports a heuristic confidence that behaves like a percentage.
enum DetectionEngine {
  /// Google's YAMNet audio event model, run on the device.
  yamnet(
    label: 'YAMNet AI',
    thresholdName: 'Gunshot score threshold',
    thresholdHelp: 'Minimum YAMNet gunshot score for a sound to count. YAMNet '
        'scores each sound type separately, so real shots often score '
        '20–70%. Lower catches more shots but admits more look-alikes such as '
        'claps and slams.',
    minThreshold: 0.05,
    maxThreshold: 0.9,
    divisions: 17,
    defaultThreshold: 0.15,
  ),

  /// The built-in loudness heuristic: no model, looks for sharp peaks.
  energy(
    label: 'Energy heuristic',
    thresholdName: 'Confidence threshold',
    thresholdHelp: 'Minimum heuristic confidence for a detection. Lower '
        'catches quieter shots but admits more false detections.',
    minThreshold: 0.3,
    maxThreshold: 0.95,
    divisions: 13,
    defaultThreshold: 0.7,
  );

  const DetectionEngine({
    required this.label,
    required this.thresholdName,
    required this.thresholdHelp,
    required this.minThreshold,
    required this.maxThreshold,
    required this.divisions,
    required this.defaultThreshold,
  });

  /// Short name shown on controls.
  final String label;

  /// Name of this engine's threshold control.
  final String thresholdName;

  /// Explanation shown under the threshold control.
  final String thresholdHelp;

  /// Lowest allowed threshold.
  final double minThreshold;

  /// Highest allowed threshold.
  final double maxThreshold;

  /// Slider steps across the range (0.05 per step).
  final int divisions;

  /// Threshold used when none is stored.
  final double defaultThreshold;

  /// Clamps [value] into this engine's range; non-finite becomes the default.
  double clampThreshold(double value) => value.isFinite
      ? value.clamp(minThreshold, maxThreshold).toDouble()
      : defaultThreshold;
}
