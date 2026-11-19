import 'package:equatable/equatable.dart';

import '../core/constants.dart';
import 'detection_engine.dart';
import 'detection_zone.dart';
import 'firearm_profile.dart';
import 'microphone.dart';
import 'sensitivity.dart';
import 'start_delay_mode.dart';

/// User preferences that seed each new session.
///
/// Every field maps to behaviour the session pipeline actually honours:
/// detection source, [DetectionConfig] parameters, start delay, beep, and
/// haptic feedback. Values can still be overridden per session in setup.
class AppSettings extends Equatable {
  /// Creates [AppSettings]. Defaults mirror the app's original constants.
  const AppSettings({
    this.useSimulation = false,
    this.detectionEngine = DetectionEngine.yamnet,
    this.yamnetThreshold = 0.15,
    this.confidenceThreshold = DetectionConstants.defaultConfidenceThreshold,
    this.firearmPreset = FirearmPreset.glock19Unsuppressed,
    this.sensitivityMode = SensitivityMode.preset,
    this.customThresholdDbFs = SensitivityLimits.defaultDbFs,
    this.customGateDbFs = -10.0,
    this.debounceMs = DetectionConstants.defaultDebounceDurationMs,
    this.latencyCompensationMs = TimingConstants.estimatedInferenceLatencyMs,
    this.startDelay = StartDelayMode.fixed3s,
    this.playStartBeep = true,
    this.hapticOnDetection = true,
    this.micSelection = MicSelection.systemDefault,
    this.detectionZone = DetectionZone.standard,
    this.micCalibrations = const {},
  });

  /// Default detection source: simulated events instead of the microphone.
  final bool useSimulation;

  /// Classifier that decides whether a loud sound is a gunshot.
  final DetectionEngine detectionEngine;

  /// Minimum YAMNet gunshot score, used with [DetectionEngine.yamnet].
  final double yamnetThreshold;

  /// Minimum heuristic confidence (0.3–0.95), used with
  /// [DetectionEngine.energy].
  final double confidenceThreshold;

  /// The threshold that applies to [engine].
  double thresholdFor(DetectionEngine engine) => switch (engine) {
        DetectionEngine.yamnet => yamnetThreshold,
        DetectionEngine.energy => confidenceThreshold,
      };

  /// The threshold for the selected [detectionEngine].
  double get activeThreshold => thresholdFor(detectionEngine);

  /// Returns a copy with [engine]'s threshold set to [value] (clamped).
  AppSettings withThreshold(DetectionEngine engine, double value) {
    final double v = engine.clampThreshold(value);
    return switch (engine) {
      DetectionEngine.yamnet => copyWith(yamnetThreshold: v),
      DetectionEngine.energy => copyWith(confidenceThreshold: v),
    };
  }

  /// Default firearm acoustic profile.
  final FirearmPreset firearmPreset;

  /// Whether the gate comes from the firearm preset or the custom threshold.
  final SensitivityMode sensitivityMode;

  /// The user's own dBFS gate, used in [SensitivityMode.custom].
  ///
  /// Kept even while preset mode is active, so switching back restores it.
  /// Always within [SensitivityLimits].
  final double customThresholdDbFs;

  /// Decibel gate (dBFS) used by the built-in "Custom Profile" preset.
  ///
  /// This is separate from [customThresholdDbFs]. It is kept for existing
  /// saved settings.
  final double customGateDbFs;

  /// Lockout between detections in milliseconds.
  final int debounceMs;

  /// Inference latency subtracted from detection timestamps.
  final int latencyCompensationMs;

  /// Default delay before the start beep.
  final StartDelayMode startDelay;

  /// Whether to play the audible start beep.
  final bool playStartBeep;

  /// Whether to vibrate when an event is detected.
  final bool hapticOnDetection;

  /// Input to record from. Defaults to the operating system's choice.
  final MicSelection micSelection;

  /// Extra filtering profile. Never [DetectionZone.directional] unless it
  /// is supported (see [DetectionZone.isSupported]).
  final DetectionZone detectionZone;

