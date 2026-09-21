import '../../providers/session_history_provider.dart';
import 'session_repository.dart';

/// Returns InMemorySessionRepository for web environments.
SessionRepository getSessionRepository() => InMemorySessionRepository();

