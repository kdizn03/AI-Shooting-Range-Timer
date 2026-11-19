import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../models/detection_zone.dart';
import '../../models/microphone.dart';
import '../../models/sensitivity.dart';
import '../../providers/audio_input_provider.dart';
import '../../providers/settings_provider.dart';
import '../theme/tokens.dart';
import 'panel.dart';
import 'status_tag.dart';

/// Settings → Detection Zone.
///
/// Only profiles that really process the signal can be chosen.
/// Directional priority and a detection radius are listed with the reason
/// they are unavailable, not as controls.
class DetectionZoneSection extends ConsumerWidget {
  /// Creates a [DetectionZoneSection].
  const DetectionZoneSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DetectionZone zone =
        ref.watch(settingsProvider.select((s) => s.detectionZone));

    Future<void> choose(DetectionZone z) async {
      try {
        await ref
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(detectionZone: z));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save detection zone: $e')));
        }
      }
    }

    return Panel(
      title: 'Detection zone',
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Extra filtering after the decibel gate and classifier threshold. '
            'Your firearm preset and custom sensitivity are not changed by '
            'switching profiles.',
            style: AppType.caption,
          ),
          const SizedBox(height: AppSpace.md),
          for (final DetectionZone z in DetectionZone.values)
            if (z.isSupported)
              _ProfileOption(
                zone: z,
                selected: z == zone,
                onTap: () => choose(z),
              ),
          if (zone == DetectionZone.nearField) ...[
            const SizedBox(height: AppSpace.sm),
            const _NearFieldDetails(),
          ],
          const SizedBox(height: AppSpace.md),
          const Text('Needs additional hardware', style: AppType.overline),
          const SizedBox(height: AppSpace.sm),
          _Unavailable(
            title: DetectionZone.directional.label,
            reason: DirectionalSupport.current.reason,
          ),
          const SizedBox(height: AppSpace.sm),
          const _Unavailable(
            title: 'Detection radius',
            reason: DirectionalSupport.spatialRadiusReason,
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.zone,
    required this.selected,
    required this.onTap,
  });

  final DetectionZone zone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Semantics(
        selected: selected,
        button: true,
        label: zone.label,
        child: Material(
          color: selected ? AppColors.surfaceElevated : AppColors.surfaceSunken,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
            side: BorderSide(
                color: selected ? AppColors.accent : AppColors.border),
          ),
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? AppColors.accent : AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(zone.label, style: AppType.body),
                        const SizedBox(height: AppSpace.xs),
                        Text(zone.description, style: AppType.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rules near-field uses, and what it needs to work well.
class _NearFieldDetails extends ConsumerWidget {
  const _NearFieldDetails();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    final MicSelection mic = ref.watch(micSelectionProvider);
    final MicCalibration? cal = s.activeCalibration;
    String db(double v) => v.toStringAsFixed(0);
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
          Text(
            'Accepted: at least ${db(NearFieldPolicy.acceptSnrDb)} dB above '
            'background and direct sound at least '
            '${db(NearFieldPolicy.acceptDirectRatioDb)} dB above its echo.\n'
            'Rejected: under ${db(NearFieldPolicy.rejectSnrDb)} dB above '
            'background, or under ${db(NearFieldPolicy.rejectDirectRatioDb)} dB '
            'direct-to-echo.\n'
            'Anything between is recorded as uncertain, for you to review.',
            style: AppType.caption,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            cal == null
                ? 'No noise floor saved for ${mic.displayName}. Background is '
                    'measured live; until about 2 s of quiet has been heard, '
                    'events are marked uncertain. Calibrating in the '
                    'Sensitivity section avoids that.'
                : 'Starts each session from the saved noise floor for '
                    '${mic.displayName} '
                    '(${SensitivityLimits.format(cal.noiseFloorDbFs)}), then '
                    'follows the live background.',
            style: AppType.caption.copyWith(
                color: cal == null ? AppColors.warning : AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.sm),
          const Text(
            'These thresholds were set from one real recording and controlled '
            'distant-sounding versions of it, not from range testing. Review '
            'uncertain and accepted events at your range before relying on it.',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.title, required this.reason});

  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.block, size: 18, color: AppColors.textMuted),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: AppType.body),
                  const StatusTag(label: 'Unavailable', dense: true),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Text(reason, style: AppType.caption),
            ],
          ),
        ),
      ],
    );
  }
}