  /// Saved background calibrations, keyed by [MicSelection.calibrationKey].
  /// Kept for every input used, so switching microphones loses nothing.
  final Map<String, MicCalibration> micCalibrations;

  /// Calibration for the selected input, if one was saved.
  MicCalibration? get activeCalibration =>
      micCalibrations[micSelection.calibrationKey];

  /// Returns a copy with [calibration] stored for [selection].
  AppSettings withCalibration(MicSelection selection, MicCalibration calibration) =>
      copyWith(micCalibrations: {
        ...micCalibrations,
        selection.calibrationKey: calibration,
      });

  /// The profile a session uses: the preset, with the custom threshold
  /// applied when [sensitivityMode] is custom.
  FirearmProfile get firearmProfile => applySensitivity(
        resolveProfile(firearmPreset),
        sensitivityMode,
        customThresholdDbFs,
      );

  /// Resolves [preset] to a profile, applying the custom gate if needed.
  FirearmProfile resolveProfile(FirearmPreset preset) {
    final FirearmProfile base = FirearmProfile.fromPreset(preset);
    return preset == FirearmPreset.custom
        ? base.copyWith(minPeakDbFs: customGateDbFs)
        : base;
  }

  /// Creates a copy with the given fields replaced.
  ///
  /// The custom threshold is validated, so an out-of-range value is clamped.
  AppSettings copyWith({
    bool? useSimulation,
    DetectionEngine? detectionEngine,
    double? yamnetThreshold,
    double? confidenceThreshold,
    FirearmPreset? firearmPreset,
    SensitivityMode? sensitivityMode,
    double? customThresholdDbFs,
    double? customGateDbFs,
    int? debounceMs,
    int? latencyCompensationMs,
    StartDelayMode? startDelay,
    bool? playStartBeep,
    bool? hapticOnDetection,
    MicSelection? micSelection,
    DetectionZone? detectionZone,
    Map<String, MicCalibration>? micCalibrations,
  }) {
    return AppSettings(
      useSimulation: useSimulation ?? this.useSimulation,
      detectionEngine: detectionEngine ?? this.detectionEngine,
      yamnetThreshold: DetectionEngine.yamnet
          .clampThreshold(yamnetThreshold ?? this.yamnetThreshold),
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      firearmPreset: firearmPreset ?? this.firearmPreset,
      sensitivityMode: sensitivityMode ?? this.sensitivityMode,
      customThresholdDbFs: SensitivityLimits.clamp(
          customThresholdDbFs ?? this.customThresholdDbFs),
      customGateDbFs: customGateDbFs ?? this.customGateDbFs,
      debounceMs: debounceMs ?? this.debounceMs,
      latencyCompensationMs:
          latencyCompensationMs ?? this.latencyCompensationMs,
      startDelay: startDelay ?? this.startDelay,
      playStartBeep: playStartBeep ?? this.playStartBeep,
      hapticOnDetection: hapticOnDetection ?? this.hapticOnDetection,
      micSelection: micSelection ?? this.micSelection,
      detectionZone: _supportedZone(detectionZone ?? this.detectionZone),
      micCalibrations: micCalibrations ?? this.micCalibrations,
    );
  }

  static DetectionZone _supportedZone(DetectionZone z) =>
      z.isSupported ? z : DetectionZone.standard;

  /// Serializes to a JSON-compatible map.
  Map<String, dynamic> toMap() => {
        'useSimulation': useSimulation,
        'detectionEngine': detectionEngine.name,
        'yamnetThreshold': yamnetThreshold,
        'confidenceThreshold': confidenceThreshold,
        'firearmPreset': firearmPreset.name,
        'sensitivityMode': sensitivityMode.name,
        'customThresholdDbFs': customThresholdDbFs,
        'customGateDbFs': customGateDbFs,
        'debounceMs': debounceMs,
        'latencyCompensationMs': latencyCompensationMs,
        'startDelay': startDelay.name,
        'playStartBeep': playStartBeep,
        'hapticOnDetection': hapticOnDetection,
        'micSelection': {
          if (micSelection.id != null) 'id': micSelection.id,
          if (micSelection.label != null) 'label': micSelection.label,
        },
        'detectionZone': detectionZone.name,
        'micCalibrations': {
          for (final MapEntry<String, MicCalibration> e
              in micCalibrations.entries)
            e.key: e.value.toMap(),
        },
      };

