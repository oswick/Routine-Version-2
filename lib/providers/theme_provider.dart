import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _accentColorKey = 'accent_color';

  static const Map<String, Color> accentColors = {
    'Purple': Color(0xFF6750A4),
    'Blue': Color(0xFF0061A4),
    'Teal': Color(0xFF006A6A),
    'Green': Color(0xFF386A20),
    'Orange': Color(0xFF8B5000),
    'Red': Color(0xFFBA1A1A),
    'Pink': Color(0xFF984061),
    'Indigo': Color(0xFF4F55A4),
  };

  String _selectedAccentColor = 'Purple';

  String get selectedAccentColor => _selectedAccentColor;
  Color get seedColor => accentColors[_selectedAccentColor]!;

  M3EThemeData get themeData => M3EThemeData.light(seedColor: seedColor);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_accentColorKey);

    if (saved != null && accentColors.containsKey(saved)) {
      _selectedAccentColor = saved;
    }
  }

  Future<void> setAccentColor(String colorName) async {
    if (!accentColors.containsKey(colorName) ||
        colorName == _selectedAccentColor) {
      return;
    }

    _selectedAccentColor = colorName;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentColorKey, colorName);
  }
}
