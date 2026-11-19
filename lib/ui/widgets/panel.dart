import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The standard RangePulse card surface.
///
/// One consistent card treatment: flat surface, 1px border, 12px radius,
/// optional overline title and trailing action.
class Panel extends StatelessWidget {
  /// Creates a [Panel].
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.onTap,
    this.semanticLabel,
    this.headerPadding = EdgeInsets.zero,
  });

  /// Extra padding around the title row (for panels with edge-to-edge
  /// content and no horizontal [padding]).
  final EdgeInsetsGeometry headerPadding;

  final Widget child;

  /// Uppercase section label shown above [child].
  final String? title;

  /// Widget placed at the end of the title row (e.g. a "View all" link).
  final Widget? trailing;

  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (title != null || trailing != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: headerPadding,
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title!.toUpperCase(), style: AppType.overline),
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          child,
        ],
      );
    }

    return Semantics(
      container: true,
      label: semanticLabel,
      button: onTap != null,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: content),
        ),
      ),
    );
  }
}
