import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../../models/session.dart';
import 'session_repository.dart';

class LocalSessionRepository implements SessionRepository {
  LocalSessionRepository({File? file}) : _file = file;

  File? _file;
  List<Session>? _cache;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final directory = await getApplicationDocumentsDirectory();
    _file = File('${directory.path}/sessions.json');
    return _file!;
  }

  Future<void> _load() async {
    if (_cache != null) return;
    try {
      final file = await _getFile();
      if (!file.existsSync()) {
        _cache = [];
        return;
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        _cache = [];
        return;
      }
      final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
      _cache = jsonList.map((e) => Session.fromMap(e as Map<String, dynamic>)).toList();
      _sort();
    } catch (e) {
      // Handle corrupt data gracefully by resetting the cache
      _cache = [];
    }
  }

  Future<void> _save() async {
    if (_cache == null) return;
    _sort();
    final file = await _getFile();
    final jsonList = _cache!.map((e) => e.toMap()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  void _sort() {
    _cache?.sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  @override
  Future<void> saveSession(Session session) async {
    await _load();
    final index = _cache!.indexWhere((e) => e.id == session.id);
    if (index >= 0) {
      _cache![index] = session;
    } else {
      _cache!.add(session);
    }
    await _save();
  }

  @override
  Future<Session?> getSession(String id) async {
    await _load();
    for (final Session session in _cache!) {
      if (session.id == id) return session;
    }
    return null;
  }

  @override
  Future<List<Session>> getAllSessions() async {
    await _load();
    return List.unmodifiable(_cache!);
  }

  @override
  Future<bool> deleteSession(String id) async {
    await _load();
    final index = _cache!.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _cache!.removeAt(index);
      await _save();
      return true;
    }
    return false;
  }

  @override
  Future<void> deleteAllSessions() async {
    _cache = [];
    await _save();
  }

  @override
  Future<int> getSessionCount() async {
    await _load();
    return _cache!.length;
  }
}
