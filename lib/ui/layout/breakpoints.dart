import 'package:flutter/widgets.dart';

/// Responsive size classes.
///
/// | Class     | Width        | Navigation      |
/// |-----------|--------------|-----------------|
/// | compact   | < 640        | bottom bar      |
/// | medium    | 640 – 767    | bottom bar      |
/// | expanded  | 768 – 1023   | navigation rail |
/// | large     | 1024 – 1439  | sidebar         |
/// | xlarge    | ≥ 1440       | sidebar         |
enum SizeClass {
  compact,
  medium,
  expanded,
  large,
  xlarge;

  /// Resolves the class for a logical [width].
  static SizeClass of(double width) {
    if (width < 640) return compact;
    if (width < 768) return medium;
    if (width < 1024) return expanded;
    if (width < 1440) return large;
    return xlarge;
  }

  /// Uses bottom navigation (phones and small tablets).
  bool get usesBottomNav => index <= medium.index;

  /// Uses the navigation rail (tablets).
  bool get usesRail => this == expanded;

  /// Uses the persistent sidebar (desktop).
  bool get usesSidebar => index >= large.index;

  /// At least tablet width.
  bool get isAtLeastExpanded => index >= expanded.index;

  /// At least desktop width.
  bool get isAtLeastLarge => index >= large.index;

  /// Horizontal page gutter.
  double get gutter => switch (this) {
        compact => 16,
        medium => 20,
        expanded => 24,
        large => 32,
        xlarge => 40,
      };
}

/// Convenience accessors.
extension SizeClassContext on BuildContext {
  /// Size class of the full window.
  SizeClass get sizeClass => SizeClass.of(MediaQuery.sizeOf(this).width);
}
