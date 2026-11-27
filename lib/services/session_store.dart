import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/session.dart';

/// Local-first session storage.
///
/// Sessions live as JSON (index) + one .md file each under the app documents
/// directory. Notes and audio NEVER leave the phone — no Supabase, no upload.
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  List<Session> _sessions = [];
  bool _loaded = false;
  Directory? _sessionsDir;

  List<Session> get sessions => List.unmodifiable(_sessions);

  Future<Directory> get _dir async {
    if (_sessionsDir != null) return _sessionsDir!;
    final docs = await getApplicationDocumentsDirectory();
    _sessionsDir = Directory(p.join(docs.path, 'sessions'));
    if (!await _sessionsDir!.exists()) {
      await _sessionsDir!.create(recursive: true);
    }
    return _sessionsDir!;
  }

  File _indexFile(Directory dir) => File(p.join(dir.path, 'index.json'));

  Future<void> load() async {
    if (_loaded) return;
    final dir = await _dir;
    final index = _indexFile(dir);
    if (await index.exists()) {
      try {
        final raw = jsonDecode(await index.readAsString()) as List;
        _sessions = raw
            .map((e) => Session.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _sessions = [];
      }
    }
    if (_sessions.isEmpty) {
      // First launch: seed the four sample sessions from the web demo.
      _sessions = sampleSessions();
      await _save();
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final dir = await _dir;
    final index = _indexFile(dir);
    await index.writeAsString(
        jsonEncode(_sessions.map((s) => s.toJson()).toList()));
    for (final s in _sessions) {
      final md = File(p.join(dir.path, s.filename));
      await md.writeAsString(s.buildRaw());
    }
  }

  Future<void> add(Session session) async {
    _sessions.insert(0, session);
    await _save();
  }

  Future<void> update(Session session) async {
    final i = _sessions.indexWhere((s) => s.id == session.id);
    if (i >= 0) {
      _sessions[i] = session;
      await _save();
    }
  }

  Future<void> delete(String id) async {
    final i = _sessions.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final removed = _sessions.removeAt(i);
    final dir = await _dir;
    final md = File(p.join(dir.path, removed.filename));
    if (await md.exists()) await md.delete();
    for (final audio in removed.audioPaths) {
      final f = File(audio);
      if (await f.exists()) await f.delete();
    }
    await _save();
  }

  Session? byId(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The .md file for a session, if it exists on disk.
  Future<File?> mdFile(Session session) async {
    final dir = await _dir;
    final f = File(p.join(dir.path, session.filename));
    return await f.exists() ? f : null;
  }

  /// "N files · X KB" line for the Sessions screen, computed from the real
  /// .md files on disk.
  Future<String> savedLocallyLine() async {
    final dir = await _dir;
    var totalBytes = 0;
    var count = 0;
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.md')) {
        count++;
        totalBytes += await e.length();
      }
    }
    final kb = (totalBytes / 1024).round();
    return '$count files · $kb KB';
  }
}
