import 'package:flutter/material.dart';

/// Application theme configuration for Shot Timer AI.
///
/// Provides dark and light themes optimized for outdoor shooting
/// range visibility with high-contrast elements.
abstract final class AppTheme {
  /// Dark theme — the primary theme, optimized for outdoor use
  /// with high contrast and reduced glare.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
        primary: Colors.greenAccent,
        error: Colors.redAccent,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        displayMedium: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(fontSize: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E1E1E),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  /// Light theme — fallback for indoor use or accessibility needs.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.light,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
