import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../models/detection_engine.dart';
import '../../providers/app_status_provider.dart';
import '../../providers/settings_provider.dart';
import '../theme/tokens.dart';
import 'status_tag.dart';

/// The RangePulse mark: a waveform glyph on a dark tile with a lime edge.
class BrandMark extends StatelessWidget {
  /// Creates a [BrandMark].
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(size * 0.22),
          border: Border.all(color: AppColors.accent, width: 1.5),
        ),
        child: Icon(Icons.graphic_eq, size: size * 0.6, color: AppColors.accent),
      ),
    );
  }
}

/// Brand mark + wordmark.
class BrandLockup extends StatelessWidget {
  /// Creates a [BrandLockup].
  const BrandLockup({super.key, this.showTagline = true});

  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'RangePulse, AI shooting range timer',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandMark(size: 34),
          const SizedBox(width: AppSpace.md),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('RangePulse',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.heading.copyWith(
                        fontSize: 17, letterSpacing: -0.2)),
                if (showTagline)
                  Text('AI SHOOTING RANGE TIMER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.overline
                          .copyWith(fontSize: 9, letterSpacing: 0.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single readiness check.
class ReadinessItem {
  const ReadinessItem(this.label, this.value, this.tone, this.icon);
  final String label;
  final String value;
  final Tone tone;
  final IconData icon;
}

/// Overall readiness derived from real permission, asset, and settings state.
class Readiness {
  const Readiness({required this.items, required this.ready, required this.headline});

  final List<ReadinessItem> items;

  /// `false` only when a live session cannot capture audio.
  final bool ready;
  final String headline;
}

/// Computes current readiness. Values are `null` while loading.
final readinessProvider = Provider<Readiness?>((ref) {
  final AsyncValue<MicPermission> mic = ref.watch(micPermissionProvider);
  final AsyncValue<bool> model = ref.watch(modelBundledProvider);
  final AppSettings settings = ref.watch(settingsProvider);
  if (mic.isLoading || model.isLoading) return null;

  final MicPermission perm = mic.valueOrNull ?? MicPermission.unknown;
  final bool bundled = model.valueOrNull ?? false;

  final ReadinessItem micItem = switch (perm) {
    MicPermission.granted =>
      const ReadinessItem('Microphone', 'Permission granted', Tone.accent, Icons.mic),
    MicPermission.notRequested => const ReadinessItem(
        'Microphone', 'Will ask when a session starts', Tone.info, Icons.mic_none),
    MicPermission.denied =>
      const ReadinessItem('Microphone', 'Permission denied', Tone.warning, Icons.mic_off),
    MicPermission.blocked => const ReadinessItem(
        'Microphone', 'Blocked in system settings', Tone.error, Icons.mic_off),
    MicPermission.browserManaged => const ReadinessItem(
        'Microphone', 'Browser will prompt', Tone.info, Icons.mic_none),
    MicPermission.unknown => const ReadinessItem(
        'Microphone', 'Status unavailable on this device', Tone.neutral, Icons.mic_none),
  };

  final ReadinessItem engine = settings.detectionEngine == DetectionEngine.energy
      ? const ReadinessItem(
          'Detection', 'Energy heuristic', Tone.neutral, Icons.memory)
      : bundled
          ? const ReadinessItem(
              'Detection', 'YAMNet AI (on device)', Tone.accent, Icons.memory)
          : const ReadinessItem('Detection',
              'YAMNet missing · energy heuristic', Tone.warning, Icons.memory);

  final ReadinessItem mode = settings.useSimulation
      ? const ReadinessItem('Default mode', 'Simulation', Tone.info, Icons.science_outlined)
      : const ReadinessItem('Default mode', 'Live microphone', Tone.neutral, Icons.hearing);

  final bool micBlocked =
      perm == MicPermission.blocked || perm == MicPermission.denied;
  final bool ready = settings.useSimulation || !micBlocked;
  return Readiness(
    items: [micItem, engine, mode],
    ready: ready,
    headline: !ready
        ? 'Microphone access needed'
        : settings.useSimulation
            ? 'Ready · simulation'
            : 'Ready to monitor',
  );
});

/// Readiness checklist used on the dashboard and in the sidebar.
class ReadinessPanel extends ConsumerWidget {
  /// Creates a [ReadinessPanel].
  const ReadinessPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Readiness? r = ref.watch(readinessProvider);
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.sm),
        child: Text('Checking system…', style: AppType.caption),
      );
    }
    final Tone headTone = r.ready ? Tone.accent : Tone.error;
    final Widget head = Row(
      children: [
        Icon(r.ready ? Icons.check_circle : Icons.error_outline,
            size: 16, color: headTone.color),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(r.headline,
              style: AppType.body.copyWith(
                  fontWeight: FontWeight.w600, color: headTone.color)),
        ),
      ],
    );

    return Semantics(
      container: true,
      label: 'System readiness: ${r.headline}',
      child: Container(
        padding: EdgeInsets.all(compact ? AppSpace.md : 0),
        decoration: compact
            ? BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.border),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compact) ...[
              const Text('SYSTEM', style: AppType.overline),
              const SizedBox(height: AppSpace.sm),
            ],
            head,
            const SizedBox(height: AppSpace.sm),
            for (final ReadinessItem item in r.items)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(item.icon, size: 14, color: item.tone.color),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    if (!compact)
                      SizedBox(
                        width: 96,
                        child: Text(item.label, style: AppType.caption),
                      ),
                    Expanded(
                      child: Text(
                        item.value,
                        style: AppType.caption.copyWith(
                          color: item.tone == Tone.neutral
                              ? AppColors.textSecondary
                              : item.tone.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
