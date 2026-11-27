import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/session.dart';

/// Background recording for 2-hour classes/meetings.
///
/// How it stays alive with the screen off / phone locked:
/// - An Android foreground service (microphone type) with a persistent
///   notification that has a Stop action. Android will not kill the app
///   while the service runs.
/// - A partial wake lock keeps the CPU awake while the screen is off.
/// - Audio is written in 10-minute chunk files, so a crash never loses the
///   whole recording.
/// - The user is asked once to exempt the app from battery optimisation,
///   so Doze cannot kill the service mid-meeting.
///
/// A fully powered-off phone cannot record — screen-off/locked is the
/// requirement, not power-off.
class RecorderService extends ChangeNotifier {
  RecorderService._();
  static final RecorderService instance = RecorderService._();

  static const _chunkMinutes = 10;
  static const _notificationChannelId = 'sessionvault_recording';

  final AudioRecorder _recorder = AudioRecorder();

  // Live transcription — the device speech service (same idea as the web
  // app's Web Speech API, bn-BD). This is NOT Whisper yet: Whisper
  // on-device transcription is the next step, after the models download.
  // If speech recognition is unavailable on a device, audio recording
  // still continues and the session saves with no transcript.
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _finalTranscript = '';
  String _interimTranscript = '';
  bool _transcriptAvailable = false;

  String get liveTranscript =>
      '${_finalTranscript.trim()} ${_interimTranscript.trim()}'.trim();
  bool get transcriptAvailable => _transcriptAvailable;

  bool _recording = false;
  bool get isRecording => _recording;

  int _seconds = 0;
  int get seconds => _seconds;

  String? _sessionId;
  String? get sessionId => _sessionId;

  final List<String> _chunkPaths = [];
  List<String> get chunkPaths => List.unmodifiable(_chunkPaths);

  Timer? _timer;
  Timer? _chunkTimer;
  DateTime? _startedAt;

  void Function()? onStopFromNotification;

