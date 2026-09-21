/// Utilities for formatting timestamps and durations in Shot Timer AI.
library;

/// Provides formatting methods for [Duration] and elapsed-time display.
abstract final class TimestampUtils {
  /// Formats a [Duration] as `MM:SS.cc` (minutes, seconds, centiseconds).
  ///
  /// Example: `Duration(seconds: 72, milliseconds: 350)` → `"01:12.35"`.
  static String formatElapsed(Duration duration) {
    final int totalMs = duration.inMilliseconds;
    final int minutes = totalMs ~/ 60000;
    final int seconds = (totalMs % 60000) ~/ 1000;
    final int centiseconds = (totalMs % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}';
  }

  /// Formats a [Duration] as seconds with 2 decimal places.
  ///
  /// Example: `Duration(milliseconds: 1423)` → `"1.42"`.
  static String formatSeconds(Duration duration) {
    final double seconds = duration.inMilliseconds / 1000.0;
    return seconds.toStringAsFixed(2);
  }

  /// Formats a [Duration] as a short interval string.
  ///
  /// Example: `Duration(milliseconds: 1423)` → `"+1.42s"`.
  static String formatInterval(Duration duration) {
    return '+${formatSeconds(duration)}s';
  }

  /// Computes the interval between two [Duration] values.
  ///
  /// Returns `null` if either duration is negative.
  static Duration? interval(Duration from, Duration to) {
    if (from.isNegative || to.isNegative) return null;
    return to - from;
  }
}

