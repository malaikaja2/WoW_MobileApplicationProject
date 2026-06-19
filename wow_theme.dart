import 'package:flutter/material.dart';

class WowColors {
  const WowColors._();

  static const purple = Color(0xFF9A48FF);
  static const violet = Color(0xFF8F43FF);
  static const pink = Color(0xFFF06AA5);
  static const rose = Color(0xFFEB5FA2);
  static const ink = Color(0xFF28153B);
  static const muted = Color(0xFF7D6A91);
  static const surface = Color(0xFFF7F1FB);
  static const line = Color(0xFFE9DCF6);
  static const success = Color(0xFF1FA971);
  static const warning = Color(0xFFFFA726);
  static const danger = Color(0xFFD32F2F);
}

class WowTheme {
  const WowTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: WowColors.pink,
      brightness: Brightness.light,
      primary: WowColors.purple,
      secondary: WowColors.pink,
      surface: Colors.white,
    );

    return ThemeData(
      colorScheme: scheme,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: WowColors.surface,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: WowColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: WowColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: WowColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: WowColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: WowColors.purple, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WowColors.purple,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
