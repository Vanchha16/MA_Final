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
  String get emailUs => 'Email';

  @override
  String get openHours => 'Open every day, 9:00 - 20:00';

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
  String get aboutCredit =>
      'Product images belong to their respective owners and are used for educational purposes only.';

  @override
  String get aboutStory =>
      'Figures, plush, model kits and anime cards, picked by fans for fans. Pay with KHQR and pick up in store or get it delivered.';

  @override
  String get aboutCity => 'Phnom Penh';

  @override
  String get aboutWeSell => 'WE SELL';

  @override
  String get aboutMadeByLabel => 'MADE BY';

  @override
  String get aboutSchool => 'SETEC Institute';

  @override
  String get aboutProject => 'Final project · SU25 · Mobile Application';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get privacy1t => 'What we collect';

  @override
  String get privacy1b =>
      'Your name, email, phone number and delivery addresses, so we can deliver your orders.';

  @override
  String get privacy2t => 'Payments';

  @override
  String get privacy2b =>
      'You pay KHQR codes in your own bank app. We never see or keep your bank or card details.';

  @override
  String get privacy3t => 'How we use it';

  @override
  String get privacy3b =>
      'Only to run your orders, send the notifications you turned on and answer you when you contact us. We never sell your data.';

  @override
  String get privacy4t => 'Your choices';

  @override
  String get privacy4b =>
      'Edit your profile and addresses, or turn notifications off, any time in Settings. To delete your account, contact us.';

  @override
  String get terms1t => 'Orders and prices';

  @override
  String get terms1b =>
      'Prices are in US dollars. An order is confirmed once its KHQR payment goes through.';

  @override
  String get terms2t => 'Paying in time';

  @override
  String get terms2b =>
      'A KHQR code is valid for 15 minutes. Unpaid orders are cancelled and the items go back on sale.';

  @override
  String get terms3t => 'Delivery and pickup';

  @override
  String get terms3b =>
      'Delivery in Phnom Penh is free from \$50 and store pickup is always free. Please check your items when they arrive.';

  @override
  String get terms4t => 'Product photos';

  @override
  String get terms4b =>
      'Product images belong to their respective owners and are used for educational purposes only.';

  @override
  String get contactTitle => 'Contact us';

  @override
  String get helpContactSub => 'Telegram, phone, email or a message';

  @override
  String get supportName => 'Anime World support';

  @override
  String get supportOnline => 'Online · usually replies in 10 min';

  @override
  String get supportOffline => 'Closed now · we reply from 9:00';

  @override
  String get chatTelegram => 'Chat on Telegram';

  @override
  String get callShort => 'Call';

  @override
  String get visitShort => 'Visit';

  @override
  String get orSendMessage => 'OR SEND US A MESSAGE';

  @override
  String get whatAbout => 'What is it about?';

  @override
  String get topicOrder => 'An order';

  @override
  String get topicPayment => 'Payment';

  @override
  String get topicProduct => 'A product';

  @override
  String get topicOther => 'Something else';

  @override
  String get noSpecificOrder => 'Not a specific order';

  @override
  String orderNumber(String number) {
    return 'Order $number';
  }

  @override
  String get messageHint => 'Write your message';

  @override
  String get sendMessage => 'Send message';

  @override
  String get sending => 'Sending...';

  @override
  String get replyNote => 'We reply in Notifications, usually the same day.';

  @override
  String get messageSent => 'Message sent';

  @override
  String messageSentAbout(String number) {
    return 'About order $number. We\'ll answer in Notifications, usually the same day.';
  }

  @override
  String get messageSentGeneral =>
      'We\'ll answer in Notifications, usually the same day.';

  @override
  String get sendAnother => 'Send another message';

  @override
  String get shopLabel => 'SHOP';

  @override
  String get shopShortAddress => '#88 St. 315, Toul Kork';

  @override
  String get loginToMessage => 'Log in to send us a message';

  @override
  String get loginToMessageSub =>
      'Telegram, call and email work without an account.';

  @override
  String couldNotOpen(String value) {
    return 'Could not open it, so we copied $value.';
  }

  @override
  String get stageToPay => 'To pay';

  @override
  String get stageWaiting => 'Waiting';

  @override
  String get stagePacking => 'Packing';

  @override
  String get stageOnTheWay => 'On the way';

  @override
  String get stageDelivered => 'Delivered';

  @override
  String get stageCancelled => 'Cancelled';

  @override
  String get adminTitle => 'Shop admin';

  @override
  String get adminEntrySub => 'Orders, products and customers';

  @override
  String goodMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String goodAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String goodEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get adminShop => 'Shop';

  @override
  String get revenuePaid => 'Revenue (paid)';

  @override
  String thisWeek(String amount) {
    return '+ $amount this week';
  }

  @override
  String get today => 'Today';

  @override
  String get toHandle => 'To handle';

  @override
  String get lowStock => 'Low stock';

  @override
  String get messagesLabel => 'Messages';

  @override
  String get liveActivity => 'Live activity';

  @override
  String get noActivity => 'Nothing yet. New orders and messages show up here.';

  @override
  String get actConfirm => 'Confirm';

  @override
  String get actShip => 'Ship it';

  @override
  String get actReply => 'Reply';

  @override
  String get actRestock => 'Restock';

  @override
  String get actRefund => 'Mark refunded';

  @override
  String get doneRefunded => 'Refunded';

  @override
  String get refundAskTitle => 'Mark as refunded?';

  @override
  String refundAskMessage(String order) {
    return 'Only after you have sent the money for $order back to the customer. They get a notification.';
  }

  @override
  String get doneConfirmed => 'Confirmed · customer told';

  @override
  String get doneShipped => 'Shipped · customer told';

  @override
  String get doneReplied => 'Replied';

  @override
  String doneRestocked(int count) {
    return '$count in stock';
  }

  @override
  String get replyTitle => 'Reply to the customer';

  @override
  String get replyHint => 'Your answer goes to their Notifications';

  @override
  String get sendReply => 'Send reply';

  @override
  String get restockTitle => 'How many are in stock now?';

  @override
  String get saveStock => 'Save stock';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navOrders => 'Orders';

  @override
  String get navProducts => 'Products';

  @override
  String get navMore => 'More';

  @override
  String get addProduct => 'Add product';

  @override
  String get adminComingSoon => 'This part of the admin comes next.';
}
