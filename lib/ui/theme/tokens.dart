/// Design tokens for the RangePulse "Dark Tactical Minimalist" identity.
///
/// Every colour, spacing step, radius, and text style used by the UI is
/// defined here. Screens and widgets must reference these tokens instead of
/// hardcoding values.
library;

import 'package:flutter/material.dart';

/// Colour tokens.
abstract final class AppColors {
  // Surfaces
  static const Color background = Color(0xFF111418);
  static const Color surface = Color(0xFF1C2229);
  static const Color surfaceElevated = Color(0xFF252D36);
  static const Color surfaceSunken = Color(0xFF0C0F12);

  // Lines
  static const Color border = Color(0xFF2C353F);
  static const Color borderStrong = Color(0xFF3A4550);

  // Text
  static const Color textPrimary = Color(0xFFF4F7F5);
  static const Color textSecondary = Color(0xFFA0A8B2);
  static const Color textMuted = Color(0xFF6E7781);

  /// Text placed on top of the lime accent.
  static const Color onAccent = Color(0xFF111418);

  // Accents
  /// Electric lime: primary actions, active state, key metrics.
  static const Color accent = Color(0xFFA3E635);

  /// Steel blue: informational elements, secondary actions, chart marks.
  static const Color info = Color(0xFF60A5FA);

  // Status
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);

  /// Translucent tint of [color] for tag/badge backgrounds.
  static Color tint(Color color, [double alpha = 0.14]) =>
      color.withValues(alpha: alpha);
}

/// 4-pt spacing scale.
abstract final class AppSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii. Kept tight for a technical, rugged feel.
abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

/// Interactive sizing.
abstract final class AppSizes {
  /// Minimum touch target (Material / WCAG guidance).
  static const double minTouch = 48;

  /// Height of primary session controls (large, glove-friendly).
  static const double controlHeight = 64;

  /// Sidebar width on desktop.
  static const double sidebarWidth = 248;

  /// Maximum width of tab page content.
  static const double maxContentWidth = 1200;

  /// Maximum width for single-column reading content (forms, settings).
  static const double maxReadableWidth = 760;
}

/// Motion tokens. Kept short; never used for continuous animation.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 220);

  /// Returns [d], or zero when the platform requests reduced motion.
  static Duration respect(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

/// Typography tokens.
///
/// Inter for interface text; JetBrains Mono with tabular figures for timers,
/// timestamps, and numeric readouts so digits never shift horizontally.
abstract final class AppType {
  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle display = TextStyle(
    fontFamily: sans,
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: sans,
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Uppercase micro-label used above metrics and section headers.
  static const TextStyle overline = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: AppColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// Numeric readout (metrics, table numbers).
  static const TextStyle metric = TextStyle(
    fontFamily: mono,
    fontSize: 24,
    height: 1.1,
    fontWeight: FontWeight.w600,
    fontFeatures: tabular,
    color: AppColors.textPrimary,
  );

  /// Small numeric text (timestamps in lists, table cells).
  static const TextStyle monoBody = TextStyle(
    fontFamily: mono,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w500,
    fontFeatures: tabular,
    color: AppColors.textPrimary,
  );

  static const TextStyle monoCaption = TextStyle(
    fontFamily: mono,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w400,
    fontFeatures: tabular,
    color: AppColors.textSecondary,
  );

  /// The dominant session timer.
  static const TextStyle timer = TextStyle(
    fontFamily: mono,
    fontSize: 96,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -2,
    fontFeatures: tabular,
    color: AppColors.textPrimary,
  );
}
