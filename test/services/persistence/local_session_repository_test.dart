import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/session.dart';
import 'package:shot_timer_ai/services/persistence/local_session_repository.dart';

void main() {
  group('LocalSessionRepository', () {
    late LocalSessionRepository repo;
    late File tempFile;

    setUp(() async {
      final tempDir = Directory.systemTemp;
      tempFile = File('${tempDir.path}/test_sessions_${DateTime.now().millisecondsSinceEpoch}.json');
      repo = LocalSessionRepository(file: tempFile);
    });

    tearDown(() async {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    });

    final tTime = DateTime(2023, 1, 1, 12, 0, 0);
    final session1 = Session(id: 's1', startTime: tTime, status: SessionStatus.setup);
    final session2 = Session(id: 's2', startTime: tTime.add(const Duration(minutes: 5)), status: SessionStatus.completed);

    test('saveSession and retrieve', () async {
      await repo.saveSession(session1);
      final retrieved = await repo.getSession('s1');
      expect(retrieved, session1);
    });

    test('getAllSessions returns in order (descending startTime)', () async {
      await repo.saveSession(session1);
      await repo.saveSession(session2); // session2 is later, should be first
      
      final sessions = await repo.getAllSessions();
      expect(sessions.length, 2);
      expect(sessions.first.id, 's2'); // sorted by descending startTime
      expect(sessions.last.id, 's1');
    });

    test('deleteSession', () async {
      await repo.saveSession(session1);
      var count = await repo.getSessionCount();
      expect(count, 1);
      
      final result = await repo.deleteSession('s1');
      expect(result, isTrue);
      
      count = await repo.getSessionCount();
      expect(count, 0);
    });

    test('deleteAllSessions', () async {
      await repo.saveSession(session1);
      await repo.saveSession(session2);
      
      await repo.deleteAllSessions();
      
      final count = await repo.getSessionCount();
      expect(count, 0);
    });

    test('getSessionCount', () async {
      expect(await repo.getSessionCount(), 0);
      await repo.saveSession(session1);
      expect(await repo.getSessionCount(), 1);
    });

    test('getSession returns null for missing ID', () async {
      final retrieved = await repo.getSession('missing_id');
      expect(retrieved, isNull);
    });

    test('update existing session', () async {
      await repo.saveSession(session1);
      final updatedSession = session1.copyWith(status: SessionStatus.active);
      await repo.saveSession(updatedSession);
      
      final sessions = await repo.getAllSessions();
      expect(sessions.length, 1);
      expect(sessions.first.status, SessionStatus.active);
    });
  });
}
