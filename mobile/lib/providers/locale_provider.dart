import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// English or Khmer (multi-language bonus). The choice is saved on the device.
class LocaleProvider extends ChangeNotifier {
  static const _key = 'locale';
  static const supported = [Locale('en'), Locale('km')];

  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  bool get isKhmer => _locale.languageCode == 'km';

  Future<void> load() async {
    try {
      final code = (await SharedPreferences.getInstance()).getString(_key);
      if (code != null && supported.any((l) => l.languageCode == code)) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (_) {
      // English stays
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_key, locale.languageCode);
    } catch (_) {
      // Only remembered for this run
    }
  }
}
