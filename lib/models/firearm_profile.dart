import 'package:equatable/equatable.dart';

/// Predefined and customizable firearm acoustic profiles.
///
/// Each profile specifies the real-world Sound Pressure Level (dB SPL) range,
/// nominal peak decibels, and recommended digital threshold (dBFS) for
/// acoustic gating in [ShotDetector].
enum FirearmPreset {
  /// Glock 19 (9x19mm Parabellum) fired unsuppressed.
  /// Extremely loud acoustic blast (155–167 dB SPL).
  glock19Unsuppressed,

  /// Glock 19 (9x19mm Parabellum) fired with a suppressor / silencer.
  /// Substantially reduced report (134–140 dB SPL, ~30–34 dB reduction).
  glock19Suppressed,

  /// Centerfire rifle or shotgun (5.56 NATO, .308 Win, 12 Gauge).
  /// High muzzle velocity blast (>160 dB SPL).
  centerfireRifle,

  /// Rimfire handgun or rifle (.22 Long Rifle).
  /// Moderate report (135–142 dB SPL).
  rimfire22,

  /// Airsoft gun or dry-fire indoor training click.
  /// Low acoustic energy (90–115 dB SPL).
  airsoftDryFire,

  /// User-defined decibel gate threshold.
  custom,
}

/// Detailed profile for a firearm acoustic preset.
class FirearmProfile extends Equatable {
  /// Creates a [FirearmProfile].
  const FirearmProfile({
    required this.preset,
    required this.displayName,
    required this.caliber,
    required this.typicalDbRange,
    required this.nominalPeakDbSpl,
    required this.minPeakDbFs,
    required this.description,
    this.isSuppressed = false,
  });

  /// Preset identifier.
  final FirearmPreset preset;

  /// Human-readable name (e.g. 'Glock 19 (Unsuppressed)').
  final String displayName;

  /// Caliber or ammunition type.
  final String caliber;

  /// Expected real-world sound pressure level range (e.g. '155–167 dB').
  final String typicalDbRange;

  /// Nominal peak sound pressure level in dB SPL under typical conditions.
  final double nominalPeakDbSpl;

  /// Minimum digital peak amplitude in dBFS (-90.0 to 0.0) required to trigger detection.
  final double minPeakDbFs;

  /// Detailed description for shooters and range officers.
  final String description;

  /// Whether this profile represents a suppressed / silenced firearm.
  final bool isSuppressed;

  /// Predefined profiles.
  static const FirearmProfile glock19Unsuppressed = FirearmProfile(
    preset: FirearmPreset.glock19Unsuppressed,
    displayName: 'Glock 19 (Unsuppressed)',
    caliber: '9x19mm Parabellum',
    typicalDbRange: '155–167 dB',
    nominalPeakDbSpl: 162.0,
    minPeakDbFs: -4.0,
    description:
        'Standard 9mm unsuppressed handgun report (155–167 dB SPL). Near 0 dBFS peak saturation.',
    isSuppressed: false,
  );

  static const FirearmProfile glock19Suppressed = FirearmProfile(
    preset: FirearmPreset.glock19Suppressed,
    displayName: 'Glock 19 (Suppressed)',
    caliber: '9x19mm Subsonic / Suppressed',
    typicalDbRange: '134–140 dB',
    nominalPeakDbSpl: 137.0,
    minPeakDbFs: -14.0,
    description:
        'Suppressed 9mm report (134–140 dB SPL). ~30–34 dB quieter than unsuppressed, requiring a more sensitive decibel gate.',
    isSuppressed: true,
  );

  static const FirearmProfile centerfireRifle = FirearmProfile(
    preset: FirearmPreset.centerfireRifle,
    displayName: 'Rifle / Shotgun (Unsuppressed)',
    caliber: '5.56 NATO / .308 Win / 12 GA',
    typicalDbRange: '160–170+ dB',
    nominalPeakDbSpl: 166.0,
    minPeakDbFs: -2.0,
    description:
        'High-energy centerfire rifle or shotgun blast (>160 dB SPL). Heavy transient shockwave.',
    isSuppressed: false,
  );

  static const FirearmProfile rimfire22 = FirearmProfile(
    preset: FirearmPreset.rimfire22,
    displayName: 'Rimfire (.22 LR)',
    caliber: '.22 Long Rifle',
    typicalDbRange: '135–142 dB',
    nominalPeakDbSpl: 138.0,
    minPeakDbFs: -12.0,
    description:
        'Rimfire pistol or rifle report (135–142 dB SPL). Moderate acoustic impulse.',
    isSuppressed: false,
  );

