import 'package:flutter/material.dart';

ThemeData buildDailyAskingTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C5CFF),
    brightness: brightness,
    primary: const Color(0xFF7C5CFF),
    secondary: const Color(0xFFFFB86B),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0C1020) : const Color(0xFFF7F3FF),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF161B2F) : Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF101629) : const Color(0xFFF5F1FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      indicatorColor: scheme.primaryContainer,
      backgroundColor: dark ? const Color(0xFF11162A) : Colors.white.withValues(alpha: 0.92),
    ),
  );
}
