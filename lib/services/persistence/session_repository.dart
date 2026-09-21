import '../../models/session.dart';

/// Abstract repository interface for session persistence.
///
/// Defines the contract for storing and retrieving shooting sessions.
/// Implementations may use SQLite (Drift), files, or any other
/// persistence mechanism.
abstract class SessionRepository {
  /// Saves a session to persistent storage.
  ///
  /// If a session with the same [Session.id] already exists,
  /// it is updated. Otherwise, a new record is created.
  Future<void> saveSession(Session session);

  /// Retrieves a session by its unique [id].
  ///
  /// Returns `null` if no session with that ID exists.
  Future<Session?> getSession(String id);

  /// Retrieves all saved sessions, ordered by start time (newest first).
  Future<List<Session>> getAllSessions();

  /// Deletes a session by its unique [id].
  ///
  /// Returns `true` if a session was deleted, `false` if not found.
  Future<bool> deleteSession(String id);

  /// Deletes all saved sessions.
  Future<void> deleteAllSessions();

  /// Returns the total number of saved sessions.
  Future<int> getSessionCount();
}

