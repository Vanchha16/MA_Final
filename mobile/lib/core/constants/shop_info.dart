/// How to reach the shop (Contact screen). Placeholders until the shop's real details are in.
class ShopInfo {
  static const phone = '+855 12 345 678';
  static const telegram = '@animeworldshop_kh';
  static const email = 'hello@animeworld.shop';
  static const address = '#88 St. 315, Boeung Kak 2, Toul Kork, Phnom Penh';

  static final phoneUri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
  static final telegramUri = Uri.https('t.me', '/${telegram.substring(1)}');
  static final emailUri = Uri(scheme: 'mailto', path: email, query: 'subject=Anime%20World%20Shop');
  static final mapsUri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': 'St. 315, Boeung Kak 2, Toul Kork, Phnom Penh'});

  /// Open every day, 9:00 - 20:00 (Phnom Penh time is the phone's time for our customers).
  static const opensAt = 9, closesAt = 20;

  static bool isOpen(DateTime now) => now.hour >= opensAt && now.hour < closesAt;
}
