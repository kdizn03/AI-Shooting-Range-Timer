import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/session.dart';
import 'package:shot_timer_ai/models/session_statistics.dart';
import 'package:shot_timer_ai/models/shot_event.dart';

void main() {
  group('SessionStatistics', () {
    final tTime = DateTime(2023, 1, 1, 12, 0, 0);

    test('with 0 shots', () {
      final session = Session(id: 's1', startTime: tTime, endTime: tTime.add(const Duration(minutes: 1)));
      final stats = SessionStatistics.fromSession(session);
      
      expect(stats.totalShots, 0);
      expect(stats.hasShots, isFalse);
      expect(stats.hasIntervals, isFalse);
      expect(stats.intervals, isEmpty);
      expect(stats.firstShotTime, isNull);
      expect(stats.averageInterval, isNull);
      expect(stats.fastestInterval, isNull);
      expect(stats.slowestInterval, isNull);
    });

    test('with 1 shot (no intervals)', () {
      final shot = ShotEvent(shotNumber: 1, elapsedTime: const Duration(seconds: 2), confidence: 0.9, detectionTimestamp: tTime);
      final session = Session(id: 's1', startTime: tTime, shots: [shot]);
      final stats = SessionStatistics.fromSession(session);
      
      expect(stats.totalShots, 1);
      expect(stats.hasShots, isTrue);
      expect(stats.hasIntervals, isFalse);
      expect(stats.firstShotTime, const Duration(seconds: 2));
      expect(stats.averageInterval, isNull);
    });

    test('with 2 shots (1 interval)', () {
      final shot1 = ShotEvent(shotNumber: 1, elapsedTime: const Duration(seconds: 2), confidence: 0.9, detectionTimestamp: tTime);
      final shot2 = ShotEvent(shotNumber: 2, elapsedTime: const Duration(seconds: 3), confidence: 0.9, detectionTimestamp: tTime);
      final session = Session(id: 's1', startTime: tTime, shots: [shot1, shot2]);
      final stats = SessionStatistics.fromSession(session);
      
      expect(stats.totalShots, 2);
      expect(stats.hasIntervals, isTrue);
      expect(stats.intervals, [const Duration(seconds: 1)]);
      expect(stats.averageInterval, const Duration(seconds: 1));
      expect(stats.fastestInterval, const Duration(seconds: 1));
      expect(stats.slowestInterval, const Duration(seconds: 1));
    });

    test('with multiple shots (average, fastest, slowest)', () {
      final s1 = ShotEvent(shotNumber: 1, elapsedTime: const Duration(seconds: 2), confidence: 0.9, detectionTimestamp: tTime);
      final s2 = ShotEvent(shotNumber: 2, elapsedTime: const Duration(seconds: 3), confidence: 0.9, detectionTimestamp: tTime); // interval 1
      final s3 = ShotEvent(shotNumber: 3, elapsedTime: const Duration(seconds: 5), confidence: 0.9, detectionTimestamp: tTime); // interval 2
      final s4 = ShotEvent(shotNumber: 4, elapsedTime: const Duration(seconds: 8), confidence: 0.9, detectionTimestamp: tTime); // interval 3
      final session = Session(id: 's1', startTime: tTime, shots: [s1, s2, s3, s4]);
      
      final stats = SessionStatistics.fromSession(session);
      
      expect(stats.totalShots, 4);
      expect(stats.intervals.length, 3);
      expect(stats.fastestInterval, const Duration(seconds: 1));
      expect(stats.slowestInterval, const Duration(seconds: 3));
      expect(stats.averageInterval, const Duration(seconds: 2)); // (1+2+3)/3 = 2
    });

    test('firstShotTime', () {
      final s1 = ShotEvent(shotNumber: 1, elapsedTime: const Duration(milliseconds: 1500), confidence: 0.9, detectionTimestamp: tTime);
      final session = Session(id: 's1', startTime: tTime, shots: [s1]);
      final stats = SessionStatistics.fromSession(session);
      
      expect(stats.firstShotTime, const Duration(milliseconds: 1500));
    });

    test('hasShots / hasIntervals property validation', () {
      const stats = SessionStatistics(
        totalShots: 5, 
        sessionDuration: Duration(seconds: 10), 
        intervals: [Duration(seconds: 1)]
      );
      expect(stats.hasShots, isTrue);
      expect(stats.hasIntervals, isTrue);
    });

    test('verify interval math is correct with floating point ms', () {
      final s1 = ShotEvent(shotNumber: 1, elapsedTime: const Duration(milliseconds: 1000), confidence: 0.9, detectionTimestamp: tTime);
      final s2 = ShotEvent(shotNumber: 2, elapsedTime: const Duration(milliseconds: 1250), confidence: 0.9, detectionTimestamp: tTime);
      final session = Session(id: 's1', startTime: tTime, shots: [s1, s2]);
      
      final stats = SessionStatistics.fromSession(session);
      expect(stats.intervals, [const Duration(milliseconds: 250)]);
    });
    
    test('equatable test', () {
       const stats1 = SessionStatistics(
        totalShots: 0, 
        sessionDuration: Duration(seconds: 10), 
        intervals: []
      );
       const stats2 = SessionStatistics(
        totalShots: 0, 
        sessionDuration: Duration(seconds: 10), 
        intervals: []
      );
      expect(stats1, stats2);
    });
  });
}
