import 'package:material_ui/material_ui.dart';

/// SessionVault design tokens — calm paper-and-ink, matching the approved
/// web demo. Paper = warm cream, Night = near-black, orange-red accent,
/// serif headings, no gradients/glows/emoji icons.
class AppTheme {
  static const Color accent = Color(0xFFC2410C); // orange-red (paper)
  static const Color accentNight = Color(0xFFE8590C); // brighter for night
  static const Color paperBg = Color(0xFFFAF6EE);
  static const Color paperSurface = Color(0xFFFFFDF7);
  static const Color paperInk = Color(0xFF1C1917);
  static const Color paperMuted = Color(0xFF78716C);
  static const Color paperBorder = Color(0xFFE7DFD3);

  static const Color nightBg = Color(0xFF131210);
  static const Color nightSurface = Color(0xFF1E1C19);
  static const Color nightInk = Color(0xFFF5F0E8);
  static const Color nightMuted = Color(0xFFA8A29A);
  static const Color nightBorder = Color(0xFF2E2A26);

  static const String serif = 'serif';

  static ThemeData paper = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: paperBg,
    colorScheme: const ColorScheme.light(
      primary: accent,
      surface: paperSurface,
      onSurface: paperInk,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          fontFamily: serif,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: paperInk),
      displayMedium: TextStyle(
          fontFamily: serif,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: paperInk),
      titleLarge: TextStyle(
          fontFamily: serif,
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: paperInk),
      titleMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: paperInk),
      bodyMedium: TextStyle(fontSize: 14, color: paperInk, height: 1.45),
      bodySmall: TextStyle(fontSize: 13, color: paperMuted, height: 1.4),
    ),
    cardTheme: const CardThemeData(
      color: paperSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: paperBorder),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: paperSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: paperBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: paperBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: paperSurface,
      selectedItemColor: accent,
      unselectedItemColor: paperMuted,
      type: BottomNavigationBarType.fixed,
    ),
  );

  static ThemeData night = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: nightBg,
    colorScheme: const ColorScheme.dark(
      primary: accentNight,
      surface: nightSurface,
      onSurface: nightInk,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          fontFamily: serif,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: nightInk),
      displayMedium: TextStyle(
          fontFamily: serif,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: nightInk),
      titleLarge: TextStyle(
          fontFamily: serif,
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: nightInk),
      titleMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: nightInk),
      bodyMedium: TextStyle(fontSize: 14, color: nightInk, height: 1.45),
      bodySmall: TextStyle(fontSize: 13, color: nightMuted, height: 1.4),
    ),
    cardTheme: const CardThemeData(
      color: nightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: nightBorder),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: nightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: nightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: nightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: accentNight, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentNight,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: nightSurface,
      selectedItemColor: accentNight,
      unselectedItemColor: nightMuted,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
