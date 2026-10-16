import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_km.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('km'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get navCategories;

  /// No description provided for @navWishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get navWishlist;

  /// No description provided for @navCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get navCart;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get language;

  /// No description provided for @notifyMeAbout.
  ///
  /// In en, this message translates to:
  /// **'NOTIFY ME ABOUT'**
  String get notifyMeAbout;

  /// No description provided for @notifyOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get notifyOrders;

  /// No description provided for @notifyOrdersSub.
  ///
  /// In en, this message translates to:
  /// **'Paid, on the way, delivered'**
  String get notifyOrdersSub;

  /// No description provided for @notifyOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers and promo codes'**
  String get notifyOffers;

  /// No description provided for @notifyOffersSub.
  ///
  /// In en, this message translates to:
  /// **'Flash sales and new codes'**
  String get notifyOffersSub;

  /// No description provided for @notifyNews.
  ///
  /// In en, this message translates to:
  /// **'Shop news'**
  String get notifyNews;

  /// No description provided for @notifyNewsSub.
  ///
  /// In en, this message translates to:
  /// **'New payment ways, new series'**
  String get notifyNewsSub;

  /// No description provided for @logInToChooseNotifications.
  ///
  /// In en, this message translates to:
  /// **'Log in to choose your notifications'**
  String get logInToChooseNotifications;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'MORE'**
  String get more;

  /// No description provided for @myAddresses.
  ///
  /// In en, this message translates to:
  /// **'My addresses'**
  String get myAddresses;

  /// No description provided for @addressesSaved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None yet} =1{1 saved} other{{count} saved}}'**
  String addressesSaved(int count);

  /// No description provided for @helpContact.
  ///
  /// In en, this message translates to:
  /// **'Help & contact'**
  String get helpContact;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @toPay.
  ///
  /// In en, this message translates to:
  /// **'To Pay'**
  String get toPay;

  /// No description provided for @toShip.
  ///
  /// In en, this message translates to:
  /// **'To Ship'**
  String get toShip;

  /// No description provided for @toReceive.
  ///
  /// In en, this message translates to:
  /// **'To Receive'**
  String get toReceive;

  /// No description provided for @toReview.
  ///
  /// In en, this message translates to:
  /// **'To Review'**
  String get toReview;

  /// No description provided for @myWishlist.
  ///
  /// In en, this message translates to:
  /// **'My Wishlist'**
  String get myWishlist;

  /// No description provided for @addresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get addresses;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutApp;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, welcome back'**
  String homeGreeting(String name);

  /// No description provided for @homeGreetingGuest.
  ///
  /// In en, this message translates to:
  /// **'Hi there, welcome'**
  String get homeGreetingGuest;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @allProducts.
  ///
  /// In en, this message translates to:
  /// **'All products'**
  String get allProducts;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @shopByAnime.
  ///
  /// In en, this message translates to:
  /// **'Shop by anime'**
  String get shopByAnime;

  /// No description provided for @cartTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping Cart'**
  String get cartTitle;

  /// No description provided for @goToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Go to checkout'**
  String get goToCheckout;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @wishlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlistTitle;

  /// No description provided for @savedItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved item} other{{count} saved items}}'**
  String savedItems(int count);

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get ordersTitle;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress · {count}'**
  String inProgress(int count);

  /// No description provided for @nothingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Nothing in progress'**
  String get nothingInProgress;

  /// No description provided for @pastOrders.
  ///
  /// In en, this message translates to:
  /// **'Past orders'**
  String get pastOrders;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get allCaughtUp;

  /// No description provided for @newCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String newCount(int count);

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrder;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add new address'**
  String get addAddress;

  /// No description provided for @defaultAddress.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultAddress;

  /// No description provided for @noAddresses.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses yet'**
  String get noAddresses;

  /// No description provided for @noAddressesSub.
  ///
  /// In en, this message translates to:
  /// **'Add one now and checkout gets faster.'**
  String get noAddressesSub;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & contact'**
  String get helpTitle;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'CONTACT US'**
  String get contactUs;

  /// No description provided for @callUs.
  ///
  /// In en, this message translates to:
  /// **'Call us'**
  String get callUs;

  /// No description provided for @telegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get telegram;

  /// No description provided for @emailUs.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailUs;

  /// No description provided for @visitShop.
  ///
  /// In en, this message translates to:
  /// **'Visit the shop'**
  String get visitShop;

  /// No description provided for @openHours.
  ///
  /// In en, this message translates to:
  /// **'Open every day, 9:00 - 20:00'**
  String get openHours;

  /// No description provided for @tapToCopy.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy'**
  String get tapToCopy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'{value} copied'**
  String copied(String value);

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'QUESTIONS'**
  String get faq;

  /// No description provided for @faq1q.
  ///
  /// In en, this message translates to:
  /// **'How long does delivery take?'**
  String get faq1q;

  /// No description provided for @faq1a.
  ///
  /// In en, this message translates to:
  /// **'In Phnom Penh we deliver the next day, between 9:00 and 18:00. Delivery is free from \$50.'**
  String get faq1a;

  /// No description provided for @faq2q.
  ///
  /// In en, this message translates to:
  /// **'How can I pay?'**
  String get faq2q;

  /// No description provided for @faq2a.
  ///
  /// In en, this message translates to:
  /// **'Scan the Bakong KHQR with any Cambodian bank app, or pay cash when your order arrives.'**
  String get faq2a;

  /// No description provided for @faq3q.
  ///
  /// In en, this message translates to:
  /// **'Are the figures genuine?'**
  String get faq3q;

  /// No description provided for @faq3a.
  ///
  /// In en, this message translates to:
  /// **'Yes. Every product is official, from makers like Bandai, Good Smile Company and MegaHouse.'**
  String get faq3a;

  /// No description provided for @faq4q.
  ///
  /// In en, this message translates to:
  /// **'What if the box arrives damaged?'**
  String get faq4q;

  /// No description provided for @faq4a.
  ///
  /// In en, this message translates to:
  /// **'Take a photo and contact us within 3 days. We will replace it or give your money back.'**
  String get faq4a;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Figures, plush, model kits and anime cards in Phnom Penh.'**
  String get aboutTagline;

  /// No description provided for @aboutMadeBy.
  ///
  /// In en, this message translates to:
  /// **'A SETEC Institute final project (SU25, Mobile Application).'**
  String get aboutMadeBy;

  /// No description provided for @aboutCredit.
  ///
  /// In en, this message translates to:
  /// **'Product images belong to their respective owners and are used for educational purposes only.'**
  String get aboutCredit;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'km':
      return AppLocalizationsKm();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
