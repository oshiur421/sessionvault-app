import 'package:material_ui/material_ui.dart';

import '../models/session.dart';
import '../services/session_store.dart';
import 'session_detail_screen.dart';

/// Sessions tab: search, subject filter chips with counts, session list,
/// per-session delete with a confirm sheet.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({
    super.key,
    required this.sessions,
    required this.onChanged,
  });

  final List<Session> sessions;
  final VoidCallback onChanged;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  String _savedLine = '';

  @override
  void initState() {
    super.initState();
    _loadSavedLine();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLine() async {
    final line = await SessionStore.instance.savedLocallyLine();
    if (mounted) setState(() => _savedLine = line);
  }

  Future<void> _askDelete(Session s) async {
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
      await _loadSavedLine();
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = <String>{};
    for (final s in widget.sessions) {
      subjects.add(s.subject);
    }
    final filters = ['All', ...subjects.toList()..sort()];
    final q = _search.text.trim().toLowerCase();
    final filtered = widget.sessions.where((s) {
      final matchesQuery = q.isEmpty ||
          s.title.toLowerCase().contains(q) ||
          s.subject.toLowerCase().contains(q) ||
          s.filename.toLowerCase().contains(q);
      final matchesSubject = _filter == 'All' || s.subject == _filter;
      return matchesQuery && matchesSubject;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text('Sessions',
              style: Theme.of(context).textTheme.displayLarge),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
              'Every recording becomes one Markdown file. Tap a session to open its note below.'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search sessions…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: filters.map((f) {
              final count = f == 'All'
                  ? widget.sessions.length
                  : widget.sessions.where((s) => s.subject == f).length;
              final selected = _filter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$f  $count'),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text('Saved locally — $_savedLine'),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No sessions match.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final s = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SessionDetailScreen(
                                sessionId: s.id,
                                onChanged: widget.onChanged,
                              ),
                            ),
                          );
                          await _loadSavedLine();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.subject.toUpperCase(),
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(s.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${s.date} · ${s.duration} · ~${s.tokens} tokens'),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                tooltip: 'Delete ${s.title}',
                                onPressed: () => _askDelete(s),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
