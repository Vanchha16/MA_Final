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
  String get emailUs => 'អ៊ីមែល';

  @override
  String get openHours => 'បើករៀងរាល់ថ្ងៃ ម៉ោង 9:00 - 20:00';

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
  String get aboutCredit =>
      'រូបភាពផលិតផលជាកម្មសិទ្ធិរបស់ម្ចាស់រៀងៗខ្លួន ហើយប្រើសម្រាប់គោលបំណងអប់រំតែប៉ុណ្ណោះ។';

  @override
  String get aboutStory =>
      'រូបចម្លាក់ តុក្កតា ម៉ូដែល និងកាតអានីមេ ជ្រើសរើសដោយអ្នកចូលចិត្ត សម្រាប់អ្នកចូលចិត្ត។ បង់ប្រាក់តាម KHQR ហើយមកយកនៅហាង ឬឱ្យយើងដឹកជូន។';

  @override
  String get aboutCity => 'ភ្នំពេញ';

  @override
  String get aboutWeSell => 'យើងលក់';

  @override
  String get aboutMadeByLabel => 'បង្កើតដោយ';

  @override
  String get aboutSchool => 'វិទ្យាស្ថាន SETEC';

  @override
  String get aboutProject =>
      'គម្រោងបញ្ចប់ការសិក្សា · SU25 · Mobile Application';

  @override
  String get licenses => 'អាជ្ញាប័ណ្ណកូដបើកចំហ';

  @override
  String get privacyPolicy => 'គោលការណ៍ឯកជនភាព';

  @override
  String get termsOfUse => 'លក្ខខណ្ឌប្រើប្រាស់';

  @override
  String get privacy1t => 'អ្វីដែលយើងប្រមូល';

  @override
  String get privacy1b =>
      'ឈ្មោះ អ៊ីមែល លេខទូរស័ព្ទ និងអាសយដ្ឋានដឹកជញ្ជូនរបស់អ្នក ដើម្បីដឹកការបញ្ជាទិញជូនអ្នក។';

  @override
  String get privacy2t => 'ការបង់ប្រាក់';

  @override
  String get privacy2b =>
      'អ្នកបង់កូដ KHQR នៅក្នុងកម្មវិធីធនាគាររបស់អ្នកផ្ទាល់។ យើងមិនដែលឃើញ ឬរក្សាទុកព័ត៌មានធនាគារ ឬកាតរបស់អ្នកទេ។';

  @override
  String get privacy3t => 'របៀបដែលយើងប្រើ';

  @override
  String get privacy3b =>
      'សម្រាប់តែដំណើរការការបញ្ជាទិញ ផ្ញើការជូនដំណឹងដែលអ្នកបានបើក និងឆ្លើយតបពេលអ្នកទាក់ទងមកយើង។ យើងមិនដែលលក់ទិន្នន័យរបស់អ្នកទេ។';

  @override
  String get privacy4t => 'ជម្រើសរបស់អ្នក';

  @override
  String get privacy4b =>
      'កែប្រវត្តិរូប និងអាសយដ្ឋាន ឬបិទការជូនដំណឹង បានគ្រប់ពេលក្នុងការកំណត់។ ដើម្បីលុបគណនី សូមទាក់ទងមកយើង។';

  @override
  String get terms1t => 'ការបញ្ជាទិញ និងតម្លៃ';

  @override
  String get terms1b =>
      'តម្លៃគិតជាដុល្លារអាមេរិក។ ការបញ្ជាទិញត្រូវបានបញ្ជាក់ នៅពេលការបង់ប្រាក់ KHQR ជោគជ័យ។';

  @override
  String get terms2t => 'បង់ប្រាក់ទាន់ពេល';

  @override
  String get terms2b =>
      'កូដ KHQR មានសុពលភាព ១៥ នាទី។ ការបញ្ជាទិញដែលមិនបានបង់ នឹងត្រូវលុបចោល ហើយទំនិញត្រឡប់មកលក់វិញ។';

  @override
  String get terms3t => 'ការដឹកជញ្ជូន និងការមកយក';

  @override
  String get terms3b =>
      'ដឹកជញ្ជូនក្នុងភ្នំពេញ ឥតគិតថ្លៃចាប់ពី \$50 ហើយមកយកនៅហាង ឥតគិតថ្លៃជានិច្ច។ សូមពិនិត្យទំនិញពេលទទួលបាន។';

  @override
  String get terms4t => 'រូបភាពផលិតផល';

  @override
  String get terms4b =>
      'រូបភាពផលិតផលជាកម្មសិទ្ធិរបស់ម្ចាស់រៀងៗខ្លួន ហើយប្រើសម្រាប់គោលបំណងអប់រំតែប៉ុណ្ណោះ។';

  @override
  String get contactTitle => 'ទាក់ទងយើង';

  @override
  String get helpContactSub => 'Telegram ទូរស័ព្ទ អ៊ីមែល ឬផ្ញើសារ';

  @override
  String get supportName => 'ផ្នែកជំនួយ Anime World';

  @override
  String get supportOnline => 'អនឡាញ · ជាធម្មតាឆ្លើយតបក្នុង ១០ នាទី';

  @override
  String get supportOffline => 'បិទហើយ · យើងឆ្លើយតបចាប់ពីម៉ោង ៩:០០';

  @override
  String get chatTelegram => 'ជជែកតាម Telegram';

  @override
  String get callShort => 'ហៅ';

  @override
  String get visitShort => 'មកហាង';

  @override
  String get orSendMessage => 'ឬផ្ញើសារមកយើង';

  @override
  String get whatAbout => 'តើវាអំពីអ្វី?';

  @override
  String get topicOrder => 'ការបញ្ជាទិញ';

  @override
  String get topicPayment => 'ការបង់ប្រាក់';

  @override
  String get topicProduct => 'ផលិតផល';

  @override
  String get topicOther => 'ផ្សេងទៀត';

  @override
  String get noSpecificOrder => 'មិនមែនការបញ្ជាទិញជាក់លាក់';

  @override
  String orderNumber(String number) {
    return 'ការបញ្ជាទិញ $number';
  }

  @override
  String get messageHint => 'សរសេរសាររបស់អ្នក';

  @override
  String get sendMessage => 'ផ្ញើសារ';

  @override
  String get sending => 'កំពុងផ្ញើ...';

  @override
  String get replyNote => 'យើងឆ្លើយតបក្នុងការជូនដំណឹង ជាធម្មតានៅថ្ងៃដដែល។';

  @override
  String get messageSent => 'បានផ្ញើសារ';

  @override
  String messageSentAbout(String number) {
    return 'អំពីការបញ្ជាទិញ $number។ យើងនឹងឆ្លើយតបក្នុងការជូនដំណឹង ជាធម្មតានៅថ្ងៃដដែល។';
  }

  @override
  String get messageSentGeneral =>
      'យើងនឹងឆ្លើយតបក្នុងការជូនដំណឹង ជាធម្មតានៅថ្ងៃដដែល។';

  @override
  String get sendAnother => 'ផ្ញើសារមួយទៀត';

  @override
  String get shopLabel => 'ហាង';

  @override
  String get shopShortAddress => '#88 ផ្លូវ 315 ទួលគោក';

  @override
  String get loginToMessage => 'ចូលគណនីដើម្បីផ្ញើសារមកយើង';

  @override
  String get loginToMessageSub =>
      'Telegram ការហៅ និងអ៊ីមែល ប្រើបានដោយមិនចាំបាច់មានគណនី។';

  @override
  String couldNotOpen(String value) {
    return 'មិនអាចបើកបានទេ ដូច្នេះយើងបានចម្លង $value។';
  }

  @override
  String get stageToPay => 'ត្រូវបង់';

  @override
  String get stageWaiting => 'កំពុងរង់ចាំ';

  @override
  String get stagePacking => 'កំពុងវេចខ្ចប់';

  @override
  String get stageOnTheWay => 'កំពុងដឹកជញ្ជូន';

  @override
  String get stageDelivered => 'បានដឹកដល់';

  @override
  String get stageReady => 'រួចរាល់សម្រាប់មកយក';

  @override
  String get stagePickedUp => 'បានមកយកហើយ';

  @override
  String get stageCancelled => 'បានលុបចោល';

  @override
  String get adminTitle => 'អ្នកគ្រប់គ្រងហាង';

  @override
  String get adminEntrySub => 'ការបញ្ជាទិញ ផលិតផល និងអតិថិជន';

  @override
  String goodMorning(String name) {
    return 'អរុណសួស្តី $name';
  }

  @override
  String goodAfternoon(String name) {
    return 'ទិវាសួស្តី $name';
  }

  @override
  String goodEvening(String name) {
    return 'សាយ័ណ្ហសួស្តី $name';
  }

  @override
  String get adminShop => 'ហាង';

  @override
  String get revenuePaid => 'ចំណូល (បានបង់)';

  @override
  String thisWeek(String amount) {
    return '+ $amount សប្តាហ៍នេះ';
  }

  @override
  String get today => 'ថ្ងៃនេះ';

  @override
  String get toHandle => 'ត្រូវដោះស្រាយ';

  @override
  String get lowStock => 'ស្តុកតិច';

  @override
  String get messagesLabel => 'សារ';

  @override
  String get liveActivity => 'សកម្មភាពផ្ទាល់';

  @override
  String get noActivity =>
      'មិនទាន់មានទេ។ ការបញ្ជាទិញ និងសារថ្មីនឹងបង្ហាញនៅទីនេះ។';

  @override
  String get actConfirm => 'បញ្ជាក់';

  @override
  String get actShip => 'ដឹកចេញ';

  @override
  String get actReady => 'រួចរាល់';

  @override
  String get actReply => 'ឆ្លើយតប';

  @override
  String get actRestock => 'បន្ថែមស្តុក';

  @override
  String get actRefund => 'បានសងប្រាក់វិញ';

  @override
  String get doneRefunded => 'បានសងប្រាក់វិញ';

  @override
  String get refundAskTitle => 'កត់ថាបានសងប្រាក់វិញ?';

  @override
  String refundAskMessage(String order) {
    return 'ធ្វើតែក្រោយពេលអ្នកបានផ្ញើប្រាក់សម្រាប់ $order ត្រឡប់ទៅអតិថិជនវិញ។ ពួកគេនឹងទទួលបានការជូនដំណឹង។';
  }

  @override
  String get doneConfirmed => 'បានបញ្ជាក់ · បានប្រាប់អតិថិជន';

  @override
  String get doneShipped => 'បានដឹកចេញ · បានប្រាប់អតិថិជន';

  @override
  String get doneReady => 'រួចរាល់ · បានប្រាប់អតិថិជន';

  @override
  String get doneReplied => 'បានឆ្លើយតប';

  @override
  String doneRestocked(int count) {
    return 'មានស្តុក $count';
  }

  @override
  String get replyTitle => 'ឆ្លើយតបអតិថិជន';

  @override
  String get replyHint => 'ចម្លើយរបស់អ្នកនឹងទៅកាន់ការជូនដំណឹងរបស់គេ';

  @override
  String get sendReply => 'ផ្ញើចម្លើយ';

  @override
  String get restockTitle => 'ឥឡូវមានស្តុកប៉ុន្មាន?';

  @override
  String get saveStock => 'រក្សាទុកស្តុក';

  @override
  String get navDashboard => 'ផ្ទាំងគ្រប់គ្រង';

  @override
  String get navOrders => 'ការបញ្ជាទិញ';

  @override
  String get navProducts => 'ផលិតផល';

  @override
  String get navMore => 'ច្រើនទៀត';

  @override
  String get addProduct => 'បន្ថែមផលិតផល';

  @override
  String get adminComingSoon => 'ផ្នែកនេះនឹងមកដល់បន្ទាប់។';
}
