import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/microphone.dart';
import '../../providers/app_status_provider.dart';
import '../../providers/audio_input_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/audio/audio_level_monitor.dart';
import '../theme/tokens.dart';
import 'panel.dart';
import 'status_tag.dart';

const String _defaultKey = '__system_default__';

/// Settings → Microphone: choose the input, see its type, permission and
/// connection state, and check its live level.
///
/// Everything shown comes from the platform: the device list from the
/// audio plugin, the type from the label the OS reports, the level from
/// captured audio. Nothing is assumed about hardware that is not listed.
class MicrophoneSection extends ConsumerWidget {
  /// Creates a [MicrophoneSection].
  const MicrophoneSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MicSelection selection = ref.watch(micSelectionProvider);
    final AsyncValue<List<MicDevice>> devices = ref.watch(micDevicesProvider);
    final MicPermission? perm = ref.watch(micPermissionProvider).valueOrNull;
    final AudioLevelMonitor monitor = ref.watch(levelMonitorProvider);
    final bool labelsHidden =
        ref.read(microphoneManagerProvider).labelsNeedPermission &&
            (devices.valueOrNull?.every((d) => d.label.trim().isEmpty) ??
                false);

    final List<MicDevice> list = devices.valueOrNull ?? const [];
    final MicDevice? resolved = selection.resolve(list);
    final bool missing =
        !selection.isSystemDefault && devices.hasValue && resolved == null;

    Future<void> select(MicSelection s) async {
      try {
        await ref
            .read(settingsProvider.notifier)
            .update((x) => x.copyWith(micSelection: s));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save microphone: $e')));
        }
      }
    }

    return Panel(
      title: 'Microphone',
      padding: const EdgeInsets.all(AppSpace.lg),
      trailing: IconButton(
        tooltip: 'Refresh input list',
        onPressed: () => ref.invalidate(micDevicesProvider),
        icon: const Icon(Icons.refresh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choose which input RangePulse records from. External microphones '
            'appear here only if the operating system offers them as an audio '
            'input; not every USB, Lightning, Bluetooth or analog microphone '
            'does.',
            style: AppType.caption,
          ),
          const SizedBox(height: AppSpace.md),
          _row(
            'Active input',
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                    resolved?.displayName ?? selection.displayName,
                    style: AppType.body),
                if (resolved != null)
                  StatusTag(
                    label: resolved.kind.label,
                    tone: resolved.kind == MicKind.external
                        ? Tone.info
                        : Tone.neutral,
                    dense: true,
                  ),
              ],
            ),
          ),
          _row('Connection', _connection(selection, devices, missing)),
          _row('Permission', Text(_permissionText(perm), style: AppType.body)),
          const SizedBox(height: AppSpace.sm),
          devices.when(
            loading: () => const Text('Reading inputs…', style: AppType.caption),
            error: (e, _) => Text('Could not read the input list: $e',
                style: AppType.caption.copyWith(color: AppColors.error)),
            data: (list) => DropdownButtonFormField<String>(
              key: ValueKey('mic-${selection.id}-${list.length}'),
              initialValue: selection.isSystemDefault
                  ? _defaultKey
                  : (resolved?.id ?? 'missing:${selection.id}'),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Input device',
                prefixIcon: Icon(Icons.mic_external_on_outlined, size: 20),
              ),
              items: [
                const DropdownMenuItem(
                  value: _defaultKey,
                  child: Text('System default input'),
                ),
                for (final MicDevice d in list)
                  DropdownMenuItem(
                    value: d.id,
                    child: Text('${d.displayName} · ${d.kind.label}',
                        overflow: TextOverflow.ellipsis),
                  ),
                if (missing)
                  DropdownMenuItem(
                    value: 'missing:${selection.id}',
                    child: Text('${selection.displayName} · not connected',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v == null || v.startsWith('missing:')) return;
                if (v == _defaultKey) {
                  select(MicSelection.systemDefault);
                  return;
                }
                final MicDevice d = list.firstWhere((x) => x.id == v);
                select(MicSelection(id: d.id, label: d.label));
              },
            ),
          ),
          if (labelsHidden) ...[
            const SizedBox(height: AppSpace.sm),
            const Text(
              'The browser hides input names until microphone access is '
              'granted. Run "Test microphone" once, then refresh the list.',
              style: AppType.caption,
            ),
          ],
          if (missing) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              'The selected input is not connected. Sessions will record from '
              'the system default input and say so on screen.',
              style: AppType.caption.copyWith(color: AppColors.warning),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          _LiveLevel(monitor: monitor),
        ],
      ),
    );
  }

  Widget _connection(
      MicSelection s, AsyncValue<List<MicDevice>> devices, bool missing) {
    if (s.isSystemDefault) {
      return const Text('Chosen by the operating system', style: AppType.body);
    }
    if (devices.isLoading) return const Text('Checking…', style: AppType.body);
    if (devices.hasError) {
      return const StatusTag(
          label: 'Unknown', tone: Tone.warning, icon: Icons.help_outline, dense: true);
    }
    return missing
        ? const StatusTag(
            label: 'Not connected', tone: Tone.warning, icon: Icons.link_off, dense: true)
        : const StatusTag(
            label: 'Connected', tone: Tone.accent, icon: Icons.link, dense: true);
  }

  static String _permissionText(MicPermission? p) => switch (p) {
        null => 'Checking…',
        MicPermission.granted => 'Granted',
        MicPermission.notRequested => 'Not requested yet',
        MicPermission.denied => 'Denied',
        MicPermission.blocked => 'Blocked in system settings',
        MicPermission.browserManaged => 'Managed by the browser',
        MicPermission.unknown => 'Unavailable on this device',
      };

  Widget _row(String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
                width: 110, child: Text(label, style: AppType.caption)),
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: value),
            ),
          ],
        ),
      );
}

/// Compact live level from the shared monitor.
class _LiveLevel extends StatelessWidget {
  const _LiveLevel({required this.monitor});

  final AudioLevelMonitor monitor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MonitorStatus>(
      valueListenable: monitor.status,
      builder: (context, status, _) {
        final bool running = status == MonitorStatus.starting ||
            status == MonitorStatus.listening ||
            status == MonitorStatus.noInput;
        return Row(
          children: [
            Expanded(
              child: RepaintBoundary(
                child: ValueListenableBuilder<LevelReading?>(
                  valueListenable: monitor.level,
                  builder: (context, reading, _) {
                    final String text = switch (status) {
                      MonitorStatus.listening when reading != null =>
                        'Input now ${reading.dbFs.toStringAsFixed(1)} dBFS',
                      MonitorStatus.starting => 'Starting…',
                      MonitorStatus.noInput => 'No audio arriving',
                      MonitorStatus.permissionDenied => 'Permission denied',
                      MonitorStatus.error =>
                        monitor.errorMessage ?? 'Microphone error',
                      _ => 'Live level: not monitoring',
                    };
                    final double fraction = reading == null
                        ? 0
                        : ((reading.dbFs + 60) / 60).clamp(0.0, 1.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(text,
                            style: AppType.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: AppSpace.xs),
                        ClipRRect(
                          borderRadius: AppRadius.mdAll,
                          child: LinearProgressIndicator(
                            value: running ? fraction : 0,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceSunken,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            OutlinedButton(
              onPressed: () => running ? monitor.stop() : monitor.start(),
              child: Text(running ? 'Stop' : 'Test'),
            ),
          ],
        );
      },
    );
  }
}
