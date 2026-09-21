import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/shot_event.dart';

void main() {
  group('ShotEvent', () {
    final tTime = DateTime(2023, 1, 1, 12, 0, 0);

    test('construction with valid parameters', () {
      final shot = ShotEvent(
        shotNumber: 1,
        elapsedTime: const Duration(seconds: 1),
        confidence: 0.9,
        detectionTimestamp: tTime,
      );
      expect(shot.shotNumber, 1);
      expect(shot.elapsedTime, const Duration(seconds: 1));
      expect(shot.confidence, 0.9);
      expect(shot.detectionTimestamp, tTime);
    });

    test('copyWith creates proper copy', () {
      final shot = ShotEvent(
        shotNumber: 1,
        elapsedTime: const Duration(seconds: 1),
        confidence: 0.9,
        detectionTimestamp: tTime,
      );
      final updated = shot.copyWith(confidence: 0.95);
      expect(updated.shotNumber, 1);
      expect(updated.elapsedTime, const Duration(seconds: 1));
      expect(updated.confidence, 0.95);
      expect(updated.detectionTimestamp, tTime);
    });

    test('toMap serialization', () {
      final shot = ShotEvent(
        shotNumber: 1,
        elapsedTime: const Duration(milliseconds: 1500),
        confidence: 0.9,
        detectionTimestamp: tTime,
      );
      final map = shot.toMap();
      expect(map['shotNumber'], 1);
      expect(map['elapsedTimeMs'], 1500);
      expect(map['confidence'], 0.9);
      expect(map['detectionTimestamp'], tTime.toIso8601String());
    });

    test('fromMap deserialization', () {
      final map = {
        'shotNumber': 2,
        'elapsedTimeMs': 2000,
        'confidence': 0.99,
        'detectionTimestamp': tTime.toIso8601String(),
      };
      final shot = ShotEvent.fromMap(map);
      expect(shot.shotNumber, 2);
      expect(shot.elapsedTime, const Duration(milliseconds: 2000));
      expect(shot.confidence, 0.99);
      expect(shot.detectionTimestamp, tTime);
    });

    test('toMap/fromMap round-trip', () {
      final shot = ShotEvent(
        shotNumber: 3,
        elapsedTime: const Duration(milliseconds: 3333),
        confidence: 0.85,
        detectionTimestamp: tTime,
      );
      final roundTrip = ShotEvent.fromMap(shot.toMap());
      expect(roundTrip, shot);
    });

    test('intervalFrom calculation', () {
      final shot1 = ShotEvent(
        shotNumber: 1,
        elapsedTime: const Duration(seconds: 1),
        confidence: 0.9,
        detectionTimestamp: tTime,
      );
      final shot2 = ShotEvent(
        shotNumber: 2,
        elapsedTime: const Duration(seconds: 3),
        confidence: 0.9,
        detectionTimestamp: tTime.add(const Duration(seconds: 2)),
      );
      expect(shot2.intervalFrom(shot1), const Duration(seconds: 2));
    });

    test('intervalFrom returns null for null previous', () {
      final shot = ShotEvent(
        shotNumber: 1,
        elapsedTime: const Duration(seconds: 1),
        confidence: 0.9,
        detectionTimestamp: tTime,
      );
      expect(shot.intervalFrom(null), isNull);
    });

    test('Equatable equality', () {
      final shot1 = ShotEvent(
        shotNumber: 1,
        elapsedTime: const Duration(seconds: 1),
        confidence: 0.9,
        detectionTimestamp: tTime,
      );
      final shot2 = ShotEvent(
        shotNumber: 1,
        elapsedTime: const Duration(seconds: 1),
        confidence: 0.9,
        detectionTimestamp: tTime,
      );
      final shot3 = ShotEvent(
        shotNumber: 2,
        elapsedTime: const Duration(seconds: 1),
        confidence: 0.9,
        detectionTimestamp: tTime,
      );
      expect(shot1, shot2);
      expect(shot1, isNot(shot3));
    });

    test('toString representation (from Equatable)', () {
      final shot = ShotEvent(
        shotNumber: 1,
        elapsedTime: const Duration(seconds: 1),
        confidence: 0.9,
        detectionTimestamp: tTime,
      );
      expect(shot.toString(), contains('ShotEvent'));
    });
  });
}
