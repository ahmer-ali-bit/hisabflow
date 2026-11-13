import 'package:flutter/material.dart';

abstract final class BrandColors {
  static const ink = Color(0xFF183B32);
  static const surface = Color(0xFFFFFFFF);
  static const elevated = Color(0xFFEAF2ED);
  static const teal = Color(0xFF18745D);
  static const gold = Color(0xFFB88942);
  static const muted = Color(0xFF71827B);
  static const canvas = Color(0xFFF4F7F4);
  static const border = Color(0xFFE2EAE5);
  static const mint = Color(0xFFE3F2EB);
  static const coral = Color(0xFFC76854);
}

ThemeData buildHisabTheme() {
  const scheme = ColorScheme.light(
    primary: BrandColors.teal,
    onPrimary: Colors.white,
    secondary: BrandColors.gold,
    onSecondary: Colors.white,
    surface: BrandColors.surface,
    onSurface: BrandColors.ink,
    error: BrandColors.coral,
    onError: Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: BrandColors.canvas,
    cardTheme: CardThemeData(
      color: BrandColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BrandColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: BrandColors.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BrandColors.surface,
      hintStyle: const TextStyle(color: BrandColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.teal, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: BrandColors.teal,
        minimumSize: const Size(48, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BrandColors.ink,
        side: const BorderSide(color: BrandColors.border),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: BrandColors.surface,
      selectedIconTheme: IconThemeData(color: BrandColors.teal),
      selectedLabelTextStyle: TextStyle(color: BrandColors.ink, fontWeight: FontWeight.w700),
      indicatorColor: BrandColors.mint,
      unselectedIconTheme: IconThemeData(color: BrandColors.muted),
      unselectedLabelTextStyle: TextStyle(color: BrandColors.muted),
      labelType: NavigationRailLabelType.all,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: BrandColors.surface,
      indicatorColor: BrandColors.mint,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: BrandColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: BrandColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: const TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: BrandColors.ink),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: BrandColors.ink),
      titleMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: BrandColors.ink),
      bodyLarge: const TextStyle(fontSize: 15, color: BrandColors.ink),
      bodyMedium: const TextStyle(fontSize: 14, color: BrandColors.ink),
      labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BrandColors.muted),
    ),
  );
}
