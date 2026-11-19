import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Semantic tone of a status element. Each tone maps to a reserved colour.
enum Tone {
  neutral(AppColors.textSecondary),
  accent(AppColors.accent),
  info(AppColors.info),
  warning(AppColors.warning),
  error(AppColors.error);

  const Tone(this.color);

  /// Foreground colour for this tone.
  final Color color;
}

/// Compact status label: icon + text on a tinted background.
///
/// Status is always communicated by text and icon, never by colour alone.
class StatusTag extends StatelessWidget {
  /// Creates a [StatusTag].
  const StatusTag({
    super.key,
    required this.label,
    this.tone = Tone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Tone tone;
  final IconData? icon;

  /// Smaller variant for list rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color c = tone.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : AppSpace.sm,
        vertical: dense ? 2 : AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.tint(c, tone == Tone.neutral ? 0.10 : 0.14),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.tint(c, 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: c),
            SizedBox(width: dense ? 4 : 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: (dense ? AppType.caption.copyWith(fontSize: 11) : AppType.caption)
                  .copyWith(color: c, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
