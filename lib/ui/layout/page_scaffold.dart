import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'breakpoints.dart';

/// Layout for a top-level tab page inside the app shell.
///
/// Renders a page header (title, subtitle, actions) followed by [slivers],
/// centred with a responsive gutter and capped at [maxWidth] so content
/// never stretches across ultra-wide displays.
class PageScaffold extends StatelessWidget {
  /// Creates a [PageScaffold].
  const PageScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.maxWidth = AppSizes.maxContentWidth,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Widget above the title (e.g. the brand mark on mobile).
  final Widget? leading;
  final List<Widget> slivers;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final SizeClass sc = SizeClass.of(constraints.maxWidth);
            final double side = math.max(
              sc.gutter,
              (constraints.maxWidth - maxWidth) / 2,
            );
            final EdgeInsets pad = EdgeInsets.symmetric(horizontal: side);
            final bool stackActions = constraints.maxWidth < 420 && actions.isNotEmpty;

            final Widget header = Padding(
              padding: EdgeInsets.only(
                top: sc.isAtLeastExpanded ? AppSpace.xxl : AppSpace.lg,
                bottom: AppSpace.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(height: AppSpace.xl),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: sc.isAtLeastExpanded
                                    ? AppType.display
                                    : AppType.display.copyWith(fontSize: 26),
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppSpace.xs),
                              Text(subtitle!, style: AppType.bodySecondary),
                            ],
                          ],
                        ),
                      ),
                      if (!stackActions && actions.isNotEmpty) ...[
                        const SizedBox(width: AppSpace.md),
                        Wrap(spacing: AppSpace.sm, children: actions),
                      ],
                    ],
                  ),
                  if (stackActions) ...[
                    const SizedBox(height: AppSpace.md),
                    Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: actions),
                  ],
                ],
              ),
            );

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: pad,
                  sliver: SliverToBoxAdapter(child: header),
                ),
                for (final Widget s in slivers)
                  SliverPadding(padding: pad, sliver: s),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpace.xxxl),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Wraps a box widget as a sliver with bottom spacing.
class SliverSection extends StatelessWidget {
  /// Creates a [SliverSection].
  const SliverSection({super.key, required this.child, this.gap = AppSpace.xl});

  final Widget child;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(padding: EdgeInsets.only(bottom: gap), child: child),
    );
  }
}

/// Constrains detail-page content (pushed routes) to a centred column.
class ContentWidth extends StatelessWidget {
  /// Creates a [ContentWidth].
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppSizes.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final double gutter = SizeClass.of(c.maxWidth).gutter;
      // heightFactor: 1 shrink-wraps vertically; without it Align expands to
      // the max height (e.g. a bottom bar would fill the whole screen).
      return Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth + gutter * 2),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: child,
          ),
        ),
      );
    });
  }
}
