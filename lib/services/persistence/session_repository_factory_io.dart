import 'local_session_repository.dart';
import 'session_repository.dart';

/// Returns LocalSessionRepository for native platforms (file system available).
SessionRepository getSessionRepository() => LocalSessionRepository();

