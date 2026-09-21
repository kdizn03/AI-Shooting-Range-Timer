import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/session.dart';
import 'package:shot_timer_ai/models/shot_event.dart';

void main() {
  group('Session', () {
    final tTime = DateTime(2023, 1, 1, 12, 0, 0);

    test('construction with defaults', () {
      final session = Session(id: 's1', startTime: tTime);
      expect(session.id, 's1');
      expect(session.startTime, tTime);
      expect(session.endTime, isNull);
      expect(session.shots, isEmpty);
      expect(session.status, SessionStatus.setup);
    });

    test('copyWith', () {
      final session = Session(id: 's1', startTime: tTime);
      final end = tTime.add(const Duration(minutes: 5));
      final updated = session.copyWith(
        endTime: end,
        status: SessionStatus.completed,
      );
      expect(updated.endTime, end);
      expect(updated.status, SessionStatus.completed);
      expect(updated.id, 's1');
    });

    test('toMap/fromMap round-trip', () {
      final shot = ShotEvent(
        shotNumber: 1,
        elapsedTime: const Duration(seconds: 1),
        confidence: 0.9,
        detectionTimestamp: tTime.add(const Duration(seconds: 1)),
      );
      final session = Session(
        id: 's1',
        startTime: tTime,
        endTime: tTime.add(const Duration(minutes: 1)),
        shots: [shot],
        status: SessionStatus.completed,
      );
      
      final map = session.toMap();
      final roundTrip = Session.fromMap(map);
      
      expect(roundTrip, session);
    });

    test('isActive / isFinished properties for setup', () {
      final session = Session(id: 's1', startTime: tTime, status: SessionStatus.setup);
      expect(session.isActive, isFalse);
      expect(session.isFinished, isFalse);
    });

    test('isActive / isFinished properties for active', () {
      final session = Session(id: 's1', startTime: tTime, status: SessionStatus.active);
      expect(session.isActive, isTrue);
      expect(session.isFinished, isFalse);
    });

    test('isActive / isFinished properties for completed', () {
      final session = Session(id: 's1', startTime: tTime, status: SessionStatus.completed);
      expect(session.isActive, isFalse);
      expect(session.isFinished, isTrue);
    });

    test('isActive / isFinished properties for cancelled', () {
      final session = Session(id: 's1', startTime: tTime, status: SessionStatus.cancelled);
      expect(session.isActive, isFalse);
      expect(session.isFinished, isTrue);
    });

    test('shotCount', () {
      final shot = ShotEvent(shotNumber: 1, elapsedTime: const Duration(seconds: 1), confidence: 0.9, detectionTimestamp: tTime);
      final session = Session(id: 's1', startTime: tTime, shots: [shot, shot]);
      expect(session.shotCount, 2);
    });

    test('addShot', () {
      final session = Session(id: 's1', startTime: tTime);
      final shot = ShotEvent(shotNumber: 1, elapsedTime: const Duration(seconds: 1), confidence: 0.9, detectionTimestamp: tTime);
      final updated = session.addShot(shot);
      expect(updated.shots.length, 1);
      expect(updated.shots.first, shot);
    });

    test('lastShot', () {
      final session = Session(id: 's1', startTime: tTime);
      expect(session.lastShot, isNull);
      
      final shot1 = ShotEvent(shotNumber: 1, elapsedTime: const Duration(seconds: 1), confidence: 0.9, detectionTimestamp: tTime);
      final shot2 = ShotEvent(shotNumber: 2, elapsedTime: const Duration(seconds: 2), confidence: 0.9, detectionTimestamp: tTime);
      
      final sessionWithShots = session.copyWith(shots: [shot1, shot2]);
      expect(sessionWithShots.lastShot, shot2);
    });
  });
}
