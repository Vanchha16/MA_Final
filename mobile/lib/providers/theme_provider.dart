import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dark mode toggle (bonus feature). The choice is saved on the device.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = ThemeMode.values[prefs.getInt(_key) ?? ThemeMode.system.index];
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }
}
