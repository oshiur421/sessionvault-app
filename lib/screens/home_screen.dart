import 'package:material_ui/material_ui.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/session.dart';
import '../services/model_download_service.dart';
import '../services/recorder_service.dart';
import '../services/session_store.dart';
import '../services/supabase_service.dart';
import '../widgets/ai_setup_dialog.dart';
import 'merge_screen.dart';
import 'recorder_screen.dart';
import 'session_detail_screen.dart';
import 'sessions_screen.dart';

/// Main page: Recorder / Sessions / Merge for AI.
///
/// There is NO Login tab/button/text here — Login is only the first screen.
/// Top bar: icon-only theme toggle + icon-only logout (logout clears only
/// the session; models-ready state and theme are kept).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onLoggedOut,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLoggedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  List<Session> _sessions = [];
  bool _modelsReady = false;
  bool _aiSetupShown = false;
  String? _lastSavedId;

  @override
  void initState() {
    super.initState();
    _reload();
    _checkModels();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  void _onTaskData(Object data) {
    if (data == 'stop') {
      RecorderService.instance.onStopFromNotification?.call();
    }
  }

  Future<void> _reload() async {
    await SessionStore.instance.load();
    if (!mounted) return;
    setState(() => _sessions = SessionStore.instance.sessions);
  }

  Future<void> _checkModels() async {
    final ready = await ModelDownloadService.instance.isReady;
    if (!mounted) return;
    setState(() => _modelsReady = ready);
    if (!ready && !_aiSetupShown) {
      _aiSetupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final done = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AiSetupDialog(),
        );
        if (done == true && mounted) {
          setState(() => _modelsReady = true);
        }
      });
    }
  }

  Future<void> _logout() async {
    await SupabaseService.instance.signOut();
    widget.onLoggedOut();
  }

  void _onSessionSaved(Session s) {
    setState(() {
      _lastSavedId = s.id;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isNight = widget.themeMode == ThemeMode.dark;
    final pages = [
      RecorderScreen(
        lastSavedId: _lastSavedId,
        onSessionSaved: _onSessionSaved,
        onOpenSession: (id) {
          final s = SessionStore.instance.byId(id);
          if (s == null) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionDetailScreen(
                sessionId: s.id,
                onChanged: _reload,
              ),
            ),
          );
        },
        onSavedChanged: _reload,
      ),
      SessionsScreen(
        sessions: _sessions,
        onChanged: _reload,
      ),
      MergeScreen(sessions: _sessions),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('SessionVault',
            style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold)),
        actions: [
          if (_modelsReady)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Chip(
                label: Text('AI ready', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          // Icon-only theme toggle: sun / moon side by side, no text label.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.wb_sunny_outlined,
                  size: 20,
                  color: !isNight
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: 'Paper theme',
                onPressed: isNight ? widget.onToggleTheme : null,
              ),
              const Text('|',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
              IconButton(
                icon: Icon(
                  Icons.nightlight_round,
                  size: 18,
                  color: isNight
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: 'Night theme',
                onPressed: isNight ? null : widget.onToggleTheme,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Recorder',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.folder_open),
            label: 'Sessions ${_sessions.length}',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.merge_type),
            label: 'Merge for AI',
          ),
        ],
      ),
    );
  }
}
