import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Entry point for the RangePulse application.
///
/// Wraps the app in a [ProviderScope] to enable Riverpod state management
/// throughout the widget tree.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  runApp(
    const ProviderScope(
      child: ShotTimerApp(),
    ),
  );
}

/// Adds bundled third-party licenses (fonts, YAMNet model, MediaPipe web
/// runtime) to the in-app license page.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (String name, String path) in const [
      ('Inter', 'assets/fonts/OFL-Inter.txt'),
      ('JetBrains Mono', 'assets/fonts/OFL-JetBrainsMono.txt'),
      // YAMNet: Copyright Google LLC. MediaPipe Tasks Audio: Copyright
      // The MediaPipe Authors. Both Apache License 2.0.
      ('YAMNet audio model (Google)', 'assets/models/LICENSE-Apache-2.0.txt'),
      ('MediaPipe Tasks Audio', 'assets/models/LICENSE-Apache-2.0.txt'),
    ]) {
      try {
        yield LicenseEntryWithLineBreaks(
            [name], await rootBundle.loadString(path));
      } catch (_) {
        // License file missing from this build; skip.
      }
    }
  });
}
