import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/session.dart';

/// Merge for AI: pick sessions, per-session + total token estimates,
/// Copy / Download merged .md. Merge joins notes for ChatGPT/Claude —
/// it is NOT a model download.
class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key, required this.sessions});

  final List<Session> sessions;

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    // Preselect the first two sessions, like the web demo.
    for (final s in widget.sessions.take(2)) {
      _selected.add(s.id);
    }
  }

  List<Session> get _picked => widget.sessions
      .where((s) => _selected.contains(s.id))
      .toList();

  int get _totalTokens =>
      _picked.fold<int>(0, (sum, s) => sum + s.tokens);

  String _mergedMd() =>
      _picked.map((s) => s.buildRaw()).join('\n\n---\n\n');

  Future<void> _copyMerged() async {
    await Clipboard.setData(ClipboardData(text: _mergedMd()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merged note copied.')));
    }
  }

  Future<void> _downloadMerged() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, 'sessionvault-merged.md'));
    await file.writeAsString(_mergedMd());
    await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)], text: 'sessionvault-merged.md'));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text('Merge for AI',
              style: Theme.of(context).textTheme.displayLarge),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
              'Pick sessions to join into one file for ChatGPT or Claude.'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_picked.length} selected',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('~$_totalTokens tokens',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: widget.sessions.isEmpty
              ? const Center(child: Text('No sessions yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  itemCount: widget.sessions.length,
                  itemBuilder: (ctx, i) {
                    final s = widget.sessions[i];
                    final checked = _selected.contains(s.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(s.id);
                            } else {
                              _selected.remove(s.id);
                            }
                          });
                        },
                        title: Text(s.title),
                        subtitle: Text(
                            '${s.date} · ${s.duration} · ~${s.tokens} tokens'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _picked.isEmpty ? null : _copyMerged,
                  child: const Text('Copy merged .md'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _picked.isEmpty ? null : _downloadMerged,
                  child: const Text('Download merged .md'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
