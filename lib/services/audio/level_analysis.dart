import 'dart:math' as math;
import 'dart:typed_data';

import '../../models/sensitivity.dart';

/// Lowest level reported. Digital silence maps here, so the UI never sees
/// negative infinity or NaN.
const double kSilenceFloorDbFs = -96;

/// Calibration: how far above the loudest ambient moments to place the gate.
const double kCalibrationMarginDb = 10;

/// Calibration: a 95th-percentile level at or below this means no signal.
const double kNoSignalCeilingDbFs = -90;

/// Calibration: a 95th-percentile level above this means loud surroundings.
const double kLoudAmbientDbFs = -15;

/// Calibration: fewest analysis windows accepted (about 2 s at 250 ms each).
const int kMinCalibrationWindows = 8;

/// Converts a peak amplitude ratio (0..1 of full scale) to dBFS.
double dbFsFromPeakRatio(double ratio) {
  if (!ratio.isFinite || ratio <= 0) return kSilenceFloorDbFs;
  final double db = 20 * math.log(ratio) / math.ln10;
  return db < kSilenceFloorDbFs ? kSilenceFloorDbFs : db;
}

/// Index (in samples) of the largest absolute sample in little-endian PCM16
/// [bytes]. Returns 0 for an empty buffer or an all-zero buffer.
///
/// The detector uses this to place a sound at the moment its peak occurred,
/// not at the moment processing finished.
int peakIndexFromPcm16(Uint8List bytes) {
  int maxAbs = 0;
  int index = 0;
  final ByteData view = ByteData.sublistView(bytes);
  final int samples = bytes.length ~/ 2;
  for (int i = 0; i < samples; i++) {
    final int abs = view.getInt16(i * 2, Endian.little).abs();
    if (abs > maxAbs) {
      maxAbs = abs;
      index = i;
    }
  }
  return index;
}

/// Peak level in dBFS of little-endian PCM16 [bytes].
///
/// This is the same measurement the detection pipeline uses for its gate:
/// the largest absolute sample in the window, relative to full scale.
double peakDbFsFromPcm16(Uint8List bytes) {
  int maxAbs = 0;
  final ByteData view = ByteData.sublistView(bytes);
  final int samples = bytes.length ~/ 2;
  for (int i = 0; i < samples; i++) {
    final int abs = view.getInt16(i * 2, Endian.little).abs();
    if (abs > maxAbs) maxAbs = abs;
  }
  return dbFsFromPeakRatio(maxAbs / 32768.0);
}

/// Linear-interpolated percentile of the finite values in [values].
///
/// [p] is 0..1. Returns `null` when there are no finite values.
double? percentile(Iterable<double> values, double p) {
  final List<double> sorted = values.where((v) => v.isFinite).toList()
    ..sort();
  if (sorted.isEmpty) return null;
  final double rank = p.clamp(0.0, 1.0) * (sorted.length - 1);
  final int lo = rank.floor();
  final int hi = rank.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
}

/// Direct-to-tail energy ratio around a peak, in dB.
///
/// Compares the mean energy of the direct sound (1 ms before to 10 ms after
/// the peak) with the tail (30–200 ms after). Nearby sources are dominated
/// by direct sound; sound from far away arrives with relatively more echo,
/// so the ratio drops. It is a relative cue, not a distance.
///
/// [samples] are scaled to -1..1 and [peakIndex] indexes the peak. Returns
/// null if less than 70 ms of tail follows the peak, or the tail is silent
/// and the direct part is too.
double? directToTailRatioDb(List<double> samples, int peakIndex,
    {int sampleRate = 16000}) {
  int ms(int v) => v * sampleRate ~/ 1000;
  final int dStart = math.max(0, peakIndex - ms(1));
  final int dEnd = math.min(samples.length, peakIndex + ms(10));
  final int tStart = peakIndex + ms(30);
  final int tEnd = math.min(samples.length, peakIndex + ms(200));
  if (tEnd - tStart < ms(70) || dEnd <= dStart) return null;

  double meanSquare(int a, int b) {
    double sum = 0;
    for (int i = a; i < b; i++) {
      sum += samples[i] * samples[i];
    }
    return sum / (b - a);
  }

  final double direct = meanSquare(dStart, dEnd);
  final double tail = meanSquare(tStart, tEnd);
  if (direct <= 0) return null;
  // A silent tail would give infinity; cap at a large, finite ratio.
  final double ratio = 10 * math.log(direct / math.max(tail, 1e-12)) / math.ln10;
  return ratio.clamp(-60.0, 60.0);
}