  /// One-time foreground-service setup. Call from main() before runApp.
  static void initForegroundService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _notificationChannelId,
        channelName: 'Recording',
        channelDescription:
            'Keeps recording while the screen is off',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions:
          const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    FlutterForegroundTask.initCommunicationPort();
  }

  Future<String?> _ensurePermissions() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return 'Microphone permission is required.';
    // Notification permission (Android 13+): best effort, recording works
    // without it — the notification just will not show.
    await Permission.notification.request();
    // Battery optimisation exemption so Doze cannot kill the service.
    try {
      final ignoring =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!ignoring) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (_) {
      // Best effort only.
    }
    return null;
  }

  Future<Directory> _audioDir(String sessionId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'audio', sessionId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _chunkPath(Directory dir, int index) =>
      p.join(dir.path, 'part-${index.toString().padLeft(2, '0')}.wav');

  Future<void> _startChunk() async {
    final dir = await _audioDir(_sessionId!);
    final path = _chunkPath(dir, _chunkPaths.length + 1);
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
        echoCancel: false,
        noiseSuppress: true,
        autoGain: false,
      ),
      path: path,
    );
    _chunkPaths.add(path);
  }

  Future<void> _rotateChunk() async {
    if (!_recording) return;
    try {
      await _recorder.stop();
    } catch (_) {
      // If the chunk could not stop cleanly, keep the partial file and
      // start a fresh chunk anyway.
    }
    try {
      await _startChunk();
    } catch (_) {
      // Recording continues on the next rotation attempt.
    }
  }

  Future<void> _startTranscription() async {
    try {
      _finalTranscript = '';
      _interimTranscript = '';
      _transcriptAvailable = false;
      final available = await _speech.initialize(
        onStatus: (_) {},
        onError: (_) {},
      );
      if (!available) return;
      final locales = await _speech.locales();
      String? localeId;
      for (final wanted in ['bn_BD', 'bn_IN', 'bn']) {
        if (locales.any((l) => l.localeId == wanted)) {
          localeId = wanted;
          break;
        }
      }
      _transcriptAvailable = true;
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            final words = result.recognizedWords.trim();
            if (words.isNotEmpty) {
              _finalTranscript =
                  '${_finalTranscript.trim()} $words'.trim();
            }
            _interimTranscript = '';
          } else {
            _interimTranscript = result.recognizedWords;
          }
          notifyListeners();
        },
        // ignore: deprecated_member_use — 7.5.0 still uses these params;
        // SpeechListenOptions is only in the 7.6 beta.
        localeId: localeId,
        listenFor: const Duration(minutes: 60),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );
    } catch (_) {
      // Live text is best-effort — recording continues without it.
      _transcriptAvailable = false;
    }
  }

  Future<void> _stopTranscription() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  /// Start recording. Returns an error message, or null on success.
  Future<String?> start() async {
    if (_recording) return null;
    final permError = await _ensurePermissions();
    if (permError != null) return permError;
    final hasMic = await _recorder.hasPermission();
    if (!hasMic) return 'Microphone permission is required.';

    _sessionId = 'rec-${DateTime.now().millisecondsSinceEpoch}';
    _chunkPaths.clear();
    _seconds = 0;
    _startedAt = DateTime.now();

    try {
      await _startChunk();
    } catch (e) {
      return 'Could not start recording: $e';
    }

    // Live transcript runs alongside the audio recording.
    await _startTranscription();

    // Keep the process alive with the screen off.
    await WakelockPlus.enable();
    await FlutterForegroundTask.saveData(
        key: 'started_at', value: _startedAt!.millisecondsSinceEpoch);
    await FlutterForegroundTask.startService(
      serviceTypes: [ForegroundServiceTypes.microphone],
      notificationTitle: 'SessionVault recording',
      notificationText: 'Recording… 00:00',
      notificationButtons: const [
        NotificationButton(id: 'stop', text: 'Stop'),
      ],
      callback: _foregroundTaskEntryPoint,
    );

    _recording = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _seconds++;
      notifyListeners();
    });
    _chunkTimer = Timer.periodic(
      const Duration(minutes: _chunkMinutes),
      (_) => _rotateChunk(),
    );
    notifyListeners();
    return null;
  }

  /// Stop recording and build the new session. The timer is frozen FIRST,
  /// so the saved duration is exactly what the timer showed at Stop.
  Future<Session?> stop({
    required String typedTitle,
    required bool autoTitle,
  }) async {
    if (!_recording) return null;

    // Freeze the timer before anything else.
    _timer?.cancel();
    _timer = null;
    _chunkTimer?.cancel();
    _chunkTimer = null;
    final frozenSeconds = _seconds;
    _recording = false;

    await _stopTranscription();
    final transcript = liveTranscript;
    _finalTranscript = '';
    _interimTranscript = '';

    String? lastPath;
    try {
      lastPath = await _recorder.stop();
    } catch (_) {
      lastPath = null;
    }
    if (lastPath != null && !_chunkPaths.contains(lastPath)) {
      _chunkPaths.add(lastPath);
    }

    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    notifyListeners();

    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    final dateStr = '${now.year}-${pad(now.month)}-${pad(now.day)}';
    final timeStr = '${pad(now.hour)}:${pad(now.minute)}';
    final title = typedTitle.trim().isNotEmpty
        ? typedTitle.trim()
        : (autoTitle ? 'CIS313 — Auto-detected topic' : 'New class recording');
    final code =
        RegExp(r'[A-Za-z]{2,}\d{3}').firstMatch(title)?.group(0);
    final subject = code ?? 'Class';
    final durationMin = frozenSeconds < 60 ? 1 : (frozenSeconds / 60).round();

    return Session(
      id: _sessionId ?? 'rec-${now.millisecondsSinceEpoch}',
      title: title,
      subject: subject,
      category: 'Class',
      date: dateStr,
      time: timeStr,
      duration: fmtDuration(frozenSeconds),
      durationMin: durationMin,
      filename:
          '${dateStr}_${timeStr.replaceAll(':', '-')}_${subject.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}.md',
      language: 'Banglish',
      tokens: estimateTokens(durationMin),
      summary: transcript.isNotEmpty
          ? (transcript.length > 500
              ? '${transcript.substring(0, 500)}…'
              : transcript)
          : 'No speech was recognised during this recording.',
      examHints: const [],
      notes: transcript.isNotEmpty
          ? [
              NoteSection(
                heading: 'Live transcript — what was actually said',
                points: [transcript],
              ),
            ]
          : const [],
      actions: transcript.isNotEmpty
          ? const []
          : ['Re-read the live transcript and fill in any gaps from memory.'],
      audioPaths: List.unmodifiable(_chunkPaths),
    );
  }

  /// Summary from the real live transcript only — first 3 sentences.
  /// Never invents content. Full Qwen summarising (exam hints, structured
  /// notes, action items) is the next step, after Whisper runs on-device.
  Session simulateSummary(Session session) {
    final transcript = session.notes.isNotEmpty
        ? session.notes.first.points.join(' ')
        : '';
    if (transcript.isEmpty) {
      return session.copyWith(
        summary: 'No speech was recognised during this recording.',
        summaryReady: true,
      );
    }
    final sentences = transcript
        .split(RegExp(r'(?<=[।.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();
    return session.copyWith(
      summary: sentences.join(' '),
      summaryReady: true,
    );
  }
}

/// Background-isolate entry point for the foreground service.
@pragma('vm:entry-point')
void _foregroundTaskEntryPoint() {
  FlutterForegroundTask.setTaskHandler(_RecordingTaskHandler());
}

class _RecordingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep the notification showing the live elapsed time.
    FlutterForegroundTask.getData<int>(key: 'started_at').then((ms) {
      if (ms == null) return;
      final elapsed =
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
      final total = elapsed.inSeconds;
      final mm = (total ~/ 60).toString().padLeft(2, '0');
      final ss = (total % 60).toString().padLeft(2, '0');
      FlutterForegroundTask.updateService(
        notificationTitle: 'SessionVault recording',
        notificationText: 'Recording… $mm:$ss',
      );
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.sendDataToMain('stop');
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
