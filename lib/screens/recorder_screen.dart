import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/session.dart';
import '../services/recorder_service.dart';
import '../services/session_store.dart';

/// Recorder tab: title field, auto title, Start/Stop, and the post-record
/// actions. Stop IMMEDIATELY saves a real session — the Sessions count goes
/// up at once and Open note / summary / Download act on the new session.
class RecorderScreen extends StatefulWidget {
  const RecorderScreen({
    super.key,
    required this.lastSavedId,
    required this.onSessionSaved,
    required this.onOpenSession,
    required this.onSavedChanged,
  });

  final String? lastSavedId;
  final void Function(Session) onSessionSaved;
  final void Function(String sessionId) onOpenSession;
  final VoidCallback onSavedChanged;

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  final _title = TextEditingController();
  bool _autoTitle = true;
  bool _busy = false;
  bool _noteReady = false;
  bool _summaryOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    RecorderService.instance.onStopFromNotification = _stop;
    RecorderService.instance.addListener(_onRecorderChanged);
  }

  @override
  void dispose() {
    RecorderService.instance.removeListener(_onRecorderChanged);
    _title.dispose();
    super.dispose();
  }

  void _onRecorderChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await RecorderService.instance.start();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
    }
  }

  Future<void> _stop() async {
    if (!RecorderService.instance.isRecording) return;
    setState(() => _busy = true);
    final session = await RecorderService.instance.stop(
      typedTitle: _title.text,
      autoTitle: _autoTitle,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (session == null) return;
    await SessionStore.instance.add(session);
    widget.onSessionSaved(session);
    setState(() {
      _noteReady = true;
      _summaryOpen = false;
    });
  }

  Future<void> _simulateSummary() async {
    final id = widget.lastSavedId;
    if (id == null) return;
    final session = SessionStore.instance.byId(id);
    if (session == null) return;
    final updated = RecorderService.instance.simulateSummary(session);
    await SessionStore.instance.update(updated);
    widget.onSavedChanged();
    if (mounted) setState(() => _summaryOpen = true);
  }

  Future<void> _downloadMd() async {
    final id = widget.lastSavedId;
    if (id == null) return;
    final session = SessionStore.instance.byId(id);
    if (session == null) return;
    final file = await SessionStore.instance.mdFile(session);
    if (file == null) return;
    await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: session.filename));
  }

  @override
  Widget build(BuildContext context) {
    final service = RecorderService.instance;
    final recording = service.isRecording;
    final seconds = service.seconds;
    final last = widget.lastSavedId == null
        ? null
        : SessionStore.instance.byId(widget.lastSavedId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Recorder', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          const Text(
            'Record a class or a meeting. When you stop, SessionVault saves a clean Markdown note on this device.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Session title (optional)',
              hintText: 'e.g. CIS313 — A* Search',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _autoTitle,
                onChanged: (v) => setState(() => _autoTitle = v ?? true),
              ),
              const Expanded(
                child: Text('Auto-generate a title from the transcript'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Automatic subject detection — Class, Meeting or a subject code'),
          const SizedBox(height: 2),
          const Text('Mic & language — Device mic · Banglish'),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    recording ? 'Recording…' : 'Ready to capture',
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recording
                        ? 'Tap to stop and save · recording keeps going with the screen off'
                        : 'Local capture. No upload. All processing happens on your device.',
                    textAlign: TextAlign.center,
                  ),
                  if (recording) ...[
                    const SizedBox(height: 16),
                    Text(
                      fmtDuration(seconds),
                      style: const TextStyle(
                          fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                  ],
                  if (recording && service.transcriptAvailable) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live transcript — what you are saying now',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            service.liveTranscript.isEmpty
                                ? 'Listening… speak now.'
                                : service.liveTranscript,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : (recording ? _stop : _start),
            icon: Icon(recording ? Icons.stop : Icons.mic, size: 20),
            label: Text(recording ? 'Stop & save as .md' : 'Start recording'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_noteReady && last != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _simulateSummary,
                    child: const Text('Transcribe with on-device AI'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onOpenSession(last.id),
                    child: const Text('Open note'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _downloadMd,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download .md'),
            ),
          ],
          if (_summaryOpen && last != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(last.title,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(last.summary),
                    if (last.examHints.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Exam hints',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ...last.examHints.map((h) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('[${h.time}] ${h.text}'),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.content_copy, size: 18),
                tooltip: 'Copy note',
                onPressed: last == null
                    ? null
                    : () {
                        Clipboard.setData(
                            ClipboardData(text: last.buildRaw()));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Note copied.')));
                      },
              ),
              const Text('Copy the saved note as Markdown.'),
            ],
          ),
        ],
      ),
    );
  }
}
