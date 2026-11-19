import 'package:flutter/material.dart';

import 'ui/layout/app_shell.dart';
import 'ui/theme/app_theme.dart';

/// Root widget for RangePulse.
///
/// Configures the [MaterialApp] with the dark tactical theme and the
/// adaptive [AppShell] as the home route.
class ShotTimerApp extends StatelessWidget {
  /// Creates a new [ShotTimerApp].
  const ShotTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RangePulse',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}
