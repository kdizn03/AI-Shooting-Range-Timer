import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format_utils.dart';
import '../../models/app_settings.dart';
import '../../models/microphone.dart';
import '../../models/sensitivity.dart';
import '../../providers/audio_input_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/audio/audio_level_monitor.dart';
import '../../services/audio/level_analysis.dart';
import '../theme/tokens.dart';
import 'panel.dart';
import 'status_tag.dart';

/// Settings → Sensitivity configuration.
///
/// Edits a draft; nothing takes effect until Save. The live meter and the
/// calibration read real microphone windows and never simulate levels.
class SensitivitySection extends ConsumerStatefulWidget {
  /// Creates a [SensitivitySection].
  const SensitivitySection({super.key});

  @override
  ConsumerState<SensitivitySection> createState() => _SensitivitySectionState();
}

class _SensitivitySectionState extends ConsumerState<SensitivitySection> {
  late SensitivityMode _mode;
  late double _threshold;
  late final TextEditingController _field;
  String? _fieldError;
  /// Shared with the Microphone section; closed by its provider.
  AudioLevelMonitor get _monitor => ref.read(levelMonitorProvider);
  CalibrationOutcome? _outcome;

  /// The input the last calibration actually measured.
  MicRoute? _outcomeRoute;
  bool _calibrating = false;

  /// Last saved values the draft is compared against.
  late SensitivityMode _baseMode;
  late double _baseThreshold;

  void _adoptBaseline(AppSettings s) {
    _baseMode = s.sensitivityMode;
    _baseThreshold = s.customThresholdDbFs;
  }

