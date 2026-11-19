/// Human-readable formatting for dates and durations in the UI.
library;

import 'package:intl/intl.dart';

/// Display formatting helpers. Numeric output is designed to be rendered in
/// a tabular monospace face.
abstract final class Fmt {
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _shortDate = DateFormat('d MMM');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _weekday = DateFormat('EEE');

  /// `18 Nov 2026`
  static String date(DateTime d) => _date.format(d);

  /// `18 Nov`
  static String shortDate(DateTime d) => _shortDate.format(d);

  /// `14:05`
  static String time(DateTime d) => _time.format(d);

  /// `18 Nov 2026 · 14:05`
  static String dateTime(DateTime d) => '${date(d)} · ${time(d)}';

  /// `Today`, `Yesterday`, weekday within a week, otherwise a short date.
  static String relativeDay(DateTime d, {DateTime? now}) {
    final DateTime n = now ?? DateTime.now();
    final DateTime today = DateTime(n.year, n.month, n.day);
    final DateTime day = DateTime(d.year, d.month, d.day);
    final int diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return _weekday.format(d);
    return shortDate(d);
  }

  /// Compact duration: `42.3s`, `3m 07s`, `1h 02m`.
  static String duration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
    }
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }

  /// Split/interval seconds with 2 decimals: `1.42s`.
  static String split(Duration d) =>
      '${(d.inMilliseconds / 1000).toStringAsFixed(2)}s';

  /// Percentage from a 0–1 ratio: `87%`.
  static String percent(double ratio) => '${(ratio * 100).round()}%';
}
