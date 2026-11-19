import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/format_utils.dart';
import '../../models/app_settings.dart';
import '../../models/detection_engine.dart';
import '../../models/firearm_profile.dart';
import '../../models/session.dart';
import '../../models/start_delay_mode.dart';
import '../../providers/app_status_provider.dart';
import '../../providers/session_history_provider.dart';
import '../../providers/settings_provider.dart';
import '../layout/page_scaffold.dart';
import '../theme/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/detection_status_card.dart';
import '../widgets/detection_zone_section.dart';
import '../widgets/microphone_section.dart';
import '../widgets/panel.dart';
import '../widgets/readiness.dart';
import '../widgets/sensitivity_section.dart';
import '../widgets/status_tag.dart';

/// Application settings. Every control changes real behaviour; values
/// persist and seed each new session's setup.
class SettingsScreen extends ConsumerWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsNotifier n = ref.read(settingsProvider.notifier);

    Future<void> set(AppSettings Function(AppSettings) f) async {
      try {
        await n.update(f);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save setting: $e')));
        }
      }
    }

    final List<Widget> sections = [
      const DetectionStatusCard(),
      _AudioSection(settings: s, set: set),
      const MicrophoneSection(),
      const SensitivitySection(),
      const DetectionZoneSection(),
      _Section(
        title: 'Detection',
        description: 'Applied to new sessions. Per-session overrides are available in setup.',
        children: [
          _Field(
            label: 'Default firearm profile',
            help: 'Sets the decibel gate a sound must exceed to count.',
            child: DropdownButtonFormField<FirearmPreset>(
              initialValue: s.firearmPreset,
              isExpanded: true,
              items: [
                for (final p in FirearmProfile.allPresets)
                  DropdownMenuItem(
                    value: p.preset,
                    child: Text('${p.displayName} · ${p.typicalDbRange}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (p) {
                if (p != null) set((x) => x.copyWith(firearmPreset: p));
              },
            ),
          ),
          _Field(
            label: 'Detection engine',
            help: "YAMNet is Google's on-device audio model; it checks each "
                'sound that passes the decibel gate. The energy heuristic '
                'only looks for sharp loud peaks.',
            child: SegmentedButton<DetectionEngine>(
              segments: [
                for (final DetectionEngine e in DetectionEngine.values)
                  ButtonSegment(value: e, label: Text(e.label)),
              ],
              selected: {s.detectionEngine},
              showSelectedIcon: false,
              onSelectionChanged: (v) =>
                  set((x) => x.copyWith(detectionEngine: v.first)),
            ),
          ),
          _SliderField(
            key: ValueKey(s.detectionEngine),
            label: s.detectionEngine.thresholdName,
            help: s.detectionEngine.thresholdHelp,
            value: s.activeThreshold,
            min: s.detectionEngine.minThreshold,
            max: s.detectionEngine.maxThreshold,
            divisions: s.detectionEngine.divisions,
            format: Fmt.percent,
            onChanged: (v) =>
                set((x) => x.withThreshold(x.detectionEngine, v)),
          ),
          _SliderField(
            label: 'Debounce window',
            help: 'Lockout after a detection so one shot is not counted twice. '
                'Splits faster than this cannot be recorded.',
            value: s.debounceMs.toDouble(),
            min: 100,
            max: 1000,
            divisions: 18,
            format: (v) => '${v.round()} ms',
            onChanged: (v) => set((x) => x.copyWith(debounceMs: v.round())),
          ),
        ],
      ),
      _Section(
        title: 'Calibration',
        description: 'Fine-tune timing and the custom decibel gate for your device.',
        children: [
          _SliderField(
            label: 'Latency compensation',
            help: 'Subtracted from each detection timestamp to offset audio '
                'buffering and inference delay. Default '
                '${TimingConstants.estimatedInferenceLatencyMs} ms.',
            value: s.latencyCompensationMs.toDouble(),
            min: 0,
            max: 200,
            divisions: 40,
            format: (v) => '${v.round()} ms',
            onChanged: (v) =>
                set((x) => x.copyWith(latencyCompensationMs: v.round())),
          ),
          _SliderField(
            label: 'Custom profile gate',
            help: 'Peak level (dBFS) required when the “Custom Profile” firearm '
                'preset is selected. Lower values detect quieter sounds.',
            value: s.customGateDbFs,
            min: -40,
            max: 0,
            divisions: 40,
            format: (v) => '${v.round()} dBFS',
            onChanged: (v) => set((x) => x.copyWith(customGateDbFs: v)),
          ),
        ],
      ),
      _Section(
        title: 'Notifications & sounds',
        children: [
          _Field(
            label: 'Start delay',
            help: 'Time between pressing Start and the beep.',
            child: SegmentedButton<StartDelayMode>(
              segments: [
                for (final m in StartDelayMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {s.startDelay},
              showSelectedIcon: false,
              onSelectionChanged: (v) =>
                  set((x) => x.copyWith(startDelay: v.first)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start beep', style: AppType.body),
            subtitle: const Text('Play the audible beep when timing begins.',
                style: AppType.caption),
            value: s.playStartBeep,
            onChanged: (v) => set((x) => x.copyWith(playStartBeep: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibrate on detection', style: AppType.body),
            subtitle: const Text('Haptic pulse for each detected event (on supported devices).',
                style: AppType.caption),
            value: s.hapticOnDetection,
            onChanged: (v) => set((x) => x.copyWith(hapticOnDetection: v)),
          ),
        ],
      ),
      const _DataSection(),
      _Section(
        title: 'Appearance',
        children: [
          const _InfoRow('Theme', 'Dark tactical (single theme)'),
          _InfoRow(
            'Reduced motion',
            (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                ? 'On — follows system setting'
                : 'Off — follows system setting',
          ),
        ],
      ),
      _Section(
        title: 'About RangePulse',
        children: [
          const _InfoRow('Version', appVersion),
          Consumer(builder: (context, ref, _) {
            final bool? bundled = ref.watch(modelBundledProvider).valueOrNull;
            return _InfoRow(
              'Detection engine',
              s.detectionEngine == DetectionEngine.energy
                  ? 'Energy heuristic (sharp-peak detector, no model)'
                  : bundled == null
                      ? 'Checking…'
                      : bundled
                          ? 'YAMNet (Google, Apache 2.0) · runs on this device'
                          : 'YAMNet model missing from this build — '
                              'sessions use the energy heuristic',
            );
          }),
          const _InfoRow('Audio pipeline',
              '16 kHz mono · 250 ms level windows · YAMNet checks ~1 s '
                  'around each loud sound'),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            alignment: WrapAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'RangePulse',
                  applicationVersion: appVersion,
                ),
                child: const Text('Open-source licenses'),
              ),
              TextButton(
                onPressed: () async {
                  final bool ok = await showConfirmDialog(
                    context,
                    title: 'Reset settings?',
                    message: 'All settings return to their defaults. Sessions are not affected.',
                    confirmLabel: 'Reset',
                  );
                  if (ok) await set((_) => const AppSettings());
                },
                child: const Text('Reset to defaults'),
              ),
            ],
          ),
        ],
      ),
    ];

    return PageScaffold(
      title: 'Settings',
      subtitle: 'Saved on this device and applied to new sessions',
      maxWidth: 1040,
      slivers: [
        SliverToBoxAdapter(
          child: LayoutBuilder(builder: (context, c) {
            if (c.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final w in sections) ...[w, const SizedBox(height: AppSpace.lg)],
                ],
              );
            }
            // Two balanced columns on wide screens.
            final List<Widget> left = [], right = [];
            for (int i = 0; i < sections.length; i++) {
              (i.isEven ? left : right)
                  .addAll([sections[i], const SizedBox(height: AppSpace.lg)]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
                const SizedBox(width: AppSpace.lg),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _AudioSection extends ConsumerWidget {
  const _AudioSection({required this.settings, required this.set});

  final AppSettings settings;
  final Future<void> Function(AppSettings Function(AppSettings)) set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Readiness? r = ref.watch(readinessProvider);
    final MicPermission? perm = ref.watch(micPermissionProvider).valueOrNull;
    final bool canRequest =
        perm == MicPermission.notRequested || perm == MicPermission.denied;
    final ReadinessItem? mic = r?.items.first;

    return _Section(
      title: 'Audio input',
      children: [
        _Field(
          label: 'Default detection source',
          help: 'Simulation generates random events for testing and is never '
              'counted in analytics by default.',
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: false, icon: Icon(Icons.mic, size: 18), label: Text('Live microphone')),
              ButtonSegment(
                  value: true,
                  icon: Icon(Icons.science_outlined, size: 18),
                  label: Text('Simulation')),
            ],
            selected: {settings.useSimulation},
            showSelectedIcon: false,
            onSelectionChanged: (v) => set((x) => x.copyWith(useSimulation: v.first)),
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 132, child: Text('Microphone', style: AppType.caption)),
            Expanded(
              child: mic == null
                  ? const Text('Checking…', style: AppType.body)
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: StatusTag(label: mic.value, tone: mic.tone, icon: mic.icon),
                    ),
            ),
          ],
        ),
        if (canRequest || perm == MicPermission.blocked) ...[
          const SizedBox(height: AppSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: canRequest
                ? OutlinedButton.icon(
                    onPressed: () async {
                      final MicPermission result = await requestMicPermission(ref);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(result == MicPermission.granted
                            ? 'Microphone access granted'
                            : 'Microphone access was not granted'),
                      ));
                    },
                    icon: const Icon(Icons.mic, size: 18),
                    label: const Text('Request microphone access'),
                  )
                : const Text(
                    'Access is blocked. Enable the microphone for RangePulse in your '
                    'device’s system settings.',
                    style: AppType.caption),
          ),
        ],
        const _InfoRow('Capture format', '16 kHz · mono · PCM 16-bit'),
      ],
    );
  }
}

class _DataSection extends ConsumerWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Session>? sessions = ref.watch(sessionHistoryProvider).valueOrNull;
    final int count = sessions?.length ?? 0;

    return _Section(
      title: 'Data management',
      description: 'Sessions are stored locally on this device.',
      children: [
        _InfoRow('Stored sessions', sessions == null ? 'Loading…' : '$count'),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            OutlinedButton.icon(
              onPressed: count == 0
                  ? null
                  : () async {
                      final String json = const JsonEncoder.withIndent('  ')
                          .convert(sessions!.map((e) => e.toMap()).toList());
                      await Clipboard.setData(ClipboardData(text: json));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Copied $count sessions to the clipboard as JSON')));
                    },
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text('Copy all as JSON'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.tint(AppColors.error, 0.5)),
              ),
              onPressed: count == 0
                  ? null
                  : () async {
                      final bool ok = await showConfirmDialog(
                        context,
                        title: 'Delete all sessions?',
                        message: 'This permanently deletes all $count stored sessions '
                            'and their events. This cannot be undone.',
                        confirmLabel: 'Delete all',
                        destructive: true,
                        icon: Icons.delete_forever_outlined,
                      );
                      if (!ok) return;
                      try {
                        await ref.read(sessionHistoryControllerProvider).deleteAll();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All sessions deleted')));
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not delete sessions: $e')));
                      }
                    },
              icon: const Icon(Icons.delete_forever_outlined, size: 18),
              label: const Text('Delete all sessions'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.description});

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(title, style: AppType.heading)),
          if (description != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(description!, style: AppType.caption),
          ],
          const SizedBox(height: AppSpace.md),
          const Divider(),
          const SizedBox(height: AppSpace.md),
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: AppSpace.md),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.help});

  final String label;
  final String? help;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
        if (help != null) ...[
          const SizedBox(height: 2),
          Text(help!, style: AppType.caption),
        ],
        const SizedBox(height: AppSpace.sm),
        child,
      ],
    );
  }
}

/// Slider that updates its label live but persists only on release.
class _SliderField extends StatefulWidget {
  const _SliderField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
    this.help,
  });

  final String label;
  final String? help;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  State<_SliderField> createState() => _SliderFieldState();
}

class _SliderFieldState extends State<_SliderField> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final double v = (_drag ?? widget.value).clamp(widget.min, widget.max);
    return _Field(
      label: widget.label,
      help: widget.help,
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: v,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              label: widget.format(v),
              semanticFormatterCallback: widget.format,
              onChanged: (x) => setState(() => _drag = x),
              onChangeEnd: (x) {
                widget.onChanged(x);
                setState(() => _drag = null);
              },
            ),
          ),
          SizedBox(
            width: 84,
            child: Text(widget.format(v),
                textAlign: TextAlign.right,
                style: AppType.monoBody.copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 132, child: Text(label, style: AppType.caption)),
        Expanded(child: Text(value, style: AppType.body)),
      ],
    );
  }
}
