import 'package:flutter/material.dart';

class BilloColors {
  const BilloColors._();

  static const paper = Color(0xFFEFE6D4);
  static const paperDeep = Color(0xFFE3D5B8);
  static const slip = Color(0xFFFFFBF3);
  static const ink = Color(0xFF1C2422);
  static const inkSoft = Color(0xFF5E584E);
  static const spine = Color(0xFF1E6A58);
  static const spineDark = Color(0xFF11483C);
  static const cream = Color(0xFFF6F1E4);
  static const creamFold = Color(0xFFD5CBB6);
  static const stamp = Color(0xFFB6402C);
  static const ok = Color(0xFF1F7A45);
  static const pending = Color(0xFF8A5A12);
  static const line = Color(0xFFE4D8C2);
}

ThemeData buildBilloTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: BilloColors.paper,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: BilloColors.spine,
      onPrimary: BilloColors.cream,
      secondary: BilloColors.stamp,
      onSecondary: BilloColors.cream,
      error: BilloColors.stamp,
      onError: BilloColors.cream,
      surface: BilloColors.slip,
      onSurface: BilloColors.ink,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: BilloColors.ink,
      displayColor: BilloColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: BilloColors.spine,
      foregroundColor: BilloColors.cream,
      elevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: BilloColors.slip,
      indicatorColor: BilloColors.paperDeep,
      height: 64,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: BilloColors.slip,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: BilloColors.line),
      ),
    ),
    checkboxTheme: const CheckboxThemeData(
      side: BorderSide(color: BilloColors.ink, width: 1.4),
    ),
  );
}
