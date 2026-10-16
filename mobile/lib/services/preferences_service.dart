import '../core/network/api_client.dart';

/// Settings > Notify me about (saved on the account, so the server skips those messages).
class NotifyPrefs {
  final bool orders, offers, news;

  const NotifyPrefs({this.orders = true, this.offers = true, this.news = true});

  factory NotifyPrefs.fromJson(Map<String, dynamic> json) =>
      NotifyPrefs(orders: json['notify_orders'] ?? true, offers: json['notify_offers'] ?? true, news: json['notify_news'] ?? true);

  NotifyPrefs copyWith({bool? orders, bool? offers, bool? news}) =>
      NotifyPrefs(orders: orders ?? this.orders, offers: offers ?? this.offers, news: news ?? this.news);

  Map<String, dynamic> toJson() => {'notify_orders': orders, 'notify_offers': offers, 'notify_news': news};
}

class PreferencesService {
  final _api = ApiClient.instance;
  static const _path = '/profile/preferences';

  Future<NotifyPrefs> get() async => NotifyPrefs.fromJson(await _api.get(_path));

  Future<NotifyPrefs> save(NotifyPrefs prefs) async => NotifyPrefs.fromJson(await _api.put(_path, data: prefs.toJson()));
}
