import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages theme switching (light / dark / system).
class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'system';
    _themeMode = _fromString(saved);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
  }

  ThemeMode _fromString(String s) => switch (s) {
    'light' => ThemeMode.light,
    'dark'  => ThemeMode.dark,
    _       => ThemeMode.system,
  };

  String _toString(ThemeMode m) => switch (m) {
    ThemeMode.light  => 'light',
    ThemeMode.dark   => 'dark',
    ThemeMode.system => 'system',
  };
}
