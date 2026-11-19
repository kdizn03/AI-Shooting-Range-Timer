import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format_utils.dart';
import '../../models/session.dart';
import '../../models/session_statistics.dart';
import '../../providers/session_history_provider.dart';
import '../layout/page_scaffold.dart';
import '../navigation.dart';
import '../theme/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/panel.dart';
import '../widgets/session_card.dart';
import '../widgets/state_views.dart';
import '../widgets/status_tag.dart';

/// Session-source filter.
enum HistoryFilter {
  all('All'),
  live('Live'),
  simulated('Simulated');

  const HistoryFilter(this.label);
  final String label;
}

/// Sort order.
enum HistorySort {
  newest('Newest first'),
  oldest('Oldest first'),
  mostEvents('Most detections'),
  longest('Longest duration'),
  fastest('Fastest split');

  const HistorySort(this.label);
  final String label;
}

/// Searchable, filterable list of stored sessions.
///
/// A card list on phones and tablets; an information-dense table at
/// desktop widths.
class HistoryScreen extends ConsumerStatefulWidget {
  /// Creates a [HistoryScreen].
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _search = TextEditingController();
  HistoryFilter _filter = HistoryFilter.all;
  HistorySort _sort = HistorySort.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<(Session, SessionStatistics)> _apply(List<Session> all) {
    final String q = _search.text.trim().toLowerCase();
    final List<(Session, SessionStatistics)> rows = [
      for (final Session s in all)
        if ((_filter == HistoryFilter.all) ||
            (_filter == HistoryFilter.live && !s.isSimulated) ||
            (_filter == HistoryFilter.simulated && s.isSimulated))
          if (q.isEmpty ||
              s.firearmProfile.displayName.toLowerCase().contains(q) ||
              s.firearmProfile.caliber.toLowerCase().contains(q) ||
              Fmt.dateTime(s.startTime).toLowerCase().contains(q) ||
              Fmt.relativeDay(s.startTime).toLowerCase().contains(q))
            (s, SessionStatistics.fromSession(s)),
    ];
    int cmpNullable(Duration? a, Duration? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    }

    rows.sort((a, b) => switch (_sort) {
          HistorySort.newest => b.$1.startTime.compareTo(a.$1.startTime),
          HistorySort.oldest => a.$1.startTime.compareTo(b.$1.startTime),
          HistorySort.mostEvents => b.$2.totalShots.compareTo(a.$2.totalShots),
          HistorySort.longest =>
            b.$2.sessionDuration.compareTo(a.$2.sessionDuration),
          HistorySort.fastest =>
            cmpNullable(a.$2.fastestInterval, b.$2.fastestInterval),
        });
    return rows;
  }

  Future<void> _delete(Session s) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete session?',
      message: 'This permanently removes the session from '
          '${Fmt.dateTime(s.startTime)} and its ${s.shotCount} events.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(sessionHistoryControllerProvider).delete(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Session deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  Future<void> _export(List<Session> sessions) async {
    final String json = const JsonEncoder.withIndent('  ')
        .convert(sessions.map((s) => s.toMap()).toList());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Copied ${sessions.length} session${sessions.length == 1 ? '' : 's'} '
          'to the clipboard as JSON'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Session>> history = ref.watch(sessionHistoryProvider);
    final List<Session> all = history.valueOrNull ?? const [];
    final List<(Session, SessionStatistics)> rows = _apply(all);

