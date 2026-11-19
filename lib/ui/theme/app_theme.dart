import 'package:flutter/material.dart';

import 'tokens.dart';

/// Application theme configuration for RangePulse.
///
/// Built entirely from the tokens in `tokens.dart`. The product ships a
/// single dark "tactical" theme, which is also the most legible option for
/// outdoor ranges and low-light indoor bays.
abstract final class AppTheme {
  /// The RangePulse dark tactical theme.
  static ThemeData get darkTheme {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.info,
      onSecondary: AppColors.background,
      tertiary: AppColors.warning,
      onTertiary: AppColors.background,
      error: AppColors.error,
      onError: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.surfaceSunken,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceElevated,
      surfaceContainerHighest: AppColors.surfaceElevated,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
    );

    const TextTheme textTheme = TextTheme(
      displayLarge: AppType.timer,
      displayMedium: AppType.display,
      headlineSmall: AppType.title,
      titleLarge: AppType.title,
      titleMedium: AppType.heading,
      titleSmall: AppType.heading,
      bodyLarge: AppType.body,
      bodyMedium: AppType.body,
      bodySmall: AppType.caption,
      labelLarge: AppType.button,
      labelMedium: AppType.caption,
      labelSmall: AppType.overline,
    );

    final ButtonStyle filled = FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onAccent,
      disabledBackgroundColor: AppColors.surfaceElevated,
      disabledForegroundColor: AppColors.textMuted,
      minimumSize: const Size(AppSizes.minTouch, AppSizes.minTouch),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      textStyle: AppType.button,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: AppType.sans,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.heading,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(style: filled),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filled),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(AppSizes.minTouch, AppSizes.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          textStyle: AppType.button,
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.info,
          minimumSize: const Size(AppSizes.minTouch, AppSizes.minTouch),
          textStyle: AppType.button,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size(AppSizes.minTouch, AppSizes.minTouch),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSunken,
        isDense: true,
        contentPadding:
            EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 14),
        hintStyle: AppType.bodySecondary,
        labelStyle: AppType.bodySecondary,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.surfaceElevated,
        thumbColor: AppColors.accent,
        overlayColor: Color(0x29A3E635),
        valueIndicatorColor: AppColors.surfaceElevated,
        valueIndicatorTextStyle: AppType.monoBody,
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.onAccent
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.surfaceElevated,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.borderStrong,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.minTouch)),
          textStyle: const WidgetStatePropertyAll(AppType.button),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.borderStrong),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.tint(AppColors.accent, 0.16)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textSecondary,
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: Color(0x29A3E635),
        side: BorderSide(color: AppColors.border),
        labelStyle: AppType.caption,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceSunken,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.tint(AppColors.accent, 0.16),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppType.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surfaceSunken,
        indicatorColor: AppColors.tint(AppColors.accent, 0.16),
        selectedIconTheme: const IconThemeData(color: AppColors.accent),
        unselectedIconTheme:
            const IconThemeData(color: AppColors.textSecondary),
        selectedLabelTextStyle: AppType.caption.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: AppType.caption,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppType.title,
        contentTextStyle: AppType.bodySecondary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: AppType.body,
        actionTextColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.smAll,
        ),
        textStyle: AppType.caption,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        minVerticalPadding: AppSpace.md,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.accent),
      focusColor: AppColors.tint(AppColors.accent, 0.24),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: AppType.body,
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surfaceElevated),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }

  /// Retained for API compatibility. RangePulse is a dark-only product, so
  /// this returns the same tactical theme as [darkTheme].
  static ThemeData get lightTheme => darkTheme;
}
