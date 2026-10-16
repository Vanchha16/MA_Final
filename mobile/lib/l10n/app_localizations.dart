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

  /// No description provided for @emailUs.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailUs;

  /// No description provided for @openHours.
  ///
  /// In en, this message translates to:
  /// **'Open every day, 9:00 - 20:00'**
  String get openHours;

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

  /// No description provided for @aboutCredit.
  ///
  /// In en, this message translates to:
  /// **'Product images belong to their respective owners and are used for educational purposes only.'**
  String get aboutCredit;

  /// No description provided for @aboutStory.
  ///
  /// In en, this message translates to:
  /// **'Figures, plush, model kits and anime cards, picked by fans for fans. Pay with KHQR and pick up in store or get it delivered.'**
  String get aboutStory;

  /// No description provided for @aboutCity.
  ///
  /// In en, this message translates to:
  /// **'Phnom Penh'**
  String get aboutCity;

  /// No description provided for @aboutWeSell.
  ///
  /// In en, this message translates to:
  /// **'WE SELL'**
  String get aboutWeSell;

  /// No description provided for @aboutMadeByLabel.
  ///
  /// In en, this message translates to:
  /// **'MADE BY'**
  String get aboutMadeByLabel;

  /// No description provided for @aboutSchool.
  ///
  /// In en, this message translates to:
  /// **'SETEC Institute'**
  String get aboutSchool;

  /// No description provided for @aboutProject.
  ///
  /// In en, this message translates to:
  /// **'Final project · SU25 · Mobile Application'**
  String get aboutProject;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get licenses;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsOfUse;

  /// No description provided for @privacy1t.
  ///
  /// In en, this message translates to:
  /// **'What we collect'**
  String get privacy1t;

  /// No description provided for @privacy1b.
  ///
  /// In en, this message translates to:
  /// **'Your name, email, phone number and delivery addresses, so we can deliver your orders.'**
  String get privacy1b;

  /// No description provided for @privacy2t.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get privacy2t;

  /// No description provided for @privacy2b.
  ///
  /// In en, this message translates to:
  /// **'You pay KHQR codes in your own bank app. We never see or keep your bank or card details.'**
  String get privacy2b;

  /// No description provided for @privacy3t.
  ///
  /// In en, this message translates to:
  /// **'How we use it'**
  String get privacy3t;

  /// No description provided for @privacy3b.
  ///
  /// In en, this message translates to:
  /// **'Only to run your orders, send the notifications you turned on and answer you when you contact us. We never sell your data.'**
  String get privacy3b;

  /// No description provided for @privacy4t.
  ///
  /// In en, this message translates to:
  /// **'Your choices'**
  String get privacy4t;

  /// No description provided for @privacy4b.
  ///
  /// In en, this message translates to:
  /// **'Edit your profile and addresses, or turn notifications off, any time in Settings. To delete your account, contact us.'**
  String get privacy4b;

  /// No description provided for @terms1t.
  ///
  /// In en, this message translates to:
  /// **'Orders and prices'**
  String get terms1t;

  /// No description provided for @terms1b.
  ///
  /// In en, this message translates to:
  /// **'Prices are in US dollars. An order is confirmed once its KHQR payment goes through.'**
  String get terms1b;

  /// No description provided for @terms2t.
  ///
  /// In en, this message translates to:
  /// **'Paying in time'**
  String get terms2t;

  /// No description provided for @terms2b.
  ///
  /// In en, this message translates to:
  /// **'A KHQR code is valid for 15 minutes. Unpaid orders are cancelled and the items go back on sale.'**
  String get terms2b;

  /// No description provided for @terms3t.
  ///
  /// In en, this message translates to:
  /// **'Delivery and pickup'**
  String get terms3t;

  /// No description provided for @terms3b.
  ///
  /// In en, this message translates to:
  /// **'Delivery in Phnom Penh is free from \$50 and store pickup is always free. Please check your items when they arrive.'**
  String get terms3b;

  /// No description provided for @terms4t.
  ///
  /// In en, this message translates to:
  /// **'Product photos'**
  String get terms4t;

  /// No description provided for @terms4b.
  ///
  /// In en, this message translates to:
  /// **'Product images belong to their respective owners and are used for educational purposes only.'**
  String get terms4b;

  /// No description provided for @contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactTitle;

  /// No description provided for @helpContactSub.
  ///
  /// In en, this message translates to:
  /// **'Telegram, phone, email or a message'**
  String get helpContactSub;

  /// No description provided for @supportName.
  ///
  /// In en, this message translates to:
  /// **'Anime World support'**
  String get supportName;

  /// No description provided for @supportOnline.
  ///
  /// In en, this message translates to:
  /// **'Online · usually replies in 10 min'**
  String get supportOnline;

  /// No description provided for @supportOffline.
  ///
  /// In en, this message translates to:
  /// **'Closed now · we reply from 9:00'**
  String get supportOffline;

  /// No description provided for @chatTelegram.
  ///
  /// In en, this message translates to:
  /// **'Chat on Telegram'**
  String get chatTelegram;

  /// No description provided for @callShort.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callShort;

  /// No description provided for @visitShort.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get visitShort;

  /// No description provided for @orSendMessage.
  ///
  /// In en, this message translates to:
  /// **'OR SEND US A MESSAGE'**
  String get orSendMessage;

  /// No description provided for @whatAbout.
  ///
  /// In en, this message translates to:
  /// **'What is it about?'**
  String get whatAbout;

  /// No description provided for @topicOrder.
  ///
  /// In en, this message translates to:
  /// **'An order'**
  String get topicOrder;

  /// No description provided for @topicPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get topicPayment;

  /// No description provided for @topicProduct.
  ///
  /// In en, this message translates to:
  /// **'A product'**
  String get topicProduct;

  /// No description provided for @topicOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get topicOther;

  /// No description provided for @noSpecificOrder.
  ///
  /// In en, this message translates to:
  /// **'Not a specific order'**
  String get noSpecificOrder;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String orderNumber(String number);

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Write your message'**
  String get messageHint;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @replyNote.
  ///
  /// In en, this message translates to:
  /// **'We reply in Notifications, usually the same day.'**
  String get replyNote;

  /// No description provided for @messageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent'**
  String get messageSent;

  /// No description provided for @messageSentAbout.
  ///
  /// In en, this message translates to:
  /// **'About order {number}. We\'ll answer in Notifications, usually the same day.'**
  String messageSentAbout(String number);

  /// No description provided for @messageSentGeneral.
  ///
  /// In en, this message translates to:
  /// **'We\'ll answer in Notifications, usually the same day.'**
  String get messageSentGeneral;

  /// No description provided for @sendAnother.
  ///
  /// In en, this message translates to:
  /// **'Send another message'**
  String get sendAnother;

  /// No description provided for @shopLabel.
  ///
  /// In en, this message translates to:
  /// **'SHOP'**
  String get shopLabel;

  /// No description provided for @shopShortAddress.
  ///
  /// In en, this message translates to:
  /// **'#88 St. 315, Toul Kork'**
  String get shopShortAddress;

  /// No description provided for @loginToMessage.
  ///
  /// In en, this message translates to:
  /// **'Log in to send us a message'**
  String get loginToMessage;

  /// No description provided for @loginToMessageSub.
  ///
  /// In en, this message translates to:
  /// **'Telegram, call and email work without an account.'**
  String get loginToMessageSub;

  /// No description provided for @couldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open it, so we copied {value}.'**
  String couldNotOpen(String value);

  /// No description provided for @stageToPay.
  ///
  /// In en, this message translates to:
  /// **'To pay'**
  String get stageToPay;

  /// No description provided for @stageWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get stageWaiting;

  /// No description provided for @stagePacking.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get stagePacking;

  /// No description provided for @stageOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get stageOnTheWay;

  /// No description provided for @stageDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get stageDelivered;

  /// No description provided for @stageCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get stageCancelled;
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
