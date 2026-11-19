import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/classifier/audio_classification.dart';
import '../theme/tokens.dart';
import 'mic_indicator.dart';
import 'status_tag.dart';

/// Monitoring state of the audio pipeline, derived from real events.
enum MonitorState {
  /// Session not started yet.
  idle('Idle', Tone.neutral, Icons.mic_none),

  /// Microphone and model are starting.
  starting('Starting microphone…', Tone.info, Icons.mic_none),

  /// Receiving audio and classifying.
  listening('Listening', Tone.accent, Icons.mic),

  /// No audio frames received recently.
  noSignal('No audio signal', Tone.warning, Icons.mic_off),

  /// Session paused; detections ignored.
  paused('Paused — detections ignored', Tone.warning, Icons.pause),

  /// Simulation mode; microphone not used.
  simulated('Simulation — mic not used', Tone.info, Icons.science_outlined),

  /// Microphone permission denied.
  permissionDenied('Microphone permission denied', Tone.error, Icons.mic_off),

  /// Pipeline failed.
  error('Audio error', Tone.error, Icons.error_outline),

  /// Session ended.
  stopped('Stopped', Tone.neutral, Icons.stop_circle_outlined);

  const MonitorState(this.label, this.tone, this.icon);
  final String label;
  final Tone tone;
  final IconData icon;

  /// Whether the pulse indicator should animate.
  bool get isLive => this == listening;
}

/// Audio monitoring panel: state, classifier engine, latest classification,
/// and a live input-level meter with the firearm profile's decibel gate.
///
/// Rebuilds only when [classification] (≈4 Hz) or [state] changes.
class AudioStatus extends StatelessWidget {
  /// Creates an [AudioStatus].
  const AudioStatus({
    super.key,
    required this.state,
    required this.classification,
    required this.gateDbFs,
    this.verdict,
    this.engineLabel,
    this.detail,
    this.compact = false,
    this.hasAudioInput = true,
    this.footer,
  });

  /// Extra context shown under the status (input, detection zone).
  final Widget? footer;

  /// Whether a microphone feeds this session. When `false` (simulation),
  /// no input-level meter is shown in any state.
  final bool hasAudioInput;

  final MonitorState state;

  /// Latest classification from the pipeline (live mode only).
  final ValueListenable<AudioClassification?> classification;

  /// Latest classifier verdict, for classifiers that only examine sounds
  /// above the gate (YAMNet). Shown while [classification] is level-only.
  final ValueListenable<AudioClassification?>? verdict;

  /// Detection gate in dBFS for the active firearm profile.
  final double gateDbFs;

  /// Inference engine in use, if known.
  final String? engineLabel;

