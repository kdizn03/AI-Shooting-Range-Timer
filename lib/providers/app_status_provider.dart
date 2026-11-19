import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/classifier/yamnet_labels.dart';

/// Primary navigation destinations in the app shell.
enum AppTab { home, history, analytics, settings }

/// Currently selected shell tab. Any screen may switch tabs through this.
final selectedTabProvider = StateProvider<AppTab>((ref) => AppTab.home);

/// Microphone permission as reported by the platform.
enum MicPermission {
  /// Permission granted.
  granted,

  /// Not yet requested; the OS will prompt when a session starts.
  notRequested,

  /// Denied; the user may be prompted again.
  denied,

  /// Permanently denied or restricted; must be changed in system settings.
  blocked,

  /// The browser handles the permission prompt itself (web builds).
  browserManaged,

  /// Status could not be determined on this platform.
  unknown,
}

/// Reads the real microphone permission status without prompting.
final micPermissionProvider = FutureProvider<MicPermission>((ref) async {
  if (kIsWeb) return MicPermission.browserManaged;
  try {
    final PermissionStatus status = await Permission.microphone.status;
    if (status.isGranted || status.isLimited) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermission.blocked;
    }
    if (status.isDenied) return MicPermission.notRequested;
    return MicPermission.unknown;
  } catch (_) {
    // Desktop platforms without permission_handler support.
    return MicPermission.unknown;
  }
});

/// Requests microphone permission and refreshes [micPermissionProvider].
Future<MicPermission> requestMicPermission(WidgetRef ref) async {
  if (kIsWeb) return MicPermission.browserManaged;
  try {
    final PermissionStatus status = await Permission.microphone.request();
    ref.invalidate(micPermissionProvider);
    if (status.isGranted || status.isLimited) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermission.blocked;
    }
    return MicPermission.denied;
  } catch (_) {
    return MicPermission.unknown;
  }
}

/// Whether the trained TFLite model asset is bundled with this build.
///
/// When it is not, live sessions run the energy-heuristic fallback
/// classifier; the UI reports this rather than implying AI inference.
final modelBundledProvider = FutureProvider<bool>((ref) async {
  try {
    await rootBundle.load(Yamnet.modelAssetPath);
    return true;
  } catch (_) {
    return false;
  }
});

/// Application version shown in About.
const String appVersion = '1.0.0';
