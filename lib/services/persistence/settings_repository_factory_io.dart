import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/app_settings.dart';
import 'settings_repository.dart';

/// Returns a JSON-file-backed settings store for native platforms.
SettingsRepository getSettingsRepository() => FileSettingsRepository();

/// Stores [AppSettings] as `settings.json` in the app documents directory,
/// mirroring how sessions are persisted.
class FileSettingsRepository implements SettingsRepository {
  /// Creates a [FileSettingsRepository]. [file] overrides the location.
  FileSettingsRepository({File? file}) : _file = file;

  File? _file;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final Directory dir = await getApplicationDocumentsDirectory();
    return _file = File('${dir.path}/settings.json');
  }

  @override
  Future<AppSettings> load() async {
    try {
      final File file = await _getFile();
      if (!file.existsSync()) return const AppSettings();
      final String content = await file.readAsString();
      if (content.trim().isEmpty) return const AppSettings();
      return AppSettings.fromMap(jsonDecode(content) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Settings load failed, using defaults: $e');
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    final File file = await _getFile();
    await file.writeAsString(jsonEncode(settings.toMap()));
  }
}
