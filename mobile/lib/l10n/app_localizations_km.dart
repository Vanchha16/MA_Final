// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khmer Central Khmer (`km`).
class AppLocalizationsKm extends AppLocalizations {
  AppLocalizationsKm([String locale = 'km']) : super(locale);

  @override
  String get navHome => 'ទំព័រដើម';

  @override
  String get navCategories => 'ប្រភេទ';

  @override
  String get navWishlist => 'ចំណូលចិត្ត';

  @override
  String get navCart => 'កន្ត្រក';

  @override
  String get navProfile => 'គណនី';

  @override
  String get settingsTitle => 'ការកំណត់';

  @override
  String get appearance => 'រូបរាង';

  @override
  String get themeSystem => 'ប្រព័ន្ធ';

  @override
  String get themeLight => 'ភ្លឺ';

  @override
  String get themeDark => 'ងងឹត';

  @override
  String get language => 'ភាសា';

  @override
  String get notifyMeAbout => 'ជូនដំណឹងខ្ញុំអំពី';

  @override
  String get notifyOrders => 'ការបញ្ជាទិញរបស់ខ្ញុំ';

  @override
  String get notifyOrdersSub => 'បានបង់ កំពុងដឹក បានទទួល';

  @override
  String get notifyOffers => 'ការផ្តល់ជូន និងលេខកូដបញ្ចុះតម្លៃ';

  @override
  String get notifyOffersSub => 'ការលក់ពិសេស និងលេខកូដថ្មី';

  @override
  String get notifyNews => 'ព័ត៌មានហាង';

  @override
  String get notifyNewsSub => 'វិធីបង់ប្រាក់ថ្មី ស៊េរីថ្មី';

  @override
  String get logInToChooseNotifications => 'ចូលគណនី ដើម្បីជ្រើសរើសការជូនដំណឹង';

  @override
  String get more => 'ផ្សេងទៀត';

  @override
  String get myAddresses => 'អាសយដ្ឋានរបស់ខ្ញុំ';

