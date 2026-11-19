import '../../models/app_settings.dart';
import 'settings_repository_factory_web.dart'
    if (dart.library.io) 'settings_repository_factory_io.dart';

/// Persistence contract for [AppSettings].
abstract class SettingsRepository {
  /// Loads stored settings, or defaults if none exist or data is corrupt.
  Future<AppSettings> load();

  /// Persists [settings].
  Future<void> save(AppSettings settings);
}

/// In-memory implementation (web, and tests).
class InMemorySettingsRepository implements SettingsRepository {
  /// Creates an in-memory repository seeded with [initial].
  InMemorySettingsRepository([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}

/// Creates the platform-appropriate [SettingsRepository]:
/// a JSON file on native platforms, memory on web.
SettingsRepository createSettingsRepository() => getSettingsRepository();
