import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/services/timing/session_timer.dart';

void main() {
  group('SessionTimer', () {
    test('initial state (not running, zero elapsed)', () {
      final timer = SessionTimer();
      expect(timer.isRunning, isFalse);
      expect(timer.elapsed, Duration.zero);
    });

    test('start begins timing', () async {
      final timer = SessionTimer(tickIntervalMs: 10);
      timer.start();
      expect(timer.isRunning, isTrue);
      
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(timer.elapsed.inMilliseconds, greaterThan(0));
      
      timer.dispose();
    });

    test('stop preserves elapsed', () async {
      final timer = SessionTimer(tickIntervalMs: 10);
      timer.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      timer.stop();
      
      expect(timer.isRunning, isFalse);
      final elapsed = timer.elapsed;
      expect(elapsed.inMilliseconds, greaterThan(0));
      
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(timer.elapsed, elapsed); // Should not have changed
      
      timer.dispose();
    });

    test('reset clears elapsed', () async {
      final timer = SessionTimer(tickIntervalMs: 10);
      timer.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      timer.stop();
      
      timer.reset();
      expect(timer.elapsed, Duration.zero);
      expect(timer.isRunning, isFalse);
      
      timer.dispose();
    });

    test('isRunning state', () {
      final timer = SessionTimer();
      expect(timer.isRunning, isFalse);
      timer.start();
      expect(timer.isRunning, isTrue);
      timer.stop();
      expect(timer.isRunning, isFalse);
      timer.dispose();
    });

    test('tickStream emits values', () async {
      final timer = SessionTimer(tickIntervalMs: 10);
      
      final List<Duration> emits = [];
      final subscription = timer.tickStream.listen(emits.add);
      
      timer.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      timer.stop();
      
      expect(emits, isNotEmpty);
      
      await subscription.cancel();
      timer.dispose();
    });
  });
}