/// PCM16 little-endian bytes as samples scaled to -1..1.
Float32List pcm16ToSamples(Uint8List bytes) {
  final ByteData d = ByteData.sublistView(bytes);
  final Float32List out = Float32List(bytes.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = d.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

/// Why a calibration could not produce a suggestion.
enum CalibrationIssue {
  /// The microphone is blocked or permission was refused.
  permissionDenied,

  /// The microphone could not start or stopped delivering audio.
  noInput,

  /// Audio arrived but it is digital silence, so the mic is probably muted.
  noSignal,

  /// Some other failure (message is in [CalibrationOutcome.message]).
  error,
}

/// Result of a background-noise calibration.
///
/// A result is a suggestion only. It must be reviewed and accepted by the
/// user before it is applied, and it does not mean detection is ready.
class CalibrationOutcome {
  const CalibrationOutcome._({
    required this.windowCount,
    this.backgroundDbFs,
    this.noiseCeilingDbFs,
    this.suggestedDbFs,
    this.warning,
    this.issue,
    this.message,
  });

  /// Calibration that produced a usable suggestion.
  factory CalibrationOutcome.suggestion({
    required int windowCount,
    required double backgroundDbFs,
    required double noiseCeilingDbFs,
    required double suggestedDbFs,
    String? warning,
  }) =>
      CalibrationOutcome._(
        windowCount: windowCount,
        backgroundDbFs: backgroundDbFs,
        noiseCeilingDbFs: noiseCeilingDbFs,
        suggestedDbFs: suggestedDbFs,
        warning: warning,
      );

  /// Calibration that could not run to completion.
  factory CalibrationOutcome.failed(
    CalibrationIssue issue, {
    int windowCount = 0,
    double? backgroundDbFs,
    double? noiseCeilingDbFs,
    String? message,
  }) =>
      CalibrationOutcome._(
        windowCount: windowCount,
        issue: issue,
        backgroundDbFs: backgroundDbFs,
        noiseCeilingDbFs: noiseCeilingDbFs,
        message: message,
      );

  /// Number of 250 ms windows analysed.
  final int windowCount;

  /// Quiet-moment level (10th percentile), or `null`.
  final double? backgroundDbFs;

  /// Loudest-typical level (95th percentile), or `null`.
  final double? noiseCeilingDbFs;

  /// Suggested custom threshold, already clamped to the allowed range.
  final double? suggestedDbFs;

  /// Non-blocking caveat, such as very loud surroundings.
  final String? warning;

  /// Set when calibration failed.
  final CalibrationIssue? issue;

  /// Extra detail for failures.
  final String? message;

  /// Whether a suggestion is available to review.
  bool get hasSuggestion => issue == null && suggestedDbFs != null;
}

/// Turns per-window levels recorded during calibration into a suggestion.
///
/// The suggested gate sits [kCalibrationMarginDb] above the 95th-percentile
/// ambient level, so ordinary background noise should not reach it. It is
/// clamped to [SensitivityLimits] and rounded to 0.1 dB.
CalibrationOutcome analyzeCalibration(List<double> windowDbFs) {
  final int n = windowDbFs.length;
  if (n < kMinCalibrationWindows) {
    return CalibrationOutcome.failed(CalibrationIssue.noInput,
        windowCount: n,
        message: 'Only $n of $kMinCalibrationWindows analysis windows were '
            'received. Check that the microphone is working and try again.');
  }

  final double background = percentile(windowDbFs, 0.10)!;
  final double ceiling = percentile(windowDbFs, 0.95)!;

  if (ceiling <= kNoSignalCeilingDbFs) {
    return CalibrationOutcome.failed(CalibrationIssue.noSignal,
        windowCount: n,
        backgroundDbFs: background,
        noiseCeilingDbFs: ceiling,
        message: 'The microphone delivered silence. It may be muted, covered, '
            'or blocked by the system.');
  }

  final double suggested = SensitivityLimits.clamp(
      ((ceiling + kCalibrationMarginDb) * 10).roundToDouble() / 10);
  final String? warning = ceiling > kLoudAmbientDbFs
      ? 'Background noise is very loud (${ceiling.toStringAsFixed(1)} dBFS). '
          'Expect false detections, or move to a quieter spot.'
      : null;

  return CalibrationOutcome.suggestion(
    windowCount: n,
    backgroundDbFs: background,
    noiseCeilingDbFs: ceiling,
    suggestedDbFs: suggested,
    warning: warning,
  );
}
