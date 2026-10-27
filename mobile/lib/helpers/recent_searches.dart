import 'package:shared_preferences/shared_preferences.dart';

/// The last few things searched for, kept on this device only.
class RecentSearches {
  static const _key = 'recent_searches';
  static const max = 8;

  static Future<List<String>> load() async {
    try {
      return (await SharedPreferences.getInstance()).getStringList(_key) ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Puts [term] first (no duplicates, ignoring case) and keeps the newest [max].
  static Future<List<String>> add(String term) async {
    final t = term.trim();
    final list = await load();
    if (t.isEmpty) return list;
    final next = [t, ...list.where((x) => x.toLowerCase() != t.toLowerCase())].take(max).toList();
    await _save(next);
    return next;
  }

  static Future<List<String>> remove(String term) async {
    final next = (await load()).where((x) => x != term).toList();
    await _save(next);
    return next;
  }

  static Future<void> clear() => _save([]);

  static Future<void> _save(List<String> list) async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, list);
    } catch (_) {
      // Recent searches are only a convenience
    }
  }
}
