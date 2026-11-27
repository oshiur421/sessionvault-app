import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase is used for LOGIN ONLY.
///
/// - Config comes from --dart-define SUPABASE_URL / SUPABASE_ANON_KEY.
///   No real key is ever hardcoded or printed.
/// - If not configured, the app runs in DEMO mode: any email/password works
///   locally and the "session" is just a flag on the device (same as the
///   web app).
/// - Login events are recorded in the `login_logs` table when configured;
///   failures are ignored silently (login must never fail because logging did).
/// - Logout clears only the session. Models-ready state and theme are kept.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static const _lsSession = 'sessionvault_session';

  bool _configured = false;
  bool _demoLoggedIn = false;

  bool get isConfigured => _configured;

  static String get url =>
      const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static String get anonKey =>
      const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  Future<void> init() async {
    _configured = url.isNotEmpty && anonKey.isNotEmpty;
    if (_configured) {
      await Supabase.initialize(url: url, publishableKey: anonKey);
    }
    final prefs = await SharedPreferences.getInstance();
    _demoLoggedIn = prefs.getBool(_lsSession) ?? false;
  }

  bool get isLoggedIn {
    if (_configured) {
      return Supabase.instance.client.auth.currentSession != null;
    }
    return _demoLoggedIn;
  }

  String? get userEmail {
    if (_configured) {
      return Supabase.instance.client.auth.currentUser?.email;
    }
    return null;
  }

  Future<String?> signIn(String email, String password) async {
    if (!_configured) {
      // Demo mode: any email/password works locally.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lsSession, true);
      _demoLoggedIn = true;
      return null;
    }
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user != null) {
        await _logSignIn(user.id, user.email ?? email);
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUp(String email, String password) async {
    if (!_configured) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lsSession, true);
      _demoLoggedIn = true;
      return null;
    }
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user != null) {
        await _logSignIn(user.id, user.email ?? email);
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> resetPassword(String email) async {
    if (!_configured) {
      return 'Password reset needs a configured Supabase project.';
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    if (_configured) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // Best effort — local state is cleared below regardless.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lsSession, false);
    _demoLoggedIn = false;
  }

  Future<void> _logSignIn(String userId, String email) async {
    if (!_configured) return;
    try {
      await Supabase.instance.client.from('login_logs').insert({
        'user_id': userId,
        'email': email,
      });
    } catch (_) {
      // Never fail login because logging failed.
    }
  }
}
