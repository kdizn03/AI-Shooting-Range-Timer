import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../models/session.dart';
import '../../models/session_statistics.dart';
import '../theme/tokens.dart';
import 'status_tag.dart';

/// List row summarising a stored session.
class SessionCard extends StatelessWidget {
  /// Creates a [SessionCard].
  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
    this.onDelete,
    this.showDivider = true,
  });

  final Session session;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final SessionStatistics stats = SessionStatistics.fromSession(session);
    final String when =
        '${Fmt.relativeDay(session.startTime)} · ${Fmt.time(session.startTime)}';
    return Semantics(
      button: true,
      label: 'Session $when, ${stats.totalShots} detections, '
          '${Fmt.duration(stats.sessionDuration)}'
          '${session.isSimulated ? ', simulated' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.md),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(bottom: BorderSide(color: AppColors.border))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${stats.totalShots}',
                  style: AppType.monoBody.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(when,
                        style: AppType.heading.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      session.firearmProfile.displayName,
                      style: AppType.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (session.isSimulated) ...[
                      const SizedBox(height: AppSpace.xs),
                      const StatusTag(
                          label: 'Simulated', tone: Tone.info, dense: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Fmt.duration(stats.sessionDuration),
                      style: AppType.monoBody),
                  const SizedBox(height: 2),
                  Text(
                    stats.fastestInterval != null
                        ? 'best ${Fmt.split(stats.fastestInterval!)}'
                        : '${stats.totalShots} det.',
                    style: AppType.monoCaption,
                  ),
                ],
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete session',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(left: AppSpace.xs),
                  child: Icon(Icons.chevron_right,
                      color: AppColors.textMuted, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
