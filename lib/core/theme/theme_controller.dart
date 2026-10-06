import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  static const String _key = 'is_dark_mode';
  static final ThemeController instance = ThemeController._();

  ThemeController._() : super(ThemeMode.light) {
    loadTheme();
  }

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_key) ?? false;
      value = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      print('ThemeController loadTheme error: $e');
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    value = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, isDark);
    } catch (e) {
      print('ThemeController setDarkMode error: $e');
    }
  }

  bool get isDarkMode => value == ThemeMode.dark;
}

final themeController = ThemeController.instance;
