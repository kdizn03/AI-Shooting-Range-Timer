import 'package:flutter/material.dart';

import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

/// Root widget for the Shot Timer AI application.
///
/// Configures the [MaterialApp] with the app theme and initial route.
class ShotTimerApp extends StatelessWidget {
  /// Creates a new [ShotTimerApp].
  const ShotTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shot Timer AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