    return PageScaffold(
      title: 'History',
      subtitle: history.hasValue
          ? '${all.length} stored session${all.length == 1 ? '' : 's'}'
          : 'Stored sessions',
      actions: [
        OutlinedButton.icon(
          onPressed: rows.isEmpty
              ? null
              : () => _export([for (final r in rows) r.$1]),
          icon: const Icon(Icons.content_copy, size: 18),
          label: const Text('Copy as JSON'),
        ),
      ],
      slivers: [
        SliverSection(gap: AppSpace.lg, child: _controls(context)),
        ...history.when(
          loading: () => const [SliverSection(child: LoadingState())],
          error: (e, _) => [
            SliverSection(
              child: ErrorState(
                title: 'Could not load history',
                message: '$e',
                onRetry: () => ref.invalidate(sessionHistoryProvider),
              ),
            ),
          ],
          data: (_) {
            if (all.isEmpty) {
              return [
                SliverSection(
                  child: Panel(
                    child: EmptyState(
                      icon: Icons.history,
                      title: 'No sessions yet',
                      message: 'Completed sessions are saved here automatically.',
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
            if (rows.isEmpty) {
              return [
                SliverSection(
                  child: Panel(
                    child: EmptyState(
                      icon: Icons.search_off,
                      title: 'No matching sessions',
                      message: 'Try a different search or filter.',
                      action: TextButton(
                        onPressed: () => setState(() {
                          _search.clear();
                          _filter = HistoryFilter.all;
                        }),
                        child: const Text('Clear filters'),
                      ),
                    ),
                  ),
                ),
              ];
            }
            return [
              SliverToBoxAdapter(
                child: LayoutBuilder(builder: (context, c) {
                  return c.maxWidth >= 860
                      ? _Table(rows: rows, onDelete: _delete)
                      : _List(rows: rows, onDelete: _delete);
                }),
              ),
            ];
          },
        ),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    final Widget search = TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search by date, day or firearm profile',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () => setState(_search.clear),
                icon: const Icon(Icons.close, size: 18),
              ),
      ),
    );
    final Widget filter = SegmentedButton<HistoryFilter>(
      segments: [
        for (final f in HistoryFilter.values)
          ButtonSegment(value: f, label: Text(f.label)),
      ],
      selected: {_filter},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _filter = s.first),
    );
    final Widget sort = PopupMenuButton<HistorySort>(
      tooltip: 'Sort sessions',
      initialValue: _sort,
      onSelected: (s) => setState(() => _sort = s),
      itemBuilder: (context) => [
        for (final s in HistorySort.values)
          CheckedPopupMenuItem(
              value: s, checked: s == _sort, child: Text(s.label)),
      ],
      child: Container(
        height: AppSizes.minTouch,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpace.sm),
            Text(_sort.label, style: AppType.button.copyWith(fontSize: 14)),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 860) {
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: AppSpace.md),
            filter,
            const SizedBox(width: AppSpace.md),
            sort,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: AppSpace.md),
          filter,
          const SizedBox(height: AppSpace.sm),
          Align(alignment: Alignment.centerLeft, child: sort),
        ],
      );
    });
  }
}

class _List extends StatelessWidget {
  const _List({required this.rows, required this.onDelete});

  final List<(Session, SessionStatistics)> rows;
  final ValueChanged<Session> onDelete;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            SessionCard(
              session: rows[i].$1,
              showDivider: i < rows.length - 1,
              onTap: () => AppNav.openSession(context, rows[i].$1),
              onDelete: () => onDelete(rows[i].$1),
            ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.onDelete});

  final List<(Session, SessionStatistics)> rows;
  final ValueChanged<Session> onDelete;

  static const List<(String, int, bool)> _cols = [
    ('Date', 5, false),
    ('Profile', 5, false),
    ('Mode', 3, false),
    ('Duration', 3, true),
    ('Detections', 3, true),
    ('Avg split', 3, true),
    ('Fastest', 3, true),
  ];

  @override
  Widget build(BuildContext context) {
    Widget cell(int col, Widget child) => Expanded(
          flex: _cols[col].$2,
          child: Align(
            alignment:
                _cols[col].$3 ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          ),
        );

    String fmtOr(Duration? d) => d == null ? '—' : Fmt.split(d);

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                for (int i = 0; i < _cols.length; i++)
                  cell(i, Text(_cols[i].$1.toUpperCase(), style: AppType.overline)),
                const SizedBox(width: 56),
              ],
            ),
          ),
          for (int r = 0; r < rows.length; r++)
            Semantics(
              button: true,
              label: 'Session ${Fmt.dateTime(rows[r].$1.startTime)}',
              child: InkWell(
                onTap: () => AppNav.openSession(context, rows[r].$1),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.only(left: AppSpace.lg, right: AppSpace.sm),
                  decoration: BoxDecoration(
                    border: r < rows.length - 1
                        ? const Border(bottom: BorderSide(color: AppColors.border))
                        : null,
                  ),
                  child: Row(
                    children: [
                      cell(
                        0,
                        Text(Fmt.dateTime(rows[r].$1.startTime),
                            style: AppType.monoBody, overflow: TextOverflow.ellipsis),
                      ),
                      cell(
                        1,
                        Text(rows[r].$1.firearmProfile.displayName,
                            style: AppType.body, overflow: TextOverflow.ellipsis),
                      ),
                      cell(
                        2,
                        rows[r].$1.isSimulated
                            ? const StatusTag(label: 'Simulated', tone: Tone.info, dense: true)
                            : const StatusTag(label: 'Live', dense: true),
                      ),
                      cell(3,
                          Text(Fmt.duration(rows[r].$2.sessionDuration), style: AppType.monoBody)),
                      cell(
                        4,
                        Text('${rows[r].$2.totalShots}',
                            style: AppType.monoBody.copyWith(
                                color: AppColors.accent, fontWeight: FontWeight.w600)),
                      ),
                      cell(5, Text(fmtOr(rows[r].$2.averageInterval), style: AppType.monoBody)),
                      cell(6, Text(fmtOr(rows[r].$2.fastestInterval), style: AppType.monoBody)),
                      SizedBox(
                        width: 56,
                        child: IconButton(
                          tooltip: 'Delete session',
                          onPressed: () => onDelete(rows[r].$1),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
