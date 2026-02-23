import 'package:flutter/material.dart';

/// TravelBuddy design system.
/// All colours, typography and component themes are defined here.
class AppTheme {
  AppTheme._();

  // ─── Brand Colours ──────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF222222); // near-black (Airbnb style)
  static const Color accent       = Color(0xFFFF5A5F); // coral red accent
  static const Color accentLight  = Color(0xFFFFF0F0);
  static const Color success      = Color(0xFF34C759);
  static const Color warning      = Color(0xFFFF9F0A);
  static const Color error        = Color(0xFFFF3B30);

  // ─── Light palette ──────────────────────────────────────────────────────────
  static const Color bgLight      = Color(0xFFF7F7F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight  = Color(0xFFE8E8E8);
  static const Color textPrimary  = Color(0xFF1A1A1A);
  static const Color textSecondary= Color(0xFF717171);
  static const Color textHint     = Color(0xFFB0B0B0);

  // ─── Dark palette ───────────────────────────────────────────────────────────
  static const Color bgDark       = Color(0xFF121212);
  static const Color surfaceDark  = Color(0xFF1E1E1E);
  static const Color borderDark   = Color(0xFF2C2C2C);

  // ─── Typography ─────────────────────────────────────────────────────────────
  static const String fontFamily = 'Inter';

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
    displayLarge:  TextStyle(fontFamily: fontFamily, fontSize: 32, fontWeight: FontWeight.w700, color: primary, height: 1.2),
    displayMedium: TextStyle(fontFamily: fontFamily, fontSize: 26, fontWeight: FontWeight.w700, color: primary, height: 1.2),
    displaySmall:  TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w600, color: primary),
    headlineMedium:TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w600, color: primary),
    headlineSmall: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: primary),
    titleLarge:    TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600, color: primary),
    titleMedium:   TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: primary),
    bodyLarge:     TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w400, color: primary, height: 1.6),
    bodyMedium:    TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: secondary, height: 1.5),
    bodySmall:     TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: secondary),
    labelLarge:    TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: primary),
    labelSmall:    TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: secondary, letterSpacing: 0.5),
  );

  // ─── Light theme ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: surfaceLight,
      error: error,
    ),
    scaffoldBackgroundColor: bgLight,
    textTheme: _textTheme(textPrimary, textSecondary),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceLight,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: borderLight,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderLight, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: textHint, fontFamily: fontFamily),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceLight,
      selectedItemColor: primary,
      unselectedItemColor: textHint,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
  );

  // ─── Dark theme ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: Colors.white,
      secondary: accent,
      surface: surfaceDark,
      error: error,
    ),
    scaffoldBackgroundColor: bgDark,
    textTheme: _textTheme(Colors.white, const Color(0xFFAAAAAA)),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderDark, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF555555), fontFamily: 'Inter'),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: bgDark,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(color: borderDark, thickness: 1),
  );
}
