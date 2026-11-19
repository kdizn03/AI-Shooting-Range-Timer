import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../services/persistence/settings_repository.dart';

/// Settings storage backend. Override in tests.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => createSettingsRepository(),
);

/// Holds the current [AppSettings], loading persisted values on creation
/// and writing every change back to storage.
class SettingsNotifier extends StateNotifier<AppSettings> {
  /// Creates a notifier backed by [_repository].
  SettingsNotifier(this._repository) : super(const AppSettings()) {
    _ready = _load();
  }

  final SettingsRepository _repository;
  late final Future<void> _ready;

  /// Completes once persisted settings have been loaded.
  Future<void> get ready => _ready;

  Future<void> _load() async {
    final AppSettings loaded = await _repository.load();
    if (mounted) state = loaded;
  }

  /// Applies [update] to the current settings and persists the result.
  Future<void> update(AppSettings Function(AppSettings) update) async {
    state = update(state);
    try {
      await _repository.save(state);
    } catch (e) {
      debugPrint('Failed to save settings: $e');
      rethrow;
    }
  }

  /// Restores defaults and persists them.
  Future<void> reset() => update((_) => const AppSettings());
}

/// Current application settings.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsRepositoryProvider));
});
