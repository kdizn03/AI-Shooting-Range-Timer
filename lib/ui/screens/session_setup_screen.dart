import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format_utils.dart';
import '../../models/app_settings.dart';
import '../../models/detection_engine.dart';
import '../../models/firearm_profile.dart';
import '../../models/sensitivity.dart';
import '../../models/start_delay_mode.dart';
import '../../providers/settings_provider.dart';
import '../layout/page_scaffold.dart';
import '../theme/tokens.dart';
import '../widgets/panel.dart';
import '../widgets/readiness.dart';
import '../widgets/state_views.dart';
import '../widgets/status_tag.dart';
import 'active_session_screen.dart';

export '../../models/start_delay_mode.dart';

/// Pre-session configuration screen.
///
/// Defaults come from Settings; changes here apply to this session only.
/// Allows the shooter to configure:
/// - Detection source (live microphone vs. simulated events)
/// - Firearm profile & decibel gate
/// - Detection engine (YAMNet or energy heuristic) and its threshold
/// - Start delay mode
class SessionSetupScreen extends ConsumerStatefulWidget {
  /// Creates a [SessionSetupScreen].
  ///
  /// [initialSimulation] overrides the default detection source.
  const SessionSetupScreen({super.key, this.initialSimulation});

  final bool? initialSimulation;

  @override
  ConsumerState<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  late AppSettings _defaults;
  late DetectionEngine _engine;

  /// Threshold per engine, so switching engines keeps each one's value.
  late final Map<DetectionEngine, double> _thresholds;

  double get _sensitivity => _thresholds[_engine]!;
  late StartDelayMode _delayMode;
  late bool _isSimulation;
  late FirearmPreset _preset;
  late SensitivityMode _gateMode;

  @override
  void initState() {
    super.initState();
    _defaults = ref.read(settingsProvider);
    _engine = _defaults.detectionEngine;
    _thresholds = {
      for (final DetectionEngine e in DetectionEngine.values)
        e: _defaults.thresholdFor(e),
    };
    _delayMode = _defaults.startDelay;
    _isSimulation = widget.initialSimulation ?? _defaults.useSimulation;
    _preset = _defaults.firearmPreset;
    _gateMode = _defaults.sensitivityMode;
    _customGate = _defaults.customThresholdDbFs;
  }

  /// Custom gate for this session only (starts from the saved setting).
  late double _customGate;

  /// The profile this session will detect with: the chosen preset, with the
  /// custom gate applied when custom sensitivity is selected.
  FirearmProfile get _profile => applySensitivity(
        _defaults.resolveProfile(_preset),
        _gateMode,
        _customGate,
      );

