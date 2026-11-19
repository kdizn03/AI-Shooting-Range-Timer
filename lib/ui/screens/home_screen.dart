import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format_utils.dart';
import '../../models/app_settings.dart';
import '../../models/history_summary.dart';
import '../../models/session.dart';
import '../../models/session_statistics.dart';
import '../../providers/app_status_provider.dart';
import '../../providers/session_history_provider.dart';
import '../../providers/settings_provider.dart';
import '../layout/breakpoints.dart';
import '../layout/page_scaffold.dart';
import '../navigation.dart';
import '../theme/tokens.dart';
import '../widgets/panel.dart';
import '../widgets/readiness.dart';
import '../widgets/session_card.dart';
import '../widgets/state_views.dart';
import '../widgets/statistics_card.dart';
import '../widgets/status_tag.dart';

/// Home dashboard: readiness, quick start, totals, and recent activity.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Session>> history = ref.watch(sessionHistoryProvider);
    final SizeClass sc = context.sizeClass;

    return PageScaffold(
      title: 'Dashboard',
      subtitle: 'Session overview and quick start',
      leading: sc.usesSidebar ? null : const BrandLockup(),
      slivers: [
        const SliverSection(child: _HeroRow()),
        ...history.when(
          loading: () => const [SliverSection(child: LoadingState())],
          error: (e, _) => [
            SliverSection(
              child: ErrorState(
                title: 'Could not load sessions',
                message: '$e',
                onRetry: () => ref.invalidate(sessionHistoryProvider),
              ),
            ),
          ],
          data: (sessions) => _dataSlivers(context, ref, sessions),
        ),
      ],
    );
  }

  List<Widget> _dataSlivers(
      BuildContext context, WidgetRef ref, List<Session> sessions) {
    final HistorySummary summary = HistorySummary.from(sessions);
    final List<Session> recent = [...sessions]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    final Widget stats = AdaptiveGrid(
      minItemWidth: 150,
      children: [
        StatCard(
          label: 'Sessions',
          value: '${summary.sessionCount}',
          icon: Icons.layers_outlined,
          caption: summary.simulatedCount > 0
              ? '+${summary.simulatedCount} simulated (excluded)'
              : 'Live sessions',
        ),
        StatCard(
          label: 'Detections',
          value: '${summary.totalDetections}',
          icon: Icons.graphic_eq,
          highlight: true,
          caption: 'Rejected events excluded',
        ),
        StatCard(
          label: 'Avg duration',
          value: summary.averageDuration == null
              ? '—'
              : Fmt.duration(summary.averageDuration!),
          icon: Icons.schedule,
          caption: 'Active time, pauses excluded',
        ),
        StatCard(
          label: 'Best split',
          value: summary.bestSplit == null ? '—' : Fmt.split(summary.bestSplit!),
          icon: Icons.bolt,
          caption: summary.bestSplit == null
              ? 'Needs 2+ events in a session'
              : 'Fastest interval recorded',
        ),
      ],
    );

    if (recent.isEmpty) {
      return [
        SliverSection(child: stats),
        SliverSection(
          child: Panel(
            child: EmptyState(
              icon: Icons.timer_outlined,
              title: 'No sessions yet',
              message:
                  'Run your first session to see recent activity and trends here.',
              action: FilledButton.icon(
                onPressed: () => AppNav.startNewSession(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start new session'),
              ),
            ),
          ),
        ),
      ];
    }

    final Widget latest = _LatestSession(session: recent.first);
    final Widget activity = Panel(
      title: 'Recent activity',
      padding: const EdgeInsets.only(top: AppSpace.md),
      headerPadding: const EdgeInsets.only(left: AppSpace.lg),
      trailing: Padding(
        padding: const EdgeInsets.only(right: AppSpace.sm),
        child: TextButton(
          onPressed: () =>
              ref.read(selectedTabProvider.notifier).state = AppTab.history,
          child: const Text('View all'),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < recent.length && i < 5; i++)
            SessionCard(
              session: recent[i],
              showDivider: i < 4 && i < recent.length - 1,
              onTap: () => AppNav.openSession(context, recent[i]),
            ),
        ],
      ),
    );

    return [
      SliverSection(child: stats),
      SliverSection(
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 880) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: latest),
                const SizedBox(width: AppSpace.lg),
                Expanded(flex: 6, child: activity),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              latest,
              const SizedBox(height: AppSpace.lg),
              activity,
            ],
          );
        }),
      ),
    ];
  }
}