  /// Extra error detail.
  final String? detail;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool showMeter = hasAudioInput &&
        (state == MonitorState.listening ||
            state == MonitorState.noSignal ||
            state == MonitorState.paused);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Audio monitoring: ${state.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: MicIndicator(
                  isActive: state.isLive,
                  label: state.label,
                  inactiveLabel: state.label,
                  color: state.tone.color,
                ),
              ),
              if (engineLabel != null && !compact)
                Flexible(
                  child: Tooltip(
                    message: 'Classifier engine in use',
                    child: StatusTag(
                      label: engineLabel!,
                      icon: Icons.memory,
                      dense: true,
                    ),
                  ),
                ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(detail!,
                style: AppType.caption.copyWith(color: state.tone.color),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppSpace.sm),
            footer!,
          ],
          if (showMeter) ...[
            const SizedBox(height: AppSpace.md),
            RepaintBoundary(
              child: ListenableBuilder(
                listenable: Listenable.merge([classification, verdict]),
                builder: (context, _) => _LevelReadout(
                  classification: classification.value,
                  verdict: verdict?.value,
                  gateDbFs: gateDbFs,
                  dimmed: state == MonitorState.paused,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelReadout extends StatelessWidget {
  const _LevelReadout({
    required this.classification,
    required this.gateDbFs,
    required this.dimmed,
    this.verdict,
  });

  final AudioClassification? classification;
  final AudioClassification? verdict;

  /// How long a verdict stays on screen after its sound.
  static const Duration _verdictHold = Duration(seconds: 3);
  final double gateDbFs;
  final bool dimmed;

  static const double _floor = -60;

  @override
  Widget build(BuildContext context) {
    final AudioClassification? c = classification;
    final double level = c?.peakDbFs ?? _floor;
    final bool overGate = c != null && level >= gateDbFs;
    final String label = c == null
        ? 'Waiting for audio…'
        : c.analyzed
            ? _describe(c)
            : _levelOnlyLabel(c, overGate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text('INPUT', style: AppType.overline),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                label,
                style: AppType.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              c == null ? '— dBFS' : '${level.toStringAsFixed(1)} dBFS',
              style: AppType.monoCaption,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Semantics(
          label: c == null
              ? 'Input level unavailable'
              : 'Input level ${level.toStringAsFixed(0)} dBFS, '
                  'gate ${gateDbFs.toStringAsFixed(0)} dBFS'
                  '${overGate ? ', above gate' : ''}',
          child: SizedBox(
            height: 8,
            child: CustomPaint(
              painter: _MeterPainter(
                fraction: ((level - _floor) / -_floor).clamp(0.0, 1.0),
                gateFraction: ((gateDbFs - _floor) / -_floor).clamp(0.0, 1.0),
                color: dimmed
                    ? AppColors.textMuted
                    : overGate
                        ? AppColors.accent
                        : AppColors.info,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Row(
          children: [
            Text('${_floor.toInt()}', style: AppType.monoCaption.copyWith(fontSize: 10)),
            const Spacer(),
            Text('gate ${gateDbFs.toStringAsFixed(0)}',
                style: AppType.monoCaption.copyWith(fontSize: 10)),
            const Spacer(),
            Text('0', style: AppType.monoCaption.copyWith(fontSize: 10)),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          c?.backgroundDbFs == null
              ? 'Background: measuring…'
              : 'Background ${c!.backgroundDbFs!.toStringAsFixed(1)} dBFS',
          style: AppType.monoCaption,
        ),
      ],
    );
  }

  String _describe(AudioClassification c) =>
      '${_labelName(c.label)} · ${(c.confidence * 100).round()}%';

  /// For a window the classifier did not examine: the recent verdict if
  /// there is one, otherwise what is happening.
  String _levelOnlyLabel(AudioClassification c, bool overGate) {
    final AudioClassification? v = verdict;
    if (v != null &&
        c.timestamp.difference(v.timestamp) <= _verdictHold &&
        !c.timestamp.isBefore(v.timestamp)) {
      return 'Last check: ${_describe(v)}';
    }
    return overGate ? 'Checking sound…' : 'Below gate';
  }

  static String _labelName(AudioLabel l) => switch (l) {
        AudioLabel.gunshot => 'Impulse (gunshot class)',
        AudioLabel.backgroundNoise => 'Background',
        AudioLabel.voice => 'Voice',
        AudioLabel.otherLoudSound => 'Other loud sound',
        AudioLabel.beep => 'Beep',
      };
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({
    required this.fraction,
    required this.gateFraction,
    required this.color,
  });

  final double fraction;
  final double gateFraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect track = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(AppRadius.sm));
    canvas.drawRRect(track, Paint()..color = AppColors.surfaceSunken);
    if (fraction > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * fraction, size.height),
          const Radius.circular(AppRadius.sm),
        ),
        Paint()..color = color,
      );
    }
    final double gx = size.width * gateFraction;
    canvas.drawRect(
      Rect.fromLTWH(gx - 1, -2, 2, size.height + 4),
      Paint()..color = AppColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.fraction != fraction ||
      old.gateFraction != gateFraction ||
      old.color != color;
}
