import 'session_repository.dart';
import 'session_repository_factory_web.dart'
    if (dart.library.io) 'session_repository_factory_io.dart';

/// Creates the appropriate [SessionRepository] depending on platform capabilities:
/// - Native: [LocalSessionRepository] (backed by file system)
/// - Web: [InMemorySessionRepository] (backed by memory)
SessionRepository createSessionRepository() => getSessionRepository();

