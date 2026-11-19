import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format_utils.dart';
import '../../models/app_settings.dart';
import '../../models/detection_zone.dart';
import '../../models/microphone.dart';
import '../../models/sensitivity.dart';
import '../../providers/audio_input_provider.dart';
import '../../providers/settings_provider.dart';
import '../theme/tokens.dart';
import 'panel.dart';
import 'status_tag.dart';

/// Summary of what new sessions will detect with, and anything to fix.
class DetectionStatusCard extends ConsumerWidget {
  /// Creates a [DetectionStatusCard].
  const DetectionStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    final List<MicDevice>? devices = ref.watch(micDevicesProvider).valueOrNull;
    final MicDevice? device =
        devices == null ? null : s.micSelection.resolve(devices);
    final bool micMissing = !s.micSelection.isSystemDefault &&
        devices != null &&
        device == null;
    final MicCalibration? cal = s.activeCalibration;

    final List<String> warnings = [
      if (micMissing)
        ('${s.micSelection.displayName} is not connected. Sessions will use '
            'the system default input until it is.'),
      if (s.detectionZone == DetectionZone.nearField && cal == null)
        ('Near-field priority has no saved noise floor for this microphone; '
            'events in the first seconds of a session are marked uncertain.'),
      if (s.useSimulation)
        ('Default source is simulation: no microphone is used and the '
            'detection zone does not apply.'),
    ];

    return Panel(
      title: 'Detection status',
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row('Profile', s.detectionZone.label),
          _row(
              'Microphone',
              micMissing
                  ? '${s.micSelection.displayName} (not connected)'
                  : (device?.displayName ?? s.micSelection.displayName)),
          _row(
            'Threshold',
            '${s.detectionEngine.label} ≥ ${Fmt.percent(s.activeThreshold)} · '
                'gate ${SensitivityLimits.format(s.firearmProfile.minPeakDbFs)}',
          ),
          _row(
            'Background',
            cal == null
                ? 'Not calibrated · measured live in sessions'
                : 'Noise floor ${SensitivityLimits.format(cal.noiseFloorDbFs)} '
                    '(calibrated ${Fmt.shortDate(cal.measuredAt)})',
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            for (final String w in warnings)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(w,
                          style: AppType.caption
                              .copyWith(color: AppColors.warning)),
                    ),
                  ],
                ),
              ),
          ] else ...[
            const SizedBox(height: AppSpace.sm),
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusTag(
                  label: 'No warnings', tone: Tone.accent, icon: Icons.check, dense: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: AppType.caption)),
            Expanded(child: Text(v, style: AppType.body)),
          ],
        ),
      );
}