  @override
  String addressesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'រក្សាទុក $count',
      zero: 'មិនទាន់មាន',
    );
    return '$_temp0';
  }

  @override
  String get helpContact => 'ជំនួយ និងទំនាក់ទំនង';

  @override
  String get about => 'អំពី';

  @override
  String version(String version) {
    return 'កំណែ $version';
  }

  @override
  String get profileTitle => 'គណនី';

  @override
  String get myOrders => 'ការបញ្ជាទិញរបស់ខ្ញុំ';

  @override
  String get viewAll => 'មើលទាំងអស់';

  @override
  String get toPay => 'ត្រូវបង់';

  @override
  String get toShip => 'ត្រូវដឹក';

  @override
  String get toReceive => 'ត្រូវទទួល';

  @override
  String get toReview => 'ត្រូវវាយតម្លៃ';

  @override
  String get myWishlist => 'ចំណូលចិត្តរបស់ខ្ញុំ';

  @override
  String get addresses => 'អាសយដ្ឋាន';

  @override
  String get aboutApp => 'អំពីកម្មវិធី';

  @override
  String get logOut => 'ចាកចេញ';

  @override
  String homeGreeting(String name) {
    return 'សួស្តី $name សូមស្វាគមន៍ការត្រឡប់មកវិញ';
  }

  @override
  String get homeGreetingGuest => 'សួស្តី សូមស្វាគមន៍';

  @override
  String get seeAll => 'មើលទាំងអស់';

  @override
  String get allProducts => 'ផលិតផលទាំងអស់';

  @override
  String get categoriesTitle => 'ប្រភេទ';

  @override
  String get shopByAnime => 'ទិញតាមរឿងអានីមេ';

  @override
  String get cartTitle => 'កន្ត្រកទំនិញ';

  @override
  String get goToCheckout => 'ទៅទូទាត់';

  @override
  String get total => 'សរុប';

  @override
  String get clear => 'សម្អាត';

  @override
  String get wishlistTitle => 'ចំណូលចិត្ត';

  @override
  String savedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'រក្សាទុក $count',
    );
    return '$_temp0';
  }

  @override
  String get ordersTitle => 'ការបញ្ជាទិញរបស់ខ្ញុំ';

  @override
  String inProgress(int count) {
    return 'កំពុងដំណើរការ · $count';
  }

  @override
  String get nothingInProgress => 'គ្មានការបញ្ជាទិញកំពុងដំណើរការ';

  @override
  String get pastOrders => 'ការបញ្ជាទិញមុនៗ';

  @override
  String get notificationsTitle => 'ការជូនដំណឹង';

  @override
  String get markAllRead => 'អានទាំងអស់';

  @override
  String get allCaughtUp => 'អានរួចទាំងអស់';

  @override
  String newCount(int count) {
    return 'ថ្មី $count';
  }

  @override
  String get checkoutTitle => 'ទូទាត់';

  @override
  String get placeOrder => 'បញ្ជាទិញ';

  @override
  String get addAddress => 'បន្ថែមអាសយដ្ឋានថ្មី';

  @override
  String get defaultAddress => 'លំនាំដើម';

  @override
  String get noAddresses => 'មិនទាន់មានអាសយដ្ឋាន';

  @override
  String get noAddressesSub => 'បន្ថែមមួយឥឡូវនេះ ដើម្បីទូទាត់កាន់តែលឿន។';

  @override
  String get helpTitle => 'ជំនួយ និងទំនាក់ទំនង';

  @override
  String get contactUs => 'ទាក់ទងមកយើង';

  @override
  String get callUs => 'ទូរស័ព្ទមកយើង';

  @override
  String get telegram => 'តេឡេក្រាម';

  @override
  String get emailUs => 'អ៊ីមែល';

  @override
  String get visitShop => 'មកកាន់ហាង';

  @override
  String get openHours => 'បើករៀងរាល់ថ្ងៃ ម៉ោង 9:00 - 20:00';

  @override
  String get tapToCopy => 'ចុចដើម្បីចម្លង';

  @override
  String copied(String value) {
    return 'បានចម្លង $value';
  }

  @override
  String get faq => 'សំណួរ';

  @override
  String get faq1q => 'តើការដឹកជញ្ជូនចំណាយពេលប៉ុន្មាន?';

  @override
  String get faq1a =>
      'នៅភ្នំពេញ យើងដឹកជូនថ្ងៃបន្ទាប់ ចន្លោះម៉ោង 9:00 ដល់ 18:00។ ដឹកឥតគិតថ្លៃ ចាប់ពី \$50 ឡើងទៅ។';

  @override
  String get faq2q => 'តើខ្ញុំអាចបង់ប្រាក់ដោយរបៀបណា?';

  @override
  String get faq2a =>
      'ស្កេន Bakong KHQR ជាមួយកម្មវិធីធនាគារណាមួយនៅកម្ពុជា ឬបង់ប្រាក់សុទ្ធពេលទទួលទំនិញ។';

  @override
  String get faq3q => 'តើរូបចម្លាក់ទាំងនេះជារបស់ពិតមែនទេ?';

  @override
  String get faq3a =>
      'ពិតប្រាកដ។ ផលិតផលទាំងអស់សុទ្ធតែជារបស់ផ្លូវការ ពីក្រុមហ៊ុនដូចជា Bandai, Good Smile Company និង MegaHouse។';

  @override
  String get faq4q => 'ប្រសិនបើប្រអប់ខូចពេលដឹកជញ្ជូន?';

  @override
  String get faq4a =>
      'ថតរូបទុក ហើយទាក់ទងមកយើងក្នុងរយៈពេល 3 ថ្ងៃ។ យើងនឹងប្តូរថ្មី ឬសងប្រាក់វិញ។';

  @override
  String get aboutTitle => 'អំពី';

  @override
  String get aboutTagline =>
      'រូបចម្លាក់ តុក្កតា ម៉ូដែល និងកាតអានីមេ នៅភ្នំពេញ។';

  @override
  String get aboutMadeBy =>
      'គម្រោងបញ្ចប់ការសិក្សា វិទ្យាស្ថាន SETEC (SU25, Mobile Application)។';

  @override
  String get aboutCredit =>
      'រូបភាពផលិតផលជាកម្មសិទ្ធិរបស់ម្ចាស់រៀងៗខ្លួន ហើយប្រើសម្រាប់គោលបំណងអប់រំតែប៉ុណ្ណោះ។';
}
