import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Downloads the on-device models on first launch.
///
/// URLs come from the bundled `assets/models.json`, which is a copy of the
/// single source of truth at `workspace/ai-class-memory/models.json`.
/// (The APK cannot read the workspace file at runtime, so the file is
/// bundled as an asset; update the asset when the shared config changes.)
///
/// This service knows file names and sizes internally, but the UI it feeds
/// must never show them — only "AI Setup", one overall progress bar with a
/// live %, a short status, Download models, and Continue when done.
class DownloadProgress {
  const DownloadProgress({
    required this.fraction,
    required this.status,
    required this.done,
  });
  final double fraction; // 0.0 .. 1.0 overall
  final String status; // generic status text, no model names/sizes
  final bool done;
}

class _RemoteFile {
  _RemoteFile({required this.url, required this.target, required this.size});
  final String url;
  final File target;
  final int size; // expected total bytes (0 = unknown)
}

class ModelDownloadService {
  ModelDownloadService._();
  static final ModelDownloadService instance = ModelDownloadService._();

  static const _prefsReadyKey = 'sessionvault_models_ready';
  static const _whisperRepo = 'shamim1122/whisper-small-bangla-onnx';

  final _client = http.Client();

  Future<bool> get isReady async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsReadyKey) != true) return false;
    // Also verify the files are actually on disk.
    final files = await _plannedFiles();
    for (final f in files) {
      if (!await f.target.exists()) return false;
      if (f.size > 0 && await f.target.length() < f.size) return false;
    }
    return true;
  }

  Future<void> _markReady() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsReadyKey, true);
  }

  Future<Directory> get _modelsDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'models'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The full download plan, built from the bundled config + the live
  /// HuggingFace file listing for the multi-file repo.
  Future<List<_RemoteFile>> _plannedFiles() async {
    final raw = await rootBundle.loadString('assets/models.json');
    final cfg = jsonDecode(raw) as Map<String, dynamic>;
    final models = cfg['models'] as List;
    final modelsDir = await _modelsDir;

    Map<String, dynamic> byRole(String role) => models.firstWhere(
          (m) => (m as Map<String, dynamic>)['role'] == role,
        ) as Map<String, dynamic>;

    final qwen = byRole('notes_llm');

    final qwenDir = Directory(p.join(modelsDir.path, 'qwen'));
    if (!await qwenDir.exists()) await qwenDir.create(recursive: true);
    final qwenFile = File(p.join(
        qwenDir.path, (qwen['file'] as String).split('/').last));
    final qwenSize =
        ((qwen['size_gb'] as num) * 1000000000).round();

    final whisperDir = Directory(p.join(modelsDir.path, 'whisper'));
    if (!await whisperDir.exists()) await whisperDir.create(recursive: true);

    // Multi-file repo: list every file via the HuggingFace API.
    final treeUri = Uri.parse(
        'https://huggingface.co/api/models/$_whisperRepo/tree/main');
    final treeRes = await _client.get(treeUri);
    if (treeRes.statusCode != 200) {
      throw HttpException(
          'Could not list files (HTTP ${treeRes.statusCode})');
    }
    final entries = jsonDecode(treeRes.body) as List;
    final files = <_RemoteFile>[
      _RemoteFile(
          url: qwen['direct_url'] as String,
          target: qwenFile,
          size: qwenSize),
    ];
    for (final e in entries) {
      final entry = e as Map<String, dynamic>;
      if (entry['type'] != 'file') continue;
      final name = entry['rfilename'] as String;
      final size = (entry['size'] as num?)?.toInt() ?? 0;
      files.add(_RemoteFile(
        url:
            'https://huggingface.co/$_whisperRepo/resolve/main/$name',
        target: File(p.join(whisperDir.path, name)),
        size: size,
      ));
    }
    return files;
  }

  /// Download everything, resuming partial files with HTTP Range.
  /// Yields overall progress; completes when all files are done.
  Stream<DownloadProgress> downloadAll() async* {
    yield const DownloadProgress(
        fraction: 0, status: 'Preparing…', done: false);
    final files = await _plannedFiles();

    var totalBytes = files.fold<int>(0, (s, f) => s + f.size);
    var doneBytes = 0;
    for (final f in files) {
      if (await f.target.exists()) {
        final have = await f.target.length();
        doneBytes += have > f.size && f.size > 0 ? f.size : have;
      }
    }
    if (totalBytes <= 0) totalBytes = doneBytes > 0 ? doneBytes : 1;

    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    for (final file in files) {
      var existing = 0;
      if (await file.target.exists()) {
        existing = await file.target.length();
      }
      if (file.size > 0 && existing >= file.size) continue;

      final request = http.Request('GET', Uri.parse(file.url));
      if (existing > 0) {
        request.headers['Range'] = 'bytes=$existing-';
      }
      final response = await _client.send(request);
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('Download failed (HTTP ${response.statusCode})');
      }
      // Learn the real total size from the response when we can.
      if (response.statusCode == 206) {
        final range = response.headers['content-range'];
        final totalMatch =
            range == null ? null : RegExp(r'/(\d+)\s*$').firstMatch(range);
        if (totalMatch != null && file.size > 0) {
          totalBytes =
              totalBytes - file.size + int.parse(totalMatch.group(1)!);
        }
      } else if (existing > 0) {
        // Server ignored Range: restart this file from scratch.
        final had = await file.target.length();
        doneBytes -= had;
        existing = 0;
      }
      final sink = file.target.openWrite(mode: FileMode.writeOnlyAppend);
      await for (final chunk in response.stream) {
        sink.add(chunk);
        doneBytes += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastEmit).inMilliseconds >= 200) {
          lastEmit = now;
          yield DownloadProgress(
            fraction: (doneBytes / totalBytes).clamp(0.0, 1.0),
            status: 'Downloading…',
            done: false,
          );
        }
      }
      await sink.close();
    }
    await _markReady();
    yield const DownloadProgress(
        fraction: 1, status: 'Download complete', done: true);
  }
}
