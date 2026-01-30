import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. The State now holds Mode AND Color
class ThemeState {
  final ThemeMode themeMode;
  final Color seedColor;

  ThemeState({required this.themeMode, required this.seedColor});
}

class ThemeCubit extends Cubit<ThemeState> {
  // Default: Purple & System Mode
  ThemeCubit() : super(ThemeState(themeMode: ThemeMode.system, seedColor: const Color(0xFF5B3E96))) {
    _loadSettings();
  }

  // 2. Change Color
  void changeColor(Color color) async {
    emit(ThemeState(themeMode: state.themeMode, seedColor: color));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seedColor', color.value);
  }

  // 3. Toggle Light/Dark
  void toggleTheme(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    emit(ThemeState(themeMode: mode, seedColor: state.seedColor));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  // 4. Load Saved Settings
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode');
    final colorValue = prefs.getInt('seedColor');

    ThemeMode mode = ThemeMode.system;
    if (isDark != null) mode = isDark ? ThemeMode.dark : ThemeMode.light;

    Color color = const Color(0xFF5B3E96);
    if (colorValue != null) color = Color(colorValue);

    emit(ThemeState(themeMode: mode, seedColor: color));
  }
}