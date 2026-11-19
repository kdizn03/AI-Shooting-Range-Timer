import 'package:flutter/material.dart';

import '../models/session.dart';
import 'screens/results_screen.dart';
import 'screens/session_setup_screen.dart';

/// Central navigation helpers so every entry point uses the same real
/// workflow.
abstract final class AppNav {
  /// Opens session setup (the real start-session workflow).
  ///
  /// [simulation] pre-selects the detection source; `null` uses settings.
  static Future<void> startNewSession(BuildContext context, {bool? simulation}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionSetupScreen(initialSimulation: simulation),
      ),
    );
  }

  /// Opens the results/review screen for a stored [session].
  static Future<void> openSession(BuildContext context, Session session) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ResultsScreen(session: session)),
    );
  }

  /// Returns to the app shell, clearing pushed routes.
  static void backToShell(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