  void _continue() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => ActiveSessionScreen(
          sensitivity: _sensitivity,
          detectionEngine: _engine,
          detectionZone: _defaults.detectionZone,
          noiseSeedDbFs: _defaults.activeCalibration?.noiseFloorDbFs,
          delayMode: _delayMode,
          isSimulation: _isSimulation,
          firearmProfile: _profile,
          debounceMs: _defaults.debounceMs,
          latencyCompensationMs: _defaults.latencyCompensationMs,
          playStartBeep: _defaults.playStartBeep,
          hapticOnDetection: _defaults.hapticOnDetection,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Readiness? readiness = ref.watch(readinessProvider);
    final bool micProblem = !_isSimulation &&
        readiness != null &&
        readiness.items.first.tone == Tone.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New session'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
        children: [
          ContentWidth(
            maxWidth: AppSizes.maxReadableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Configure this session', style: AppType.title),
                const SizedBox(height: AppSpace.xs),
                const Text(
                  'Defaults come from Settings. Changes here apply to this session only.',
                  style: AppType.bodySecondary,
                ),
                const SizedBox(height: AppSpace.xl),
                _section(
                  'Detection source',
                  'Live mode listens through the microphone. Simulation generates '
                      'random events every 1–3 s for testing the timer — those sessions '
                      'are tagged “Simulated” and excluded from analytics by default.',
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false,
                          icon: Icon(Icons.mic, size: 18),
                          label: Text('Live microphone')),
                      ButtonSegment(
                          value: true,
                          icon: Icon(Icons.science_outlined, size: 18),
                          label: Text('Simulation')),
                    ],
                    selected: {_isSimulation},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _isSimulation = s.first),
                  ),
                ),
                if (micProblem) ...[
                  const SizedBox(height: AppSpace.md),
                  const InlineNotice(
                    icon: Icons.mic_off,
                    color: AppColors.error,
                    message:
                        'Microphone access is blocked. Enable it in system settings, '
                        'or use simulation mode.',
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                _section(
                  'Firearm profile',
                  'Sets the decibel gate a sound must exceed before it can count.',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<FirearmPreset>(
                        initialValue: _preset,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Profile',
                          prefixIcon: Icon(Icons.tune, size: 20),
                        ),
                        items: [
                          for (final FirearmProfile p in FirearmProfile.allPresets)
                            DropdownMenuItem(
                              value: p.preset,
                              child: Text('${p.displayName} · ${p.typicalDbRange}',
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (p) {
                          if (p != null) setState(() => _preset = p);
                        },
                      ),
                      const SizedBox(height: AppSpace.md),
                      Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: [
                          StatusTag(
                            label: _profile.isSuppressed ? 'Suppressed' : 'Unsuppressed',
                            tone: Tone.info,
                            icon: _profile.isSuppressed
                                ? Icons.volume_down
                                : Icons.volume_up,
                          ),
                          StatusTag(
                              label:
                                  'Gate ${_profile.minPeakDbFs.toStringAsFixed(0)} dBFS',
                              icon: Icons.filter_alt_outlined),
                          StatusTag(
                              label:
                                  'Nominal ${_profile.nominalPeakDbSpl.toStringAsFixed(0)} dB SPL',
                              icon: Icons.speed),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(_profile.description, style: AppType.caption),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                _section(
                  'Audio sensitivity',
                  'The level (dBFS) a sound must reach before it can count. '
                      'Lower values count quieter sounds.',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: SensitivityLimits.clamp(_profile.minPeakDbFs),
                              min: SensitivityLimits.minDbFs,
                              max: SensitivityLimits.maxDbFs,
                              divisions: SensitivityLimits.divisions,
                              label: SensitivityLimits.format(
                                  _profile.minPeakDbFs),
                              semanticFormatterCallback: (v) =>
                                  'Gate ${SensitivityLimits.format(v)}',
                              onChanged: (v) => setState(() {
                                _gateMode = SensitivityMode.custom;
                                _customGate = v;
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            child: Text(
                                '${_profile.minPeakDbFs.toStringAsFixed(0)} dB',
                                textAlign: TextAlign.right,
                                style: AppType.monoBody
                                    .copyWith(color: AppColors.accent)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                                'More sensitive (${SensitivityLimits.minDbFs.toStringAsFixed(0)})',
                                style: AppType.caption),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Text(
                                'Less sensitive (${SensitivityLimits.maxDbFs.toStringAsFixed(0)})',
                                textAlign: TextAlign.right,
                                style: AppType.caption),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _gateMode == SensitivityMode.custom
                                  ? 'Custom value for this session.'
                                  : 'From the firearm preset.',
                              style: AppType.caption,
                            ),
                          ),
                          if (_gateMode == SensitivityMode.custom)
                            TextButton(
                              onPressed: () => setState(
                                  () => _gateMode = SensitivityMode.preset),
                              child: const Text('Use preset gate'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                _section(
                  'Detection engine',
                  _engine.thresholdHelp,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<DetectionEngine>(
                        segments: [
                          for (final DetectionEngine e in DetectionEngine.values)
                            ButtonSegment(
                              value: e,
                              icon: Icon(
                                  e == DetectionEngine.yamnet
                                      ? Icons.memory
                                      : Icons.graphic_eq,
                                  size: 18),
                              label: Text(e.label),
                            ),
                        ],
                        selected: {_engine},
                        showSelectedIcon: false,
                        onSelectionChanged: _isSimulation
                            ? null
                            : (v) => setState(() => _engine = v.first),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(_engine.thresholdName, style: AppType.body),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _sensitivity,
                              min: _engine.minThreshold,
                              max: _engine.maxThreshold,
                              divisions: _engine.divisions,
                              label: Fmt.percent(_sensitivity),
                              semanticFormatterCallback: (v) =>
                                  'Threshold ${Fmt.percent(v)}',
                              onChanged: (v) => setState(() =>
                                  _thresholds[_engine] = _engine.clampThreshold(v)),
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(Fmt.percent(_sensitivity),
                                textAlign: TextAlign.right,
                                style: AppType.monoBody.copyWith(
                                    color: AppColors.accent)),
                          ),
                        ],
                      ),
                      const Row(
                        children: [
                          Text('More sensitive', style: AppType.caption),
                          Spacer(),
                          Text('Stricter', style: AppType.caption),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                _section(
                  'Start delay',
                  'Time between pressing Start and the beep. Random delay is not '
                      'counted down on screen.',
                  SegmentedButton<StartDelayMode>(
                    segments: [
                      for (final m in StartDelayMode.values)
                        ButtonSegment(value: m, label: Text(m.label)),
                    ],
                    selected: {_delayMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _delayMode = s.first),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceSunken,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: ContentWidth(
              maxWidth: AppSizes.maxReadableWidth,
              child: FilledButton.icon(
                onPressed: _continue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue to timer'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.controlHeight)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String help, Widget control) {
    return Panel(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppType.heading),
          const SizedBox(height: AppSpace.xs),
          Text(help, style: AppType.caption),
          const SizedBox(height: AppSpace.md),
          control,
        ],
      ),
    );
  }
}
