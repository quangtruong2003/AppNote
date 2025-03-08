import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  MaterialColor _primaryColor = Colors.blue;

  // Thêm getter cho lightTheme và darkTheme
  ThemeData get lightTheme => ThemeData(
    primarySwatch: _primaryColor,
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    ),
  );

  ThemeData get darkTheme => ThemeData(
    primarySwatch: _primaryColor,
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.dark,
    ),
  );

  // Đảm bảo rằng theme trả về đúng theme hiện tại
  ThemeData get theme => _isDarkMode ? darkTheme : lightTheme;

  bool get isDarkMode => _isDarkMode;
  MaterialColor get primaryColor => _primaryColor;

  ThemeProvider() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      final colorValue = prefs.getInt('primary_color') ?? Colors.blue.value;
      _primaryColor = _getMaterialColorFromValue(colorValue);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', _isDarkMode);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  Future<void> setPrimaryColor(MaterialColor color) async {
    _primaryColor = color;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('primary_color', color.value);
    } catch (e) {
      debugPrint('Error saving color preference: $e');
    }
  }

  MaterialColor _getMaterialColorFromValue(int value) {
    if (value == Colors.blue.value) return Colors.blue;
    if (value == Colors.purple.value) return Colors.purple;
    if (value == Colors.pink.value) return Colors.pink;
    if (value == Colors.red.value) return Colors.red;
    if (value == Colors.orange.value) return Colors.orange;
    if (value == Colors.amber.value) return Colors.amber;
    if (value == Colors.green.value) return Colors.green;
    if (value == Colors.teal.value) return Colors.teal;
    if (value == Colors.indigo.value) return Colors.indigo;
    return Colors.blue; // Default
  }
}