  @override
  void initState() {
    super.initState();
    _adoptBaseline(ref.read(settingsProvider));
    _mode = _baseMode;
    _threshold = _baseThreshold;
    _field = TextEditingController(text: _format(_threshold));
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  static String _format(double v) => v.toStringAsFixed(1);

  bool get _dirty =>
      _mode != _baseMode || (_threshold - _baseThreshold).abs() > 0.001;

  bool get _canSave => _dirty && _fieldError == null;

  /// Gate that would apply if the draft were saved.
  double _presetGate(AppSettings s) => s.resolveProfile(s.firearmPreset).minPeakDbFs;

  double get _activeGate =>
      _mode == SensitivityMode.custom
          ? _threshold
          : _presetGate(ref.read(settingsProvider));

  /// Sets the draft threshold and keeps the text field in step.
  void _setThreshold(double value) {
    setState(() {
      _threshold = value;
      _fieldError = null;
      _field.text = _format(value);
    });
  }

  void _onFieldChanged(String text) {
    final double? parsed = double.tryParse(text.trim());
    String? error;
    if (parsed == null) {
      error = 'Enter a number, for example -30.';
    } else if (!SensitivityLimits.isValid(parsed)) {
      error =
          'Must be between ${_format(SensitivityLimits.minDbFs)} and '
          '${_format(SensitivityLimits.maxDbFs)} dBFS.';
    }
    setState(() {
      _fieldError = error;
      if (error == null) _threshold = parsed!;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(settingsProvider.notifier).update(
            (s) => s.copyWith(
              sensitivityMode: _mode,
              customThresholdDbFs: _threshold,
            ),
          );
      messenger.showSnackBar(const SnackBar(
          content: Text('Sensitivity saved. New sessions use it.')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not save sensitivity: $e')));
    }
  }

  void _discard() {
    setState(() {
      _mode = _baseMode;
      _threshold = _baseThreshold;
      _fieldError = null;
      _field.text = _format(_threshold);
    });
  }

  Future<void> _toggleMonitor() async {
    final MonitorStatus s = _monitor.status.value;
    if (s == MonitorStatus.idle ||
        s == MonitorStatus.permissionDenied ||
        s == MonitorStatus.error) {
      await _monitor.start();
    } else {
      await _monitor.stop();
    }
  }

  Future<void> _calibrate() async {
    setState(() {
      _calibrating = true;
      _outcome = null;
    });
    final AudioLevelMonitor monitor = _monitor;
    final CalibrationOutcome result = await monitor.calibrate();
    if (!mounted) return;
    setState(() {
      _calibrating = false;
      _outcome = result;
      _outcomeRoute = monitor.route;
    });
  }

  void _useSuggestion() {
    final double? suggested = _outcome?.suggestedDbFs;
    if (suggested == null) return;
    setState(() {
      _mode = SensitivityMode.custom;
      _outcome = null;
    });
    _setThreshold(suggested);
  }

  @override
  Widget build(BuildContext context) {
    // Settings load from storage asynchronously. Follow the stored values
    // until the user starts editing, so the draft never shows stale defaults
    // and never overwrites edits in progress.
    ref.listen<AppSettings>(settingsProvider, (previous, next) {
      final bool hadEdits = _dirty;
      _adoptBaseline(next);
      if (!hadEdits) {
        setState(() {
          _mode = _baseMode;
          _threshold = _baseThreshold;
          _fieldError = null;
          _field.text = _format(_threshold);
        });
      }
    });
    final AppSettings settings = ref.watch(settingsProvider);
    // Keeps the shared monitor alive while this section is shown.
    ref.watch(levelMonitorProvider);
    return Panel(
      title: 'Sensitivity configuration',
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'The gate is the level a sound must reach before it can count. '
            'It is measured in dBFS, the digital level relative to full scale. '
            'Lower (more negative) values are more sensitive: they count quieter sounds. '
            'This is not microphone gain or sound pressure in dB SPL.',
            style: AppType.caption,
          ),
          const SizedBox(height: AppSpace.md),
          SegmentedButton<SensitivityMode>(
            segments: const [
              ButtonSegment(
                  value: SensitivityMode.preset,
                  label: Text('Firearm preset')),
              ButtonSegment(
                  value: SensitivityMode.custom,
                  label: Text('Custom sensitivity')),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: AppSpace.md),
          if (_mode == SensitivityMode.preset)
            _presetInfo(settings)
          else
            _customControls(),
          const SizedBox(height: AppSpace.lg),
          _Readouts(
            monitor: _monitor,
            activeGate: _activeGate,
            gateSource: _mode == SensitivityMode.custom
                ? 'Custom'
                : 'Preset: ${settings.resolveProfile(settings.firearmPreset).displayName}',
          ),
          const SizedBox(height: AppSpace.md),
          _LevelMeter(monitor: _monitor, gateDbFs: _activeGate),
          const SizedBox(height: AppSpace.md),
          _monitorControls(),
          const SizedBox(height: AppSpace.lg),
          const Divider(),
          const SizedBox(height: AppSpace.md),
          _calibrationPanel(settings),
          const SizedBox(height: AppSpace.lg),
          const Divider(),
          const SizedBox(height: AppSpace.md),
          _footer(),
        ],
      ),
    );
  }

  Widget _presetInfo(AppSettings settings) {
    final double gate = _presetGate(settings);
    return Text(
      'Using the firearm preset: ${settings.resolveProfile(settings.firearmPreset).displayName}, '
      'gate ${SensitivityLimits.format(gate)}. Change the preset in the Detection section below.',
      style: AppType.body,
    );
  }

  Widget _customControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Starting points', style: AppType.overline),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final SensitivityPreset p in kSensitivityPresets)
              ChoiceChip(
                label: Text('${p.label} ${p.dbFs.toStringAsFixed(0)}'),
                selected: (_threshold - p.dbFs).abs() < 0.05,
                onSelected: (_) => _setThreshold(p.dbFs),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _threshold,
                min: SensitivityLimits.minDbFs,
                max: SensitivityLimits.maxDbFs,
                divisions: SensitivityLimits.divisions,
                label: SensitivityLimits.format(_threshold),
                semanticFormatterCallback: SensitivityLimits.format,
                onChanged: _setThreshold,
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: TextField(
                controller: _field,
                keyboardType: const TextInputType.numberWithOptions(
                    signed: true, decimal: true),
                decoration: InputDecoration(
                  labelText: 'Threshold (dBFS)',
                  errorText: _fieldError,
                  errorMaxLines: 2,
                ),
                onChanged: _onFieldChanged,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                'Range ${_format(SensitivityLimits.minDbFs)} to '
                '${_format(SensitivityLimits.maxDbFs)}',
                style: AppType.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _setThreshold(SensitivityLimits.defaultDbFs),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: Text(
                'Reset to default (${_format(SensitivityLimits.defaultDbFs)} dBFS)'),
          ),
        ),
      ],
    );
  }

  Widget _monitorControls() {
    return ValueListenableBuilder<MonitorStatus>(
      valueListenable: _monitor.status,
      builder: (context, status, _) {
        final bool running = status == MonitorStatus.starting ||
            status == MonitorStatus.listening ||
            status == MonitorStatus.noInput;
        final String message = switch (status) {
          MonitorStatus.idle =>
            'Not monitoring. Start the test to see live input levels.',
          MonitorStatus.starting => 'Starting the microphone…',
          MonitorStatus.listening => 'Listening. Levels shown are live.',
          MonitorStatus.noInput =>
            _monitor.errorMessage ?? 'No audio input is arriving.',
          MonitorStatus.permissionDenied =>
            _monitor.errorMessage ?? 'Microphone permission was denied.',
          MonitorStatus.error => _monitor.errorMessage ?? 'Microphone error.',
        };
        final bool bad = status == MonitorStatus.permissionDenied ||
            status == MonitorStatus.error ||
            status == MonitorStatus.noInput;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: AppType.caption.copyWith(
                  color: bad ? AppColors.error : AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _calibrating ? null : _toggleMonitor,
                icon: Icon(running ? Icons.stop : Icons.mic, size: 18),
                label: Text(running ? 'Stop test' : 'Test microphone'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _calibrationPanel(AppSettings settings) {
    final CalibrationOutcome? o = _outcome;
    final MicCalibration? saved = settings.activeCalibration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            const Text('Background calibration', style: AppType.heading),
            FilledButton.tonalIcon(
              onPressed: _calibrating ? null : _calibrate,
              icon: const Icon(Icons.graphic_eq, size: 18),
              label: Text(_calibrating ? 'Listening…' : 'Calibrate (6 s)'),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          'Stay quiet for six seconds. Measures through: '
          '${settings.micSelection.displayName}. The suggested threshold is '
          'not applied until you accept it and save. The noise floor can be '
          'saved for this microphone; it measures ambient level, not a '
          'detection distance.',
          style: AppType.caption,
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          saved == null
              ? 'No saved calibration for this microphone.'
              : 'Saved for this microphone: noise floor '
                  '${SensitivityLimits.format(saved.noiseFloorDbFs)} · '
                  '${Fmt.shortDate(saved.measuredAt)}',
          style: AppType.caption.copyWith(
              color: saved == null ? AppColors.textMuted : AppColors.accent),
        ),
        if (_calibrating) ...[
          const SizedBox(height: AppSpace.md),
          const LinearProgressIndicator(),
        ],
        if (o != null) ...[
          const SizedBox(height: AppSpace.md),
          _calibrationResult(o),
        ],
      ],
    );
  }

  Widget _calibrationResult(CalibrationOutcome o) {
    if (o.issue != null) {
      return Row(
        children: [
          const StatusTag(label: 'Calibration failed', tone: Tone.error, icon: Icons.error_outline),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(o.message ?? 'Calibration could not complete.',
                style: AppType.caption),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Background (quiet moments)',
              SensitivityLimits.format(o.backgroundDbFs!)),
          _kv('Ambient peaks (95th percentile)',
              SensitivityLimits.format(o.noiseCeilingDbFs!)),
          _kv('Suggested threshold', SensitivityLimits.format(o.suggestedDbFs!),
              highlight: true),
          _kv('Windows analysed', '${o.windowCount}'),
          _kv('Measured through', _outcomeRoute?.displayName ?? '—'),
          if (_outcomeRoute?.selectedMissing ?? false) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              'The selected microphone was not connected, so this measured the '
              'system default input. Saving stores it for the system default.',
              style: AppType.caption.copyWith(color: AppColors.warning),
            ),
          ],
          if (o.warning != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(o.warning!, style: AppType.caption.copyWith(color: AppColors.warning)),
          ],
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              FilledButton(
                onPressed: _useSuggestion,
                child: const Text('Use suggestion'),
              ),
              OutlinedButton(
                onPressed: () => _saveCalibration(o),
                child: const Text('Save noise floor'),
              ),
              TextButton(
                onPressed: () => setState(() => _outcome = null),
                child: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Stores the measured noise floor for the input that was measured.
  Future<void> _saveCalibration(CalibrationOutcome o) async {
    final double? floor = o.backgroundDbFs;
    final double? peak = o.noiseCeilingDbFs;
    if (floor == null || peak == null) return;
    final MicRoute? route = _outcomeRoute;
    final MicSelection measured = (route == null || route.device == null)
        ? MicSelection.systemDefault
        : route.selection;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(settingsProvider.notifier).update((s) => s.withCalibration(
            measured,
            MicCalibration(
              noiseFloorDbFs: floor,
              ambientPeakDbFs: peak,
              windowCount: o.windowCount,
              measuredAt: DateTime.now(),
            ),
          ));
      messenger.showSnackBar(SnackBar(
          content: Text('Noise floor saved for ${measured.displayName}.')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not save calibration: $e')));
    }
  }

  Widget _kv(String k, String v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(k, style: AppType.caption)),
          Text(v,
              style: AppType.monoBody.copyWith(
                  color: highlight ? AppColors.accent : AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _footer() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpace.md,
      runSpacing: AppSpace.sm,
      children: [
        Text(
          _dirty
              ? (_fieldError == null
                  ? 'Unsaved changes.'
                  : 'Fix the threshold value to save.')
              : 'All changes saved.',
          style: AppType.caption,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _dirty ? _discard : null,
              child: const Text('Discard'),
            ),
            const SizedBox(width: AppSpace.sm),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Current input, active gate and background estimate, labelled separately.
class _Readouts extends StatelessWidget {
  const _Readouts({
    required this.monitor,
    required this.activeGate,
    required this.gateSource,
  });

  final AudioLevelMonitor monitor;
  final double activeGate;
  final String gateSource;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<LevelReading?>(
            valueListenable: monitor.level,
            builder: (context, reading, _) => _Readout(
              label: 'Input now',
              value: reading == null
                  ? '—'
                  : SensitivityLimits.format(reading.dbFs),
              color: reading != null && reading.dbFs >= activeGate
                  ? AppColors.accent
                  : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: _Readout(
            label: 'Active gate',
            value: SensitivityLimits.format(activeGate),
            caption: gateSource,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: ValueListenableBuilder<double?>(
            valueListenable: monitor.backgroundDbFs,
            builder: (context, bg, _) => _Readout(
              label: 'Background (est.)',
              value: bg == null ? '—' : SensitivityLimits.format(bg),
            ),
          ),
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    this.caption,
    this.color = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final String? caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppType.overline.copyWith(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: AppType.monoBody.copyWith(fontSize: 15, color: color)),
          ),
          if (caption != null)
            Text(caption!,
                style: AppType.caption.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Horizontal meter from -60 to 0 dBFS with the gate and background marked.
///
/// Repaints only when the monitor's level or background changes.
class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.monitor, required this.gateDbFs});

  final AudioLevelMonitor monitor;
  final double gateDbFs;

  static const double _floor = -60;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: ValueListenableBuilder<LevelReading?>(
            valueListenable: monitor.level,
            builder: (context, reading, _) {
              final double? level = reading?.dbFs;
              return ValueListenableBuilder<double?>(
                valueListenable: monitor.backgroundDbFs,
                builder: (context, bg, _) => RepaintBoundary(
                  child: CustomPaint(
                    painter: _MeterPainter(
                      levelFraction: _fraction(level),
                      gateFraction: _fraction(gateDbFs)!,
                      backgroundFraction: _fraction(bg),
                      levelAboveGate: level != null && level >= gateDbFs,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Row(
          children: [
            Text('${_floor.toInt()} dBFS', style: AppType.monoCaption.copyWith(fontSize: 10)),
            const Spacer(),
            Text('gate ${gateDbFs.toStringAsFixed(1)}',
                style: AppType.monoCaption.copyWith(fontSize: 10, color: AppColors.textPrimary)),
            const Spacer(),
            Text('0 dBFS', style: AppType.monoCaption.copyWith(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  double? _fraction(double? db) {
    if (db == null || !db.isFinite) return null;
    return ((db - _floor) / -_floor).clamp(0.0, 1.0);
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({
    required this.levelFraction,
    required this.gateFraction,
    required this.backgroundFraction,
    required this.levelAboveGate,
  });

  final double? levelFraction;
  final double gateFraction;
  final double? backgroundFraction;
  final bool levelAboveGate;

  @override
  void paint(Canvas canvas, Size size) {
    final double barTop = (size.height - 10) / 2;
    final RRect track = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, barTop, size.width, 10), const Radius.circular(AppRadius.sm));
    canvas.drawRRect(track, Paint()..color = AppColors.surfaceElevated);

    final double? lf = levelFraction;
    if (lf != null && lf > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barTop, size.width * lf, 10),
          const Radius.circular(AppRadius.sm),
        ),
        Paint()
          ..color = levelAboveGate ? AppColors.accent : AppColors.info,
      );
    }

    final double? bg = backgroundFraction;
    if (bg != null) {
      final double x = size.width * bg;
      canvas.drawRect(Rect.fromLTWH(x - 1, barTop - 4, 2, 18),
          Paint()..color = AppColors.textSecondary);
    }

    final double gx = size.width * gateFraction;
    canvas.drawRect(Rect.fromLTWH(gx - 1.5, 0, 3, size.height),
        Paint()..color = AppColors.textPrimary);
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.levelFraction != levelFraction ||
      old.gateFraction != gateFraction ||
      old.backgroundFraction != backgroundFraction ||
      old.levelAboveGate != levelAboveGate;
}
