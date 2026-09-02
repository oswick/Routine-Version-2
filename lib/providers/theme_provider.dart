// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:myapp/config/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'app_theme_mode';
  static const String _amoledKey = 'app_amoled_mode';
  static const String _seedColorKey = 'app_seed_color_index';
  static const String _useDynamicColorKey = 'app_use_dynamic_color';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isAmoled = false;
  AppThemeSeed _selectedSeed = AppThemeSeed.indigo;
  bool _useDynamicColor = true;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isAmoled => _isAmoled;
  AppThemeSeed get selectedSeed => _selectedSeed;
  bool get useDynamicColor => _useDynamicColor;
  bool get isInitialized => _isInitialized;

  Color get currentSeedColor => _selectedSeed.color;

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final modeIndex = prefs.getInt(_themeModeKey);
      if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[modeIndex];
      }

      _isAmoled = prefs.getBool(_amoledKey) ?? false;

      final seedIndex = prefs.getInt(_seedColorKey);
      if (seedIndex != null && seedIndex >= 0 && seedIndex < AppThemeSeed.values.length) {
        _selectedSeed = AppThemeSeed.values[seedIndex];
      }

      _useDynamicColor = prefs.getBool(_useDynamicColorKey) ?? true;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
      _isInitialized = true;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setAmoled(bool value) async {
    if (_isAmoled == value) return;
    _isAmoled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_amoledKey, value);
  }

  Future<void> setSelectedSeed(AppThemeSeed seed) async {
    if (_selectedSeed == seed && !_useDynamicColor) return;
    _selectedSeed = seed;
    _useDynamicColor = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, seed.index);
    await prefs.setBool(_useDynamicColorKey, false);
  }

  Future<void> setUseDynamicColor(bool value) async {
    if (_useDynamicColor == value) return;
    _useDynamicColor = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDynamicColorKey, value);
  }
}