  static const FirearmProfile airsoftDryFire = FirearmProfile(
    preset: FirearmPreset.airsoftDryFire,
    displayName: 'Airsoft / Dry Fire',
    caliber: 'Practice Click / Airsoft Gas',
    typicalDbRange: '90–115 dB',
    nominalPeakDbSpl: 105.0,
    minPeakDbFs: -24.0,
    description:
        'Low-energy practice clicks or gas blowback (90–115 dB SPL) for indoor drills.',
    isSuppressed: false,
  );

  static const FirearmProfile custom = FirearmProfile(
    preset: FirearmPreset.custom,
    displayName: 'Custom Profile',
    caliber: 'User Configured',
    typicalDbRange: 'Adjustable',
    nominalPeakDbSpl: 150.0,
    minPeakDbFs: -10.0,
    description: 'Custom decibel sensitivity and threshold setting.',
    isSuppressed: false,
  );

  /// All available presets for easy iteration in UI dropdowns.
  static const List<FirearmProfile> allPresets = [
    glock19Unsuppressed,
    glock19Suppressed,
    centerfireRifle,
    rimfire22,
    airsoftDryFire,
    custom,
  ];

  /// Resolves a preset from its [FirearmPreset] enum.
  static FirearmProfile fromPreset(FirearmPreset preset) {
    switch (preset) {
      case FirearmPreset.glock19Unsuppressed:
        return glock19Unsuppressed;
      case FirearmPreset.glock19Suppressed:
        return glock19Suppressed;
      case FirearmPreset.centerfireRifle:
        return centerfireRifle;
      case FirearmPreset.rimfire22:
        return rimfire22;
      case FirearmPreset.airsoftDryFire:
        return airsoftDryFire;
      case FirearmPreset.custom:
        return custom;
    }
  }

  /// Deserializes a [FirearmProfile] from a JSON map or string.
  factory FirearmProfile.fromMap(Map<String, dynamic> map) {
    final presetName = map['preset'] as String? ?? 'glock19Unsuppressed';
    final preset = FirearmPreset.values.firstWhere(
      (p) => p.name == presetName,
      orElse: () => FirearmPreset.glock19Unsuppressed,
    );
    final base = fromPreset(preset);
    return FirearmProfile(
      preset: preset,
      displayName: map['displayName'] as String? ?? base.displayName,
      caliber: map['caliber'] as String? ?? base.caliber,
      typicalDbRange: map['typicalDbRange'] as String? ?? base.typicalDbRange,
      nominalPeakDbSpl:
          (map['nominalPeakDbSpl'] as num?)?.toDouble() ?? base.nominalPeakDbSpl,
      minPeakDbFs:
          (map['minPeakDbFs'] as num?)?.toDouble() ?? base.minPeakDbFs,
      description: map['description'] as String? ?? base.description,
      isSuppressed: map['isSuppressed'] as bool? ?? base.isSuppressed,
    );
  }

  /// Serializes this profile to a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'preset': preset.name,
      'displayName': displayName,
      'caliber': caliber,
      'typicalDbRange': typicalDbRange,
      'nominalPeakDbSpl': nominalPeakDbSpl,
      'minPeakDbFs': minPeakDbFs,
      'description': description,
      'isSuppressed': isSuppressed,
    };
  }

  /// Creates a copy with the given fields replaced.
  FirearmProfile copyWith({
    FirearmPreset? preset,
    String? displayName,
    String? caliber,
    String? typicalDbRange,
    double? nominalPeakDbSpl,
    double? minPeakDbFs,
    String? description,
    bool? isSuppressed,
  }) {
    return FirearmProfile(
      preset: preset ?? this.preset,
      displayName: displayName ?? this.displayName,
      caliber: caliber ?? this.caliber,
      typicalDbRange: typicalDbRange ?? this.typicalDbRange,
      nominalPeakDbSpl: nominalPeakDbSpl ?? this.nominalPeakDbSpl,
      minPeakDbFs: minPeakDbFs ?? this.minPeakDbFs,
      description: description ?? this.description,
      isSuppressed: isSuppressed ?? this.isSuppressed,
    );
  }

  @override
  List<Object?> get props => [
        preset,
        displayName,
        caliber,
        typicalDbRange,
        nominalPeakDbSpl,
        minPeakDbFs,
        description,
        isSuppressed,
      ];
}

