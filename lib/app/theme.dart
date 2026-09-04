/// 留痕主题：克制、清晰、安静。
///
/// 多角色颜色：矿物白、墨绿、朱红、琥珀、湖蓝。
/// 深色主题使用中性近黑与低饱和表面；不使用玻璃拟态、星系光球、呼吸动画。
library;

import 'package:flutter/material.dart';

/// 设计令牌。
class Palette {
  Palette._();

  // 角色色（明暗两套）。
  static const mineralWhite = Color(0xFFF6F3EA); // 矿物白
  static const inkGreen = Color(0xFF2F4B3E); // 墨绿
  static const vermilion = Color(0xFFB8452F); // 朱红
  static const amber = Color(0xFFC98A2D); // 琥珀
  static const lakeBlue = Color(0xFF2E6E7E); // 湖蓝

  // 深色表面。
  static const nearBlack = Color(0xFF141715); // 中性近黑
  static const surfaceDark = Color(0xFF1D211E);
  static const surfaceDark2 = Color(0xFF262B27);
}

const _radius = 12.0;

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.inkGreen,
    brightness: Brightness.light,
    primary: Palette.inkGreen,
    secondary: Palette.lakeBlue,
    error: Palette.vermilion,
    surface: Palette.mineralWhite,
  );
  return _base(ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.mineralWhite,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.mineralWhite,
      foregroundColor: Palette.inkGreen,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: BorderSide(color: Palette.inkGreen.withValues(alpha: 0.12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: Palette.inkGreen.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: Palette.inkGreen.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Palette.inkGreen, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.inkGreen.withValues(alpha: 0.08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
    ),
  ));
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.inkGreen,
    brightness: Brightness.dark,
    primary: const Color(0xFF8FB8A4),
    secondary: const Color(0xFF7FB0BF),
    error: const Color(0xFFE07A63),
    surface: Palette.nearBlack,
  );
  return _base(ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.nearBlack,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.nearBlack,
      foregroundColor: Color(0xFFE6E3D8),
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Palette.surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surfaceDark2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFF8FB8A4), width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ));
}

ThemeData _base(ThemeData t) {
  return t.copyWith(
    textTheme: t.textTheme.apply(
      bodyColor: t.brightness == Brightness.dark
          ? const Color(0xFFE6E3D8)
          : const Color(0xFF1F2A24),
      displayColor: t.brightness == Brightness.dark
          ? const Color(0xFFEDEADF)
          : const Color(0xFF1F2A24),
      fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'Noto Sans CJK SC'],
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.scaffoldBackgroundColor,
      indicatorColor: Palette.inkGreen.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.inkGreen,
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}