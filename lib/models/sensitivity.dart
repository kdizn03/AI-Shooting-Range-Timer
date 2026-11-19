import 'firearm_profile.dart';

/// Where the decibel gate comes from.
///
/// - [preset]: the selected firearm profile's built-in gate.
/// - [custom]: the user's own dBFS threshold (see [AppSettings]).
enum SensitivityMode { preset, custom }

/// Valid range and default for the custom threshold, in dBFS.
///
/// dBFS is the level of a digital sample relative to full scale (0 dBFS is
/// the loudest value the 16-bit microphone stream can represent). It is NOT
/// microphone gain, preamp sensitivity, or acoustic dB SPL. A more negative
/// threshold is more sensitive: it accepts quieter sounds.
abstract final class SensitivityLimits {
  /// Most sensitive value allowed (quietest sound that can count).
  static const double minDbFs = -60;

  /// Least sensitive value allowed.
  static const double maxDbFs = -1;

  /// Slider steps: one per dB across the range.
  static const int divisions = 59;

  /// Value used when no valid custom threshold is stored.
  static const double defaultDbFs = -30;

  /// Whether [value] is a finite number inside [minDbFs]..[maxDbFs].
  static bool isValid(double value) =>
      value.isFinite && value >= minDbFs && value <= maxDbFs;

  /// Clamps [value] into range. Non-finite input becomes [defaultDbFs].
  static double clamp(double value) =>
      value.isFinite ? value.clamp(minDbFs, maxDbFs).toDouble() : defaultDbFs;

  /// Formats a threshold for display, e.g. `-30.0 dBFS`.
  static String format(double value) => '${value.toStringAsFixed(1)} dBFS';
}

/// A named starting threshold for custom sensitivity.
class SensitivityPreset {
  const SensitivityPreset(this.label, this.dbFs);

  /// Shown on the chip, e.g. `Medium`.
  final String label;

  /// Threshold in dBFS.
  final double dbFs;
}

/// Starting points for custom sensitivity.
///
/// These are editorial defaults, not detection standards. Change the values
/// here to retune the chips; nothing else depends on them.
const List<SensitivityPreset> kSensitivityPresets = [
  SensitivityPreset('Very High', -45),
  SensitivityPreset('High', -38),
  SensitivityPreset('Medium', -30),
  SensitivityPreset('Low', -22),
  SensitivityPreset('Very Low', -15),
];

/// Returns the firearm profile the detector should use.
///
/// In [SensitivityMode.preset] the [base] profile is returned unchanged. In
/// [SensitivityMode.custom] its gate is replaced by [customDbFs], and the
/// display name says so, so saved sessions record the gate that was really
/// used.
FirearmProfile applySensitivity(
  FirearmProfile base,
  SensitivityMode mode,
  double customDbFs,
) {
  if (mode == SensitivityMode.preset) return base;
  final double gate = SensitivityLimits.clamp(customDbFs);
  return base.copyWith(
    minPeakDbFs: gate,
    displayName: 'Custom sensitivity (${SensitivityLimits.format(gate)})',
  );
}
