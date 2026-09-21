import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Entry point for the Shot Timer AI application.
///
/// Wraps the app in a [ProviderScope] to enable Riverpod state management
/// throughout the widget tree.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: ShotTimerApp(),
    ),
  );
}

