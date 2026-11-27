import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/session.dart';
import '../services/session_store.dart';

/// Session detail: Formatted / Raw .md, Copy, Download/share, tickable
/// action items, delete with confirm sheet.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    required this.onChanged,
  });

  final String sessionId;
  final VoidCallback onChanged;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  Session? _session;
  bool _raw = false;

  @override
  void initState() {
    super.initState();
    _session = SessionStore.instance.byId(widget.sessionId);
  }

  Future<void> _refresh() async {
    final s = SessionStore.instance.byId(widget.sessionId);
    if (mounted) setState(() => _session = s);
  }

  Future<void> _toggleAction(int i, bool? value) async {
    final s = _session;
    if (s == null) return;
    final checked = List<bool>.from(s.checkedActions);
    if (i < 0 || i >= checked.length) return;
    checked[i] = value ?? false;
    final updated = s.copyWith(checkedActions: checked);
    await SessionStore.instance.update(updated);
    widget.onChanged();
    await _refresh();
  }

  Future<void> _shareMd() async {
    final s = _session;
    if (s == null) return;
    final file = await SessionStore.instance.mdFile(s);
    if (file == null) return;
    await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: s.filename));
  }

  Future<void> _askDelete() async {
    final s = _session;
    if (s == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this session?',
            style:
                TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold)),
        content: Text(
            '"${s.title}" (${s.filename}) will be removed from this device. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SessionStore.instance.delete(s.id);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: const Center(child: Text('This session was deleted.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title,
            style:
                const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Copy note',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: s.buildRaw()));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note copied.')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, size: 20),
            tooltip: 'Download .md',
            onPressed: _shareMd,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Delete ${s.title}',
            onPressed: _askDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.date} · ${s.time} · ${s.duration}',
                style: Theme.of(context).textTheme.bodySmall),
            Text(s.filename,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Formatted')),
                ButtonSegment(value: true, label: Text('Raw .md')),
              ],
              selected: {_raw},
              onSelectionChanged: (v) => setState(() => _raw = v.first),
            ),
            const SizedBox(height: 16),
            if (_raw)
              SelectableText(
                s.buildRaw(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              )
            else ...[
              Text('Summary',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(s.summary),
              if (s.examHints.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Exam hints and key takeaways',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                ...s.examHints.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('[${h.time}] ${h.text}'),
                    )),
              ],
              if (s.notes.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Structured notes',
                    style: Theme.of(context).textTheme.titleLarge),
                ...s.notes.map((n) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.heading,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          ...n.points.map((p) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('• $p'),
                              )),
                        ],
                      ),
                    )),
              ],
              if (s.actions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Action items',
                    style: Theme.of(context).textTheme.titleLarge),
                ...List.generate(
                  s.actions.length,
                  (i) => CheckboxListTile(
                    value: i < s.checkedActions.length
                        ? s.checkedActions[i]
                        : false,
                    onChanged: (v) => _toggleAction(i, v),
                    title: Text(s.actions[i]),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
