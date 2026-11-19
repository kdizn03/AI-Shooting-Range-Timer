import 'settings_repository.dart';

/// Returns an in-memory settings store for web builds.
SettingsRepository getSettingsRepository() => InMemorySettingsRepository();