class _HeroRow extends ConsumerWidget {
  const _HeroRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final Widget start = Panel(
      padding: const EdgeInsets.all(AppSpace.xl),
      borderColor: AppColors.borderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEW SESSION', style: AppType.overline),
          const SizedBox(height: AppSpace.sm),
          const Text('Start a timed session', style: AppType.title),
          const SizedBox(height: AppSpace.xs),
          const Text(
            'Set the firearm profile, start delay and detection source, then '
            'shoot on the beep. Every detected event is timed from the beep.',
            style: AppType.bodySecondary,
          ),
          const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              StatusTag(
                  label: settings.firearmProfile.displayName,
                  icon: Icons.tune),
              StatusTag(label: settings.startDelay.label, icon: Icons.timer_outlined),
              StatusTag(
                  label: '${settings.detectionEngine.label} · '
                      '≥ ${Fmt.percent(settings.activeThreshold)}',
                  icon: Icons.filter_alt_outlined),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          Builder(builder: (context) {
            final Widget primary = FilledButton.icon(
              onPressed: () => AppNav.startNewSession(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start new session'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            );
            final Widget secondary = OutlinedButton.icon(
              onPressed: () =>
                  AppNav.startNewSession(context, simulation: true),
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Simulation drill'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
            );
            // Full-width, stacked actions on phones; inline otherwise.
            // (Decided from window width: this panel may sit inside an
            // IntrinsicHeight, which cannot measure a LayoutBuilder.)
            if (MediaQuery.sizeOf(context).width < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  primary,
                  const SizedBox(height: AppSpace.sm),
                  secondary,
                ],
              );
            }
            return Wrap(
              spacing: AppSpace.md,
              runSpacing: AppSpace.md,
              children: [primary, secondary],
            );
          }),
        ],
      ),
    );

    final Widget readiness = Panel(
      title: 'System readiness',
      padding: const EdgeInsets.all(AppSpace.xl),
      trailing: TextButton(
        onPressed: () =>
            ref.read(selectedTabProvider.notifier).state = AppTab.settings,
        child: const Text('Configure'),
      ),
      child: const ReadinessPanel(),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 880) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: start),
              const SizedBox(width: AppSpace.lg),
              Expanded(flex: 2, child: readiness),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [start, const SizedBox(height: AppSpace.lg), readiness],
      );
    });
  }
}

class _LatestSession extends StatelessWidget {
  const _LatestSession({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final SessionStatistics s = SessionStatistics.fromSession(session);
    return Panel(
      title: 'Latest session',
      trailing: TextButton(
        onPressed: () => AppNav.openSession(context, session),
        child: const Text('Review'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Fmt.dateTime(session.startTime), style: AppType.heading),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(session.firearmProfile.displayName, style: AppType.caption),
              if (session.isSimulated)
                const StatusTag(label: 'Simulated', tone: Tone.info, dense: true),
              if (s.rejectedShots > 0)
                StatusTag(
                    label: '${s.rejectedShots} rejected',
                    tone: Tone.error,
                    dense: true),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          AdaptiveGrid(
            minItemWidth: 96,
            spacing: AppSpace.sm,
            children: [
              _Mini('Duration', Fmt.duration(s.sessionDuration)),
              _Mini('Detections', '${s.totalShots}', accent: true),
              _Mini('Avg split',
                  s.averageInterval == null ? '—' : Fmt.split(s.averageInterval!)),
              _Mini('Fastest',
                  s.fastestInterval == null ? '—' : Fmt.split(s.fastestInterval!)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value, {this.accent = false});

  final String label;
  final String value;
  final bool accent;

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
          Text(label.toUpperCase(), style: AppType.overline.copyWith(fontSize: 10)),
          const SizedBox(height: AppSpace.xs),
          Text(value,
              style: AppType.metric.copyWith(
                  fontSize: 18,
                  color: accent ? AppColors.accent : AppColors.textPrimary)),
        ],
      ),
    );
  }
}
