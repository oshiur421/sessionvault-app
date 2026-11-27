import 'package:material_ui/material_ui.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/recorder_service.dart';
import 'services/session_store.dart';
import 'services/supabase_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase is login-only. If no --dart-define values were passed, the
  // app runs in demo mode (any email/password works locally).
  await SupabaseService.instance.init();
  await SessionStore.instance.load();

  // Foreground service setup for screen-off recording.
  RecorderService.initForegroundService();

  final prefs = await SharedPreferences.getInstance();
  final night = prefs.getBool('sessionvault_theme_night') ?? false;

  runApp(SessionVaultApp(initialNight: night));
}

class SessionVaultApp extends StatefulWidget {
  const SessionVaultApp({super.key, required this.initialNight});

  final bool initialNight;

  @override
  State<SessionVaultApp> createState() => _SessionVaultAppState();
}

class _SessionVaultAppState extends State<SessionVaultApp> {
  late ThemeMode _themeMode;
  late bool _loggedIn;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialNight ? ThemeMode.dark : ThemeMode.light;
    _loggedIn = SupabaseService.instance.isLoggedIn;
  }

  Future<void> _toggleTheme() async {
    final next =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sessionvault_theme_night', next == ThemeMode.dark);
    setState(() => _themeMode = next);
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: MaterialApp(
        title: 'SessionVault',
        theme: AppTheme.paper,
        darkTheme: AppTheme.night,
        themeMode: _themeMode,
        home: _loggedIn
            ? HomeScreen(
                themeMode: _themeMode,
                onToggleTheme: _toggleTheme,
                onLoggedOut: () => setState(() => _loggedIn = false),
              )
            : LoginScreen(
                onLoggedIn: () => setState(() => _loggedIn = true)),
      ),
    );
  }
}
