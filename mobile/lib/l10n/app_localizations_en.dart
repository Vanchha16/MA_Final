// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navCategories => 'Categories';

  @override
  String get navWishlist => 'Wishlist';

  @override
  String get navCart => 'Cart';

  @override
  String get navProfile => 'Profile';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearance => 'APPEARANCE';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'LANGUAGE';

  @override
  String get notifyMeAbout => 'NOTIFY ME ABOUT';

  @override
  String get notifyOrders => 'My orders';

  @override
  String get notifyOrdersSub => 'Paid, on the way, delivered';

  @override
  String get notifyOffers => 'Offers and promo codes';

  @override
  String get notifyOffersSub => 'Flash sales and new codes';

  @override
  String get notifyNews => 'Shop news';

  @override
  String get notifyNewsSub => 'New payment ways, new series';

  @override
  String get logInToChooseNotifications =>
      'Log in to choose your notifications';

  @override
  String get more => 'MORE';

  @override
  String get myAddresses => 'My addresses';

  @override
  String addressesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved',
      one: '1 saved',
      zero: 'None yet',
    );
    return '$_temp0';
  }

  @override
  String get helpContact => 'Help & contact';

  @override
  String get about => 'About';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get myOrders => 'My Orders';

  @override
  String get viewAll => 'View all';

  @override
  String get toPay => 'To Pay';

  @override
  String get toShip => 'To Ship';

  @override
  String get toReceive => 'To Receive';

  @override
  String get toReview => 'To Review';

  @override
  String get myWishlist => 'My Wishlist';

  @override
  String get addresses => 'Addresses';

  @override
  String get aboutApp => 'About App';

  @override
  String get logOut => 'Log out';

  @override
  String homeGreeting(String name) {
    return 'Hi $name, welcome back';
  }

  @override
  String get homeGreetingGuest => 'Hi there, welcome';

  @override
  String get seeAll => 'See all';

  @override
  String get allProducts => 'All products';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get shopByAnime => 'Shop by anime';

  @override
  String get cartTitle => 'Shopping Cart';

  @override
  String get goToCheckout => 'Go to checkout';

  @override
  String get total => 'Total';

  @override
  String get clear => 'Clear';

  @override
  String get wishlistTitle => 'Wishlist';

  @override
  String savedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved items',
      one: '1 saved item',
    );
    return '$_temp0';
  }

  @override
  String get ordersTitle => 'My orders';

  @override
  String inProgress(int count) {
    return 'In progress · $count';
  }

  @override
  String get nothingInProgress => 'Nothing in progress';

  @override
  String get pastOrders => 'Past orders';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get allCaughtUp => 'All caught up';

  @override
  String newCount(int count) {
    return '$count new';
  }

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get placeOrder => 'Place order';

  @override
  String get addAddress => 'Add new address';

  @override
  String get defaultAddress => 'Default';

  @override
  String get noAddresses => 'No saved addresses yet';

  @override
  String get noAddressesSub => 'Add one now and checkout gets faster.';

  @override
  String get helpTitle => 'Help & contact';

  @override
  String get contactUs => 'CONTACT US';

  @override
  String get callUs => 'Call us';

  @override
  String get telegram => 'Telegram';

  @override
  String get emailUs => 'Email';

  @override
  String get visitShop => 'Visit the shop';

  @override
  String get openHours => 'Open every day, 9:00 - 20:00';

  @override
  String get tapToCopy => 'Tap to copy';

  @override
  String copied(String value) {
    return '$value copied';
  }

  @override
  String get faq => 'QUESTIONS';

  @override
  String get faq1q => 'How long does delivery take?';

  @override
  String get faq1a =>
      'In Phnom Penh we deliver the next day, between 9:00 and 18:00. Delivery is free from \$50.';

  @override
  String get faq2q => 'How can I pay?';

  @override
  String get faq2a =>
      'Scan the Bakong KHQR with any Cambodian bank app, or pay cash when your order arrives.';

  @override
  String get faq3q => 'Are the figures genuine?';

  @override
  String get faq3a =>
      'Yes. Every product is official, from makers like Bandai, Good Smile Company and MegaHouse.';

  @override
  String get faq4q => 'What if the box arrives damaged?';

  @override
  String get faq4a =>
      'Take a photo and contact us within 3 days. We will replace it or give your money back.';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutTagline =>
      'Figures, plush, model kits and anime cards in Phnom Penh.';

  @override
  String get aboutMadeBy =>
      'A SETEC Institute final project (SU25, Mobile Application).';

  @override
  String get aboutCredit =>
      'Product images belong to their respective owners and are used for educational purposes only.';
}
