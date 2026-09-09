// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'Flutter Riverpod ক্লিন আর্কিটেকচার';

  @override
  String get welcomeMessage => 'Flutter Riverpod ক্লিন আর্কিটেকচারে স্বাগতম';

  @override
  String get home => 'হোম';

  @override
  String get settings => 'সেটিংস';

  @override
  String get profile => 'প্রোফাইল';

  @override
  String get darkMode => 'ডার্ক মোড';

  @override
  String get lightMode => 'লাইট মোড';

  @override
  String get systemMode => 'সিস্টেম মোড';

  @override
  String get language => 'ভাষা';

  @override
  String get change_language => 'Change application language';

  @override
  String get theme => 'Theme';

  @override
  String get change_theme => 'Change application theme';

  @override
  String get notifications => 'Notifications';

  @override
  String get notification_settings => 'Configure notification preferences';

  @override
  String get localization_demo => 'Localization Demo';

  @override
  String get localization_demo_description =>
      'View localization features in action';

  @override
  String get language_settings => 'Language Settings';

  @override
  String get select_your_language => 'Select your preferred language';

  @override
  String get language_explanation =>
      'The selected language will be applied across the entire application';

  @override
  String get localization_assets_demo => 'Localization & Assets Demo';

  @override
  String get current_language => 'Current Language';

  @override
  String get language_code => 'Language code';

  @override
  String get language_name => 'Language name';

  @override
  String get formatting_examples => 'Formatting Examples';

  @override
  String get date_full => 'Date (full)';

  @override
  String get date_short => 'Date (short)';

  @override
  String get time => 'Time';

  @override
  String get currency => 'Currency';

  @override
  String get percent => 'Percent';

  @override
  String get localized_assets => 'Localized Assets';

  @override
  String get localized_assets_explanation =>
      'This section demonstrates how to load different assets based on the selected language. Images, audio, and other resources can be language-specific.';

  @override
  String get image_example => 'Localized Image Example';

  @override
  String get welcome_image_caption =>
      'This image is loaded based on your selected language';

  @override
  String get common_image_example => 'Common Image Example';

  @override
  String get common_image_caption =>
      'This image is the same across all languages';

  @override
  String get logout => 'লগআউট';

  @override
  String get login => 'লগইন';

  @override
  String get email => 'ইমেইল';

  @override
  String get password => 'পাসওয়ার্ড';

  @override
  String get signIn => 'সাইন ইন';

  @override
  String get register => 'রেজিস্টার';

  @override
  String get forgotPassword => 'পাসওয়ার্ড ভুলে গেছেন?';

  @override
  String get errorOccurred => 'একটি ত্রুটি ঘটেছে';

  @override
  String get tryAgain => 'আবার চেষ্টা করুন';

  @override
  String greeting(String name) {
    return 'হ্যালো, $name!';
  }

  @override
  String itemCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি আইটেম',
      one: '১টি আইটেম',
      zero: 'কোন আইটেম নেই',
    );
    return '$_temp0';
  }

  @override
  String lastUpdated(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'সর্বশেষ আপডেট: $dateString';
  }

  @override
  String get browsePeople => 'লোকজন';

  @override
  String get chatDirect => 'সরাসরি চ্যাট';

  @override
  String get chatGroup => 'গ্রুপ';

  @override
  String get chatSupergroup => 'সুপারগ্রুপ';

  @override
  String get chatChannel => 'চ্যানেল';

  @override
  String get chatFallbackTitle => 'চ্যাট';

  @override
  String membersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count জন সদস্য',
      one: '১ জন সদস্য',
      zero: 'কোন সদস্য নেই',
    );
    return '$_temp0';
  }

  @override
  String get attachmentProcessing => 'প্রক্রিয়াকরণ…';

  @override
  String get attachmentFailed => 'আপলোড ব্যর্থ';

  @override
  String get attachmentOpenFailed => 'এই ফাইলটি খোলা যায়নি';

  @override
  String get imageLoadFailed => 'ছবি অনুপলব্ধ';

  @override
  String get close => 'বন্ধ';

  @override
  String get addReaction => 'প্রতিক্রিয়া যোগ করুন';

  @override
  String get reactionsDisabled => 'এই চ্যাটে প্রতিক্রিয়া বন্ধ';

  @override
  String reactionLimitReached(Object limit) {
    return 'প্রতি বার্তায় সর্বোচ্চ $limitটি প্রতিক্রিয়া যোগ করতে পারেন';
  }

  @override
  String get messageNotFound => 'সেই বার্তাটি আর নেই';

  @override
  String get chatInfo => 'চ্যাট তথ্য';

  @override
  String get chatName => 'নাম';

  @override
  String get chatDescription => 'বিবরণ';

  @override
  String get chatPublic => 'পাবলিক চ্যাট';

  @override
  String get chatPublicHint => 'লিঙ্ক থাকলে যে কেউ যোগ দিতে পারে';

  @override
  String get chatAdminOnly => 'শুধু অ্যাডমিন';

  @override
  String get chatAdminOnlyHint => 'শুধু অ্যাডমিনরা পোস্ট করতে পারে';

  @override
  String get chatSlowMode => 'স্লো মোড';

  @override
  String get chatSlowModeOff => 'বন্ধ';

  @override
  String chatSlowModeSeconds(Object seconds) {
    return 'বার্তার মধ্যে $seconds সেকেন্ড';
  }

  @override
  String get chatReactionsMode => 'প্রতিক্রিয়া';

  @override
  String get chatReactionsAll => 'সবাই, যেকোনো ইমোজি';

  @override
  String get chatReactionsSome => 'শুধু নির্বাচিত ইমোজি';

  @override
  String get chatReactionsNone => 'বন্ধ';

  @override
  String get leaveChat => 'চ্যাট ছাড়ুন';

  @override
  String get leaveChatConfirm => 'এই চ্যাট ছাড়বেন? আপনি আর বার্তা পাবেন না।';

  @override
  String get leaveChatOwnerBlocked =>
      'চ্যাটের নির্মাতা ছাড়তে পারেন না — বরং চ্যাটটি মুছুন।';

  @override
  String get deleteChat => 'চ্যাট মুছুন';

  @override
  String get deleteChatConfirm =>
      'সবার জন্য এই চ্যাট মুছবেন? এটি ফেরানো যাবে না।';

  @override
  String get saveChanges => 'সংরক্ষণ';

  @override
  String get cancel => 'বাতিল';

  @override
  String get chatSettingsSaved => 'চ্যাট আপডেট হয়েছে';

  @override
  String get viewMembers => 'সদস্যরা';

  @override
  String get messageEdited => 'সম্পাদিত';

  @override
  String get messageReply => 'উত্তর';

  @override
  String get messageForward => 'ফরোয়ার্ড';

  @override
  String get messageEdit => 'সম্পাদনা';

  @override
  String get messageDelete => 'মুছুন';

  @override
  String get messageSelect => 'নির্বাচন';

  @override
  String get backToLatest => 'সাম্প্রতিক বার্তায় ফিরুন';
}
