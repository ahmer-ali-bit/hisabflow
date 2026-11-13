import 'package:flutter/material.dart';

abstract final class BrandColors {
  static const ink = Color(0xFF101A1C);
  static const surface = Color(0xFF192527);
  static const elevated = Color(0xFF223235);
  static const teal = Color(0xFF54D6B3);
  static const gold = Color(0xFFE6B66A);
  static const muted = Color(0xFF93A5A3);
  static const canvas = Color(0xFF0D1517);
}

ThemeData buildHisabTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.teal,
    brightness: Brightness.dark,
    surface: BrandColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: BrandColors.teal,
      secondary: BrandColors.gold,
      surface: BrandColors.surface,
      onSurface: const Color(0xFFEAF1EF),
    ),
    scaffoldBackgroundColor: BrandColors.canvas,
    cardTheme: CardTheme(
      color: BrandColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BrandColors.elevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: BrandColors.surface,
      selectedIconTheme: IconThemeData(color: BrandColors.ink),
      indicatorColor: BrandColors.teal,
      unselectedIconTheme: IconThemeData(color: BrandColors.muted),
      labelType: NavigationRailLabelType.all,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFC3D0CD)),
      labelMedium: TextStyle(fontSize: 12, color: BrandColors.muted),
    ),
  );
}
