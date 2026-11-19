/// How candidate sounds are filtered beyond the decibel gate and classifier.
enum DetectionZone {
  /// The firearm preset / custom gate and classifier threshold only.
  standard(
    'Standard detection',
    'Uses the decibel gate and classifier threshold only. This is the '
        'original behaviour.',
  ),

  /// Prefers sounds whose signal looks like a nearby source.
  nearField(
    'Near-field priority',
    'Also checks how far a sound stands above the background, and how much '
        'its direct sound dominates its echo. Nearby shots usually score high '
        'on both; shots from other lanes usually arrive quieter relative to '
        'the background and with more echo. This is an approximation from one '
        'microphone, not a distance measurement: a loud distant shot can '
        'still pass, and borderline sounds are marked uncertain for review.',
  ),

  /// Needs a multi-channel array with known geometry (not available).
  directional(
    'Directional priority',
    'Needs a microphone array that delivers synchronized channels with known '
        'microphone positions, plus beamforming. RangePulse captures one '
        'mono channel and the audio plugin does not report microphone '
        'geometry, so this is not available.',
  );

  const DetectionZone(this.label, this.description);

  final String label;
  final String description;

  /// Whether the profile can be selected with the current capture setup.
  bool get isSupported => DirectionalSupport.current.available || this != directional;
}

/// Whether directional processing can run.
///
/// RangePulse records a single channel and the `record` plugin exposes no
/// channel count or microphone positions, so this is always unavailable.
/// A future multi-channel capture path would report its real capability
/// here.
class DirectionalSupport {
  const DirectionalSupport._(this.available, this.reason);

  final bool available;
  final String reason;

  static const DirectionalSupport current = DirectionalSupport._(
    false,
    'Not available: requires synchronized multi-channel capture with known '
        'microphone positions. Single microphones — built-in, USB, wired or '
        'Bluetooth — cannot tell direction.',
  );

  /// Spatial detection radius: not implemented for any hardware.
  static const String spatialRadiusReason =
      'A detection radius is not offered. One microphone cannot measure how '
      'far away a sound is; a radius would need several synchronized '
      'microphones at known positions to locate sources.';
}

/// Outcome of the zone check for one candidate sound.
enum ZoneVerdict {
  /// Recorded as a detection.
  accepted,

  /// Recorded, but flagged for review.
  uncertain,

  /// Not recorded.
  rejected,
}

/// Signal measurements the near-field check uses.
class ZoneFeatures {
  const ZoneFeatures({
    required this.peakDbFs,
    this.backgroundDbFs,
    this.directRatioDb,
  });

  final double peakDbFs;

  /// Background estimate, or null before one is available.
  final double? backgroundDbFs;

  /// Direct-to-tail energy ratio, or null when too little audio follows
  /// the peak to measure it.
  final double? directRatioDb;

  /// Peak above background, when the background is known.
  double? get snrDb {
    final double? b = backgroundDbFs;
    if (b == null || !b.isFinite || !peakDbFs.isFinite) return null;
    return peakDbFs - b;
  }
}

/// Result of the zone check, with the reason shown in review.
class ZoneDecision {
  const ZoneDecision(this.verdict, this.reason, this.features);

  final ZoneVerdict verdict;
  final String reason;
  final ZoneFeatures features;
}

/// Thresholds for [DetectionZone.nearField].
///
/// Starting values from measurements on a real gunshot recording (SNR about
/// 40 dB, direct-to-tail ratio 12–14 dB) against controlled versions made to
/// sound distant (quieter, high frequencies rolled off, reverb added: SNR
/// 15–20 dB, ratio 4–6 dB). They are not range-validated; retune with
/// recordings from the range.
abstract final class NearFieldPolicy {
  /// Accept when the sound is at least this far above background…
  static const double acceptSnrDb = 25;

  /// …and its direct sound is at least this much stronger than its tail.
  static const double acceptDirectRatioDb = 10;

  /// Reject below this SNR.
  static const double rejectSnrDb = 15;

  /// Reject below this direct-to-tail ratio.
  static const double rejectDirectRatioDb = 6;

  /// With no ratio available, accepting needs this much SNR.
  static const double acceptSnrOnlyDb = 30;

  /// Applies the near-field rules to [f].
  static ZoneDecision evaluate(ZoneFeatures f) {
    final double? snr = f.snrDb;
    final double? dtr = f.directRatioDb;
    String fmt(double v) => v.toStringAsFixed(1);

    if (snr == null && dtr == null) {
      return ZoneDecision(ZoneVerdict.uncertain,
          'No background estimate or echo measurement yet', f);
    }
    if (snr != null && snr < rejectSnrDb) {
      return ZoneDecision(ZoneVerdict.rejected,
          'Only ${fmt(snr)} dB above background', f);
    }
    if (dtr != null && dtr < rejectDirectRatioDb) {
      return ZoneDecision(ZoneVerdict.rejected,
          'Echo-heavy: direct sound only ${fmt(dtr)} dB above its tail', f);
    }
    if (dtr == null) {
      return snr! >= acceptSnrOnlyDb
          ? ZoneDecision(ZoneVerdict.accepted,
              '${fmt(snr)} dB above background', f)
          : ZoneDecision(ZoneVerdict.uncertain,
              '${fmt(snr)} dB above background; echo not measurable', f);
    }
    if (snr == null) {
      return ZoneDecision(ZoneVerdict.uncertain,
          'Direct-to-tail ${fmt(dtr)} dB; background not yet known', f);
    }
    if (snr >= acceptSnrDb && dtr >= acceptDirectRatioDb) {
      return ZoneDecision(ZoneVerdict.accepted,
          '${fmt(snr)} dB above background, direct-to-tail ${fmt(dtr)} dB', f);
    }
    return ZoneDecision(ZoneVerdict.uncertain,
        'Borderline: ${fmt(snr)} dB above background, direct-to-tail '
        '${fmt(dtr)} dB',
        f);
  }
}
