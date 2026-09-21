import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/core/utils/timestamp_utils.dart';

void main() {
  group('TimestampUtils', () {
    test('formatElapsed with zero duration', () {
      expect(
        TimestampUtils.formatElapsed(Duration.zero),
        '00:00.00',
      );
    });

    test('formatElapsed with minutes and seconds', () {
      expect(
        TimestampUtils.formatElapsed(
          const Duration(minutes: 1, seconds: 5, milliseconds: 500),
        ),
        '01:05.50',
      );
    });

    test('formatElapsed with large duration', () {
      expect(
        TimestampUtils.formatElapsed(
          const Duration(minutes: 12, seconds: 34, milliseconds: 560),
        ),
        '12:34.56',
      );
    });

    test('formatElapsed wraps over 60 minutes', () {
      expect(
        TimestampUtils.formatElapsed(const Duration(hours: 1)),
        '60:00.00',
      );
    });

    test('formatSeconds precision', () {
      expect(
        TimestampUtils.formatSeconds(const Duration(milliseconds: 1560)),
        '1.56',
      );
      expect(
        TimestampUtils.formatSeconds(const Duration(seconds: 2)),
        '2.00',
      );
      expect(
        TimestampUtils.formatSeconds(Duration.zero),
        '0.00',
      );
    });

    test('formatInterval includes plus and suffix', () {
      expect(
        TimestampUtils.formatInterval(const Duration(milliseconds: 250)),
        '+0.25s',
      );
      expect(
        TimestampUtils.formatInterval(
          const Duration(seconds: 1, milliseconds: 50),
        ),
        '+1.05s',
      );
      expect(
        TimestampUtils.formatInterval(Duration.zero),
        '+0.00s',
      );
    });

    test('interval computation positive', () {
      const d1 = Duration(seconds: 1);
      const d2 = Duration(seconds: 3);
      final result = TimestampUtils.interval(d1, d2);
      expect(result, const Duration(seconds: 2));
    });

    test('interval returns null for negative durations', () {
      const neg = Duration(seconds: -1);
      const pos = Duration(seconds: 1);
      expect(TimestampUtils.interval(neg, pos), isNull);
      expect(TimestampUtils.interval(pos, neg), isNull);
    });
  });
}
