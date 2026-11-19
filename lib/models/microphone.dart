import 'package:equatable/equatable.dart';

/// Whether an input is the device's own microphone or something attached.
///
/// Derived only from what the operating system reports. When the report
/// does not say, the kind is [unknown]; it is never guessed.
enum MicKind {
  builtIn('Built-in'),
  external('External'),
  unknown('Unknown type');

  const MicKind(this.label);

  /// Short label for tags.
  final String label;
}

/// Platform family, which decides how input labels are read.
enum MicPlatform { android, ios, web, desktop }

/// An audio input the operating system reports.
class MicDevice extends Equatable {
  const MicDevice({required this.id, required this.label, required this.kind});

  /// Platform ID used to select the device. On Android it can change when
  /// the device is reconnected, so selections also match on [label].
  final String id;

  /// Name reported by the OS. Empty on the web until microphone permission
  /// has been granted.
  final String label;

  final MicKind kind;

  /// Label for display, with a fallback for unnamed inputs.
  String get displayName => label.trim().isEmpty ? 'Unnamed input' : label;

  @override
  List<Object?> get props => [id, label, kind];
}

// Android's record plugin labels inputs as "<product> (<type>[, address])".
const List<String> _androidExternalTypes = [
  'wired headset',
  'usb device',
  'usb accessory',
  'usb headset',
  'bluetooth',
  'line analog',
  'line digital',
  'auxiliary line',
  'dock',
  'hearing aid',
  'hdmi',
];

/// Classifies an input from the label the platform reports.
///
/// - Android labels include the device type, e.g. "(built-in microphone)" or
///   "(USB device)", so both kinds are reliable there.
/// - iOS lists the device's own microphone ("iPhone Microphone",
///   "iPad Microphone") plus attached inputs, so anything else is external.
/// - Web and desktop labels are free text. Only explicit wording counts;
///   otherwise the kind is [MicKind.unknown].
MicKind classifyMicLabel(String label, MicPlatform platform) {
  final String l = label.toLowerCase();
  switch (platform) {
    case MicPlatform.android:
      if (l.contains('(built-in microphone')) return MicKind.builtIn;
      if (_androidExternalTypes.any(l.contains)) return MicKind.external;
      return MicKind.unknown;
    case MicPlatform.ios:
      if (l.isEmpty) return MicKind.unknown;
      if (RegExp(r'^(iphone|ipad|ipod) microphone').hasMatch(l) ||
          l == 'built-in microphone') {
        return MicKind.builtIn;
      }
      return MicKind.external;
    case MicPlatform.web:
    case MicPlatform.desktop:
      if (l.contains('built-in') || l.contains('internal')) {
        return MicKind.builtIn;
      }
      if (l.contains('usb') ||
          l.contains('bluetooth') ||
          l.contains('headset') ||
          l.contains('airpods')) {
        return MicKind.external;
      }
      return MicKind.unknown;
  }
}

/// The input the user chose, or the system default when [id] is null.
///
/// Stores both ID and label so the choice survives Android reassigning IDs
/// when a device is reconnected.
class MicSelection extends Equatable {
  const MicSelection({this.id, this.label});

  /// The operating system's default input.
  static const MicSelection systemDefault = MicSelection();

  final String? id;
  final String? label;

  bool get isSystemDefault => id == null;

  /// Key used to store calibration for this input.
  String get calibrationKey {
    if (isSystemDefault) return 'default';
    final String? l = label?.trim();
    return (l == null || l.isEmpty) ? 'id:$id' : 'label:$l';
  }

  String get displayName => isSystemDefault
      ? 'System default input'
      : ((label?.trim().isEmpty ?? true) ? 'Unnamed input' : label!);

  /// Finds this selection among [devices]: by ID first, then by label.
  /// Returns null for the system default, or when the input is missing.
  MicDevice? resolve(List<MicDevice> devices) {
    if (isSystemDefault) return null;
    for (final MicDevice d in devices) {
      if (d.id == id) return d;
    }
    final String? l = label?.trim();
    if (l == null || l.isEmpty) return null;
    for (final MicDevice d in devices) {
      if (d.label.trim() == l) return d;
    }
    return null;
  }

  @override
  List<Object?> get props => [id, label];
}

/// A saved background measurement for one input.
///
/// Records ambient level as captured through that microphone. It does not
/// describe a physical detection radius.
class MicCalibration extends Equatable {
  const MicCalibration({
    required this.noiseFloorDbFs,
    required this.ambientPeakDbFs,
    required this.windowCount,
    required this.measuredAt,
  });

  /// Background level during quiet moments (dBFS).
  final double noiseFloorDbFs;

  /// 95th-percentile ambient peak (dBFS).
  final double ambientPeakDbFs;

  /// Number of 250 ms windows measured.
  final int windowCount;

  final DateTime measuredAt;

  Map<String, dynamic> toMap() => {
        'noiseFloorDbFs': noiseFloorDbFs,
        'ambientPeakDbFs': ambientPeakDbFs,
        'windowCount': windowCount,
        'measuredAt': measuredAt.toIso8601String(),
      };

  /// Parses a stored calibration; returns null if anything is invalid.
  static MicCalibration? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final Object? floor = raw['noiseFloorDbFs'];
    final Object? peak = raw['ambientPeakDbFs'];
    final Object? count = raw['windowCount'];
    final DateTime? at = DateTime.tryParse('${raw['measuredAt']}');
    if (floor is! num || peak is! num || count is! num || at == null) {
      return null;
    }
    final double f = floor.toDouble();
    final double p = peak.toDouble();
    bool valid(double v) => v.isFinite && v >= -96 && v <= 0;
    if (!valid(f) || !valid(p)) return null;
    return MicCalibration(
      noiseFloorDbFs: f,
      ambientPeakDbFs: p,
      windowCount: count.toInt(),
      measuredAt: at,
    );
  }

  @override
  List<Object?> get props =>
      [noiseFloorDbFs, ambientPeakDbFs, windowCount, measuredAt];
}

/// What a session is actually recording from.
class MicRoute extends Equatable {
  const MicRoute({
    required this.selection,
    this.device,
    this.selectedMissing = false,
  });

  /// What the user asked for.
  final MicSelection selection;

  /// The input passed to the recorder; null means the OS default input.
  final MicDevice? device;

  /// The chosen input was not connected, so the OS default is in use.
  final bool selectedMissing;

  String get displayName =>
      device?.displayName ?? 'System default input';

  @override
  List<Object?> get props => [selection, device, selectedMissing];
}
