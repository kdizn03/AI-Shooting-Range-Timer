import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/persistence/session_repository.dart';
import '../services/persistence/session_repository_factory.dart';

class InMemorySessionRepository implements SessionRepository {
  final List<Session> _sessions = [];

  @override
  Future<void> saveSession(Session session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.add(session);
    }
  }

  @override
  Future<Session?> getSession(String id) async {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Session>> getAllSessions() async {
    return List.from(_sessions);
  }

  @override
  Future<bool> deleteSession(String id) async {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index >= 0) {
      _sessions.removeAt(index);
      return true;
    }
    return false;
  }

  @override
  Future<void> deleteAllSessions() async {
    _sessions.clear();
  }

  @override
  Future<int> getSessionCount() async {
    return _sessions.length;
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return createSessionRepository();
});

final sessionHistoryProvider = FutureProvider<List<Session>>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getAllSessions();
});