  /// Deserializes from a map, falling back to defaults for missing or
  /// invalid fields. Older saved settings (without the sensitivity fields)
  /// load in preset mode with the default custom threshold.
  factory AppSettings.fromMap(Map<String, dynamic> map) {
    const AppSettings d = AppSettings();
    T pick<T>(String key, T fallback) {
      final Object? v = map[key];
      return v is T ? v : fallback;
    }

    final Object? rawThreshold = map['customThresholdDbFs'];
    final double threshold = rawThreshold is num
        ? SensitivityLimits.clamp(rawThreshold.toDouble())
        : d.customThresholdDbFs;

    return AppSettings(
      useSimulation: pick<bool>('useSimulation', d.useSimulation),
      detectionEngine: DetectionEngine.values.firstWhere(
        (e) => e.name == map['detectionEngine'],
        orElse: () => d.detectionEngine,
      ),
      yamnetThreshold: DetectionEngine.yamnet.clampThreshold(
          pick<num>('yamnetThreshold', d.yamnetThreshold).toDouble()),
      confidenceThreshold:
          (pick<num>('confidenceThreshold', d.confidenceThreshold))
              .toDouble()
              .clamp(0.3, 0.95),
      firearmPreset: FirearmPreset.values.firstWhere(
        (p) => p.name == map['firearmPreset'],
        orElse: () => d.firearmPreset,
      ),
      sensitivityMode: SensitivityMode.values.firstWhere(
        (m) => m.name == map['sensitivityMode'],
        orElse: () => d.sensitivityMode,
      ),
      customThresholdDbFs: threshold,
      customGateDbFs: (pick<num>('customGateDbFs', d.customGateDbFs))
          .toDouble()
          .clamp(-40.0, 0.0),
      debounceMs:
          pick<num>('debounceMs', d.debounceMs).toInt().clamp(100, 1000),
      latencyCompensationMs: pick<num>(
        'latencyCompensationMs',
        d.latencyCompensationMs,
      ).toInt().clamp(0, 200),
      startDelay: StartDelayMode.values.firstWhere(
        (m) => m.name == map['startDelay'],
        orElse: () => d.startDelay,
      ),
      playStartBeep: pick<bool>('playStartBeep', d.playStartBeep),
      hapticOnDetection: pick<bool>('hapticOnDetection', d.hapticOnDetection),
      micSelection: _parseSelection(map['micSelection']),
      detectionZone: _supportedZone(DetectionZone.values.firstWhere(
        (z) => z.name == map['detectionZone'],
        orElse: () => d.detectionZone,
      )),
      micCalibrations: _parseCalibrations(map['micCalibrations']),
    );
  }

  static MicSelection _parseSelection(Object? raw) {
    if (raw is! Map) return MicSelection.systemDefault;
    final Object? id = raw['id'];
    final Object? label = raw['label'];
    if (id is! String || id.isEmpty) return MicSelection.systemDefault;
    return MicSelection(id: id, label: label is String ? label : null);
  }

  /// Invalid entries are dropped individually; the rest are kept.
  static Map<String, MicCalibration> _parseCalibrations(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final MapEntry<Object?, Object?> e in raw.entries)
        if (e.key is String && MicCalibration.tryParse(e.value) != null)
          e.key! as String: MicCalibration.tryParse(e.value)!,
    };
  }

  @override
  List<Object?> get props => [
        useSimulation,
        detectionEngine,
        yamnetThreshold,
        confidenceThreshold,
        firearmPreset,
        sensitivityMode,
        customThresholdDbFs,
        customGateDbFs,
        debounceMs,
        latencyCompensationMs,
        startDelay,
        playStartBeep,
        hapticOnDetection,
        micSelection,
        detectionZone,
        micCalibrations,
      ];
}
