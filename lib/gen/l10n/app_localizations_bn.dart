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
  String get change_language => 'ভাষা পরিবর্তন';

  @override
  String get theme => 'থিম';

  @override
  String get change_theme => 'থিম পরিবর্তন';

  @override
  String get notifications => 'বিজ্ঞপ্তি';

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

  @override
  String get messageRead => 'পঠিত';

  @override
  String get messageSent => 'পাঠানো';

  @override
  String get dateToday => 'আজ';

  @override
  String get dateYesterday => 'গতকাল';

  @override
  String get unreadMessages => 'অপঠিত বার্তা';

  @override
  String get noMessagesYet => 'এখনো কোনো বার্তা নেই';

  @override
  String get editingMessage => 'বার্তা সম্পাদনা';

  @override
  String get scrollToBottom => 'সাম্প্রতিক বার্তায় যান';

  @override
  String get messageDensity => 'বার্তার ঘনত্ব';

  @override
  String get densityCompact => 'সংক্ষিপ্ত';

  @override
  String get densityCozy => 'স্বাভাবিক';

  @override
  String get densityComfortable => 'প্রশস্ত';

  @override
  String get voiceSlideToCancel => 'বাতিলে বামে, লক করতে উপরে সোয়াইপ';

  @override
  String get voiceReleaseToCancel => 'ছাড়লে বাতিল';

  @override
  String get voiceRecordingLocked => 'রেকর্ডিং — শেষ হলে পাঠান চাপুন';

  @override
  String get voicePermissionDenied => 'মাইক্রোফোন অ্যাক্সেস বন্ধ';

  @override
  String get voiceMessage => 'ভয়েস বার্তা';

  @override
  String get attach => 'সংযুক্ত করুন';

  @override
  String get messageHint => 'বার্তা';

  @override
  String get unknownChat => 'অজানা চ্যাট';

  @override
  String get unknownProfile => 'অজানা প্রোফাইল';

  @override
  String get goToChats => 'চ্যাটে যান';

  @override
  String get pageNotFound => 'পেজ পাওয়া যায়নি';

  @override
  String pathDoesNotExist(String path) {
    return '$path নেই';
  }

  @override
  String get retry => 'আবার চেষ্টা';

  @override
  String get clear => 'মুছুন';

  @override
  String get add => 'যোগ করুন';

  @override
  String get save => 'সংরক্ষণ';

  @override
  String get readAll => 'সব পড়া';

  @override
  String get filter => 'ফিল্টার';

  @override
  String get filterAll => 'সব';

  @override
  String get filterUnread => 'শুধু অপঠিত';

  @override
  String get filterRead => 'শুধু পঠিত';

  @override
  String get showAll => 'সব দেখান';

  @override
  String get notificationsLoadFailed => 'বিজ্ঞপ্তি লোড করা যায়নি।';

  @override
  String get profiles => 'মানুষ';

  @override
  String get searchByName => 'নাম দিয়ে খুঁজুন';

  @override
  String get searchByUsername => 'ইউজারনেম দিয়ে খুঁজুন';

  @override
  String get profilesLoadFailed => 'প্রোফাইল লোড করা যায়নি।';

  @override
  String get signInToViewProfile => 'প্রোফাইল দেখতে সাইন ইন করুন';

  @override
  String get signInToEditProfile => 'প্রোফাইল সম্পাদনা করতে সাইন ইন করুন';

  @override
  String get profileAbout => 'পরিচিতি';

  @override
  String get profileSkills => 'দক্ষতা';

  @override
  String get profileContacts => 'যোগাযোগ';

  @override
  String get sendMessageAction => 'বার্তা';

  @override
  String get editProfile => 'প্রোফাইল সম্পাদনা';

  @override
  String get displayName => 'প্রদর্শন নাম';

  @override
  String get specialization => 'বিশেষত্ব';

  @override
  String get bio => 'জীবনী';

  @override
  String get dateOfBirth => 'জন্ম তারিখ';

  @override
  String get addContact => 'যোগাযোগ যোগ করুন';

  @override
  String get contactProvider => 'প্রদানকারী (যেমন telegram)';

  @override
  String get contactHandle => 'যোগাযোগ (যেমন @handle)';

  @override
  String get skillsHint => 'দক্ষতা লিখে এন্টার চাপুন';

  @override
  String get photoLibraryFailed => 'ফটো লাইব্রেরি খোলা যায়নি';

  @override
  String get chats => 'চ্যাট';

  @override
  String get searchChatsAndPeople => 'চ্যাট ও মানুষ খুঁজুন';

  @override
  String get chatsLoadFailed => 'চ্যাট লোড করা যায়নি।';

  @override
  String get noChatsYet => 'এখনো কোনো চ্যাট নেই';

  @override
  String get noChatsYetHint => 'কথা শুরু করলে এখানে দেখা যাবে।';

  @override
  String get newChat => 'নতুন চ্যাট';

  @override
  String get chatTypeDirect => 'সরাসরি';

  @override
  String get chatTypeGroup => 'গ্রুপ';

  @override
  String get chatTypeSuper => 'সুপার';

  @override
  String get chatTypeChannel => 'চ্যানেল';

  @override
  String get chatPublicHintCreate => 'যে কেউ এই চ্যাট খুঁজে যোগ দিতে পারে';

  @override
  String get chatSlowModeSecondsField => 'স্লো মোড (সেকেন্ড)';

  @override
  String get createChat => 'চ্যাট তৈরি করুন';

  @override
  String get membersTitle => 'সদস্যরা';

  @override
  String get membersLoadFailed => 'সদস্য লোড করা যায়নি';

  @override
  String get addMember => 'সদস্য যোগ করুন';

  @override
  String get changeRole => 'ভূমিকা পরিবর্তন';

  @override
  String get banMember => 'নিষিদ্ধ';

  @override
  String get banMemberTitle => 'সদস্য নিষিদ্ধ করুন';

  @override
  String get kickMember => 'সরান';

  @override
  String get banReason => 'কারণ (ঐচ্ছিক)';

  @override
  String get banUntil => 'তারিখ দিন';

  @override
  String get searchPeople => 'মানুষ';

  @override
  String get noPeopleFound => 'কাউকে পাওয়া যায়নি';

  @override
  String get callConnecting => 'সংযোগ হচ্ছে…';

  @override
  String get callJoin => 'কলে যোগ দিন';

  @override
  String get callEnded => 'কল শেষ';

  @override
  String get callRejoin => 'আবার যোগ দিন';

  @override
  String get callLeave => 'ছাড়ুন';

  @override
  String get callTitle => 'কল';

  @override
  String selectedCount(int count) {
    return '$countটি নির্বাচিত';
  }

  @override
  String deleteMessagesTitle(int count) {
    return '$countটি বার্তা মুছবেন?';
  }

  @override
  String get cannotBeUndone => 'এটি ফেরানো যাবে না।';

  @override
  String get chatLoadFailed => 'চ্যাট লোড করা যায়নি';

  @override
  String get attachMedia => 'ছবি ও ভিডিও';

  @override
  String get attachDocument => 'নথি';

  @override
  String get messageForwarded => 'বার্তা ফরোয়ার্ড হয়েছে';

  @override
  String get forwardTo => 'কাকে ফরোয়ার্ড';

  @override
  String get noOtherChats => 'অন্য চ্যাট নেই';

  @override
  String get chatsLoadFailedShort => 'চ্যাট লোড করা যায়নি';

  @override
  String get discard => 'বাতিল করুন';

  @override
  String get reactedTitle => 'প্রতিক্রিয়া';

  @override
  String get noReactionsYet => 'এখনো কেউ এই প্রতিক্রিয়া দেয়নি';

  @override
  String get showMore => 'আরও দেখুন';

  @override
  String get bulkForwarding => 'ফরোয়ার্ড হচ্ছে';

  @override
  String get bulkDeleting => 'মুছে ফেলা হচ্ছে';

  @override
  String bulkProgress(String label, int done, int total) {
    return '$label $done/$total…';
  }

  @override
  String bulkComplete(String label, int total) {
    return '$label সম্পন্ন ($total)';
  }

  @override
  String bulkPartial(int done, int total, int failed, String reason) {
    return '$totalটির মধ্যে $doneটি সফল — $failedটি ব্যর্থ: $reason';
  }

  @override
  String get callTokenUnavailable => 'কল শুরু করা যায়নি';

  @override
  String get loginTitle => 'লগইন';

  @override
  String get emailOrUsername => 'ইমেইল বা ইউজারনেম';

  @override
  String get emailOrUsernameHint => 'you@example.com বা ইউজারনেম';

  @override
  String get passwordHint => 'পাসওয়ার্ড লিখুন';

  @override
  String get logIn => 'লগ ইন';

  @override
  String get username => 'ইউজারনেম';

  @override
  String get usernameHint => '৪-১০০ অক্ষর';

  @override
  String get emailHint => 'ইমেইল লিখুন';

  @override
  String get passwordRule => '৮+ অক্ষর, বড়/ছোট/সংখ্যা/বিশেষ';

  @override
  String get confirmPassword => 'পাসওয়ার্ড নিশ্চিত করুন';

  @override
  String get confirmPasswordHint => 'পাসওয়ার্ড আবার লিখুন';

  @override
  String get signInTitle => 'সাইন ইন';

  @override
  String get backToSignIn => 'সাইন ইনে ফিরুন';

  @override
  String get setNewPassword => 'নতুন পাসওয়ার্ড দিন';

  @override
  String get resetCode => 'রিসেট কোড';

  @override
  String get newPassword => 'নতুন পাসওয়ার্ড';

  @override
  String get confirmNewPassword => 'নতুন পাসওয়ার্ড নিশ্চিত করুন';

  @override
  String get resetPassword => 'পাসওয়ার্ড রিসেট';

  @override
  String get passwordUpdated => 'পাসওয়ার্ড হালনাগাদ হয়েছে — লগইন করুন।';

  @override
  String get sendCode => 'কোড পাঠান';

  @override
  String get haveCodeAlready => 'আমার কাছে কোড আছে';

  @override
  String get resetCodeSent => 'কোডের জন্য ইমেইল দেখুন।';

  @override
  String get verifyEmailTitle => 'ইমেইল যাচাই';

  @override
  String get verifyEmailHint => 'পাঠানো ইমেইলের টোকেন পেস্ট করুন।';

  @override
  String get verificationToken => 'যাচাই টোকেন';

  @override
  String get verify => 'যাচাই';

  @override
  String get resendLimitHint => 'আবার পাঠানো যায় — ঘণ্টায় ৩ বার পর্যন্ত।';

  @override
  String get resendVerification => 'যাচাই ইমেইল আবার পাঠান';

  @override
  String get emailVerified => 'ইমেইল যাচাই হয়েছে';

  @override
  String get verificationSent => 'যাচাই ইমেইল পাঠানো হয়েছে — ইনবক্স দেখুন।';

  @override
  String get browserOpenFailed => 'ব্রাউজার খোলা যায়নি';

  @override
  String continueWith(String provider) {
    return '$provider দিয়ে চালিয়ে যান';
  }

  @override
  String get peopleSearchFailed => 'মানুষ খোঁজা যায়নি';

  @override
  String get startChatFailed => 'এই ব্যক্তির সাথে চ্যাট শুরু করা যায়নি';

  @override
  String get profileLoadFailed => 'এই প্রোফাইল লোড করা যায়নি';

  @override
  String get myProfileLoadFailed => 'আপনার প্রোফাইল লোড করা যায়নি';

  @override
  String get saveChangesFailed => 'পরিবর্তন সংরক্ষণ করা যায়নি';

  @override
  String get avatarUpdateFailed => 'অবতার হালনাগাদ করা যায়নি';

  @override
  String get oauthCancelled => 'সাইন ইন বাতিল হয়েছে';

  @override
  String get oauthCancelledHint =>
      'কিছু বদলায়নি। আবার চেষ্টা করুন বা ইউজারনেম ও পাসওয়ার্ড ব্যবহার করুন।';

  @override
  String get oauthFailed => 'সাইন ইন সম্পূর্ণ করা যায়নি';

  @override
  String get oauthFailedHint => 'বরং ইউজারনেম ও পাসওয়ার্ড দিয়ে সাইন ইন করুন।';

  @override
  String get realtimeRejected => 'এই চ্যাটে লাইভ আপডেট বন্ধ';

  @override
  String get forwardComment => 'মন্তব্য যোগ করুন (ঐচ্ছিক)';

  @override
  String get forwardAction => 'ফরোয়ার্ড';

  @override
  String get banDuration => 'কতক্ষণ';

  @override
  String get banForever => 'স্থায়ীভাবে';

  @override
  String get banUntilDate => 'একটি তারিখ পর্যন্ত';

  @override
  String get banLift => 'নিষেধাজ্ঞা তুলুন';

  @override
  String get banLiftHint =>
      'অতীত তারিখ পাঠায়, সার্ভার একে নিষেধাজ্ঞা প্রত্যাহার হিসেবে পড়ে';

  @override
  String get banPickDate => 'তারিখ বাছুন';

  @override
  String get myDevices => 'আমার ডিভাইস';

  @override
  String get devicesLoadFailed => 'ডিভাইস লোড করা যায়নি।';

  @override
  String get noDevices => 'কোনো সক্রিয় সেশন নেই';

  @override
  String get deviceActive => 'সক্রিয়';

  @override
  String get deviceInactive => 'সাইন আউট';

  @override
  String deviceLastActive(String date) {
    return 'সর্বশেষ সক্রিয়: $date';
  }

  @override
  String get designSystem => 'ডিজাইন সিস্টেম';

  @override
  String get accentColor => 'অ্যাকসেন্ট রঙ';

  @override
  String get chatWallpaper => 'চ্যাটের পটভূমি';

  @override
  String get wallpaperAurora => 'অরোরা';

  @override
  String get wallpaperMesh => 'মেশ';

  @override
  String get wallpaperPlain => 'সাদামাটা';

  @override
  String get textSize => 'লেখার আকার';

  @override
  String get textSizeSmall => 'ছোট';

  @override
  String get textSizeDefault => 'স্বাভাবিক';

  @override
  String get textSizeLarge => 'বড়';

  @override
  String get textSizeExtraLarge => 'অতি বড়';

  @override
  String get resetAppearance => 'চেহারা রিসেট করুন';

  @override
  String get showcaseAccents => 'অ্যাকসেন্ট';

  @override
  String get showcaseNeutrals => 'নিউট্রাল';

  @override
  String get showcaseNeutralsLight => 'হালকা ধাপ';

  @override
  String get showcaseNeutralsDark => 'গাঢ় ধাপ';

  @override
  String get showcaseRadii => 'কোণের ব্যাসার্ধ';

  @override
  String get showcaseSpacing => 'ফাঁক';

  @override
  String get showcaseElevation => 'উচ্চতা';

  @override
  String get showcaseMotion => 'গতি';

  @override
  String get showcaseMotionFast => 'দ্রুত';

  @override
  String get showcaseMotionBase => 'সাধারণ';

  @override
  String get showcaseMotionSlow => 'ধীর';

  @override
  String get showcaseMotionReplay => 'আবার চালান';

  @override
  String get showcaseTypography => 'টাইপোগ্রাফি';

  @override
  String get showcaseTabularFigures => 'সারিবদ্ধ সংখ্যা';

  @override
  String get showcaseBubbles => 'বার্তার বাবল';

  @override
  String get showcaseReactions => 'প্রতিক্রিয়া';

  @override
  String get showcaseAuthors => 'লেখকের রঙ';

  @override
  String get showcaseComponents => 'কম্পোনেন্ট';

  @override
  String get showcaseIncomingSample => 'আগত: উষ্ণ পৃষ্ঠ, একটি সরু রেখা।';

  @override
  String get showcaseStackedSample => 'একই ধারার দ্বিতীয় বার্তা।';

  @override
  String get showcaseOutgoingSample => 'প্রেরিত: অ্যাকসেন্ট গ্রেডিয়েন্ট।';

  @override
  String get messageSending => 'পাঠানো হচ্ছে';

  @override
  String get onlineNow => 'অনলাইন';

  @override
  String userTyping(String name) {
    return '$name লিখছেন…';
  }

  @override
  String severalTyping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count জন লিখছেন…',
      one: '1 জন লিখছেন…',
    );
    return '$_temp0';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি সংযুক্তি',
      one: '1টি সংযুক্তি',
    );
    return '$_temp0';
  }

  @override
  String get contacts => 'পরিচিতি';

  @override
  String get profileSettingsHint => 'আপনার নাম, অবতার ও যোগাযোগের তথ্য';

  @override
  String get noChatSelected => 'কোনো চ্যাট নির্বাচিত হয়নি';

  @override
  String get noChatSelectedHint =>
      'পড়া শুরু করতে তালিকা থেকে একটি কথোপকথন বেছে নিন।';

  @override
  String get newDirectChat => 'নতুন সরাসরি চ্যাট';

  @override
  String get newGroup => 'নতুন গ্রুপ';

  @override
  String get newChannel => 'নতুন চ্যানেল';

  @override
  String get quickActionsHint => 'নতুন কিছু শুরু করুন';

  @override
  String unreadMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি অপঠিত বার্তা',
      one: '১টি অপঠিত বার্তা',
      zero: 'কোনো অপঠিত বার্তা নেই',
    );
    return '$_temp0';
  }

  @override
  String unreadNotificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি নতুন বিজ্ঞপ্তি',
      one: '১টি নতুন বিজ্ঞপ্তি',
      zero: 'কোনো নতুন বিজ্ঞপ্তি নেই',
    );
    return '$_temp0';
  }

  @override
  String get noContactsFound => 'এই নামের সঙ্গে কেউ মেলেনি';

  @override
  String get noContactsFoundHint => 'ছোট নাম বা অন্য বানানে চেষ্টা করুন।';

  @override
  String get noContactsYet => 'দেখানোর মতো এখনো কেউ নেই';

  @override
  String get previewYou => 'আপনি';

  @override
  String get previewPhoto => 'ছবি';

  @override
  String get previewVideo => 'ভিডিও';

  @override
  String get previewVoice => 'ভয়েস বার্তা';

  @override
  String get previewVideoNote => 'ভিডিও বার্তা';

  @override
  String get previewFile => 'ফাইল';

  @override
  String get previewNoText => 'বার্তা';

  @override
  String get draftLabel => 'খসড়া:';

  @override
  String get markAsRead => 'পঠিত হিসেবে চিহ্নিত করুন';

  @override
  String get archiveChat => 'আর্কাইভ';

  @override
  String get unarchiveChat => 'আর্কাইভ থেকে ফেরান';

  @override
  String get pinChat => 'পিন করুন';

  @override
  String get unpinChat => 'পিন সরান';

  @override
  String get muteChat => 'নীরব করুন';

  @override
  String get unmuteChat => 'নীরবতা বন্ধ করুন';

  @override
  String get archivedChats => 'আর্কাইভ করা';

  @override
  String get chatPinnedLabel => 'পিন করা';

  @override
  String get chatMutedLabel => 'বিজ্ঞপ্তি বন্ধ';

  @override
  String get chatArchivedToast => 'চ্যাট আর্কাইভ করা হয়েছে';

  @override
  String get chatDeletedToast => 'চ্যাট মুছে ফেলা হয়েছে';

  @override
  String get undo => 'পূর্বাবস্থায় ফেরান';

  @override
  String get allChatsArchived => 'সবকিছু আর্কাইভ করা আছে';

  @override
  String previewVoiceWithDuration(String duration) {
    return 'ভয়েস বার্তা $duration';
  }

  @override
  String archivedChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি চ্যাট',
      one: '১টি চ্যাট',
    );
    return '$_temp0';
  }

  @override
  String get chatFolders => 'ফোল্ডার';

  @override
  String get chatFoldersAll => 'সব চ্যাট';

  @override
  String get folderPresetUnread => 'অপঠিত';

  @override
  String get folderPresetPersonal => 'ব্যক্তিগত';

  @override
  String get folderPresetGroups => 'গ্রুপ';

  @override
  String get folderPresetChannels => 'চ্যানেল';

  @override
  String get folderPresetNoReply => 'আমার উত্তরের অপেক্ষায়';

  @override
  String get newFolder => 'নতুন ফোল্ডার';

  @override
  String get editFolder => 'ফোল্ডার সম্পাদনা';

  @override
  String get folderName => 'ফোল্ডারের নাম';

  @override
  String get folderIcon => 'আইকন';

  @override
  String get folderRules => 'নিয়ম';

  @override
  String get folderMatchModeTitle => 'একটি চ্যাট এখানে আসবে যখন';

  @override
  String get folderMatchAll => 'এটি সব নিয়ম মেনে চলে';

  @override
  String get folderMatchAny => 'এটি যেকোনো একটি নিয়ম মেনে চলে';

  @override
  String get addFolderRule => 'নিয়ম যোগ করুন';

  @override
  String get removeFolderRule => 'নিয়ম সরান';

  @override
  String get folderRuleChatType => 'চ্যাটের ধরন';

  @override
  String folderRuleChatTypeIn(String types) {
    return 'ধরন $types';
  }

  @override
  String get folderRuleUnread => 'অপঠিত বার্তা আছে';

  @override
  String get folderRuleRead => 'কিছুই অপঠিত নেই';

  @override
  String get folderRulePinned => 'পিন করা আছে';

  @override
  String get folderRuleNotPinned => 'পিন করা নেই';

  @override
  String get folderRuleNoReply => 'আমার উত্তরের অপেক্ষায়';

  @override
  String folderRuleNoReplyDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days দিনের বেশি আমার উত্তরের অপেক্ষায়',
      one: '১ দিনের বেশি আমার উত্তরের অপেক্ষায়',
      zero: 'আমার উত্তরের অপেক্ষায়',
    );
    return '$_temp0';
  }

  @override
  String get folderRuleDaysLabel => 'আমি উত্তর দিইনি যত দিন';

  @override
  String get folderRuleDaysAny => 'যেকোনো';

  @override
  String get folderRuleMember => 'একজন নির্দিষ্ট ব্যক্তি আছেন';

  @override
  String folderRuleMemberNamed(String name) {
    return '$name আছেন';
  }

  @override
  String get folderRulePickPerson => 'একজনকে বাছুন';

  @override
  String get folderRuleNoPeople =>
      'যাদের সঙ্গে চ্যাট আছে, তারা এখানে দেখা যাবে';

  @override
  String get folderRuleMemberLocalNote =>
      'চ্যাট তালিকা যা জানে তার উপরেই মিলিয়ে দেখে: আপনি, লোড হওয়া সদস্য তালিকা, শেষ বার্তার প্রেরক এবং চ্যাটটি যিনি তৈরি করেছেন।';

  @override
  String get deleteFolder => 'ফোল্ডার মুছুন';

  @override
  String get deleteFolderConfirm =>
      'এই ফোল্ডারটি মুছবেন? ভিতরের চ্যাটগুলো যেখানে আছে সেখানেই থাকবে।';

  @override
  String get folderNameRequired => 'ফোল্ডারের একটি নাম দিন';

  @override
  String folderNameTooLong(int count) {
    return 'ফোল্ডারের নাম সর্বোচ্চ $count অক্ষরের';
  }

  @override
  String get folderRulesRequired => 'অন্তত একটি নিয়ম যোগ করুন';

  @override
  String folderLimitReached(int count) {
    return 'আপনি সর্বোচ্চ $countটি ফোল্ডার রাখতে পারেন';
  }

  @override
  String pinLimitReached(int count) {
    return 'কেবল $countটি চ্যাট পিন করা যায়। আগে একটি খুলে দিন।';
  }

  @override
  String get foldersEmpty => 'এখনও কোনো ফোল্ডার নেই';

  @override
  String get foldersEmptyHint =>
      'ফোল্ডার হলো নিয়মের সমষ্টি, তালিকা নয়। চ্যাট নিজে থেকেই আসে ও যায়।';

  @override
  String get folderReadyMade => 'তৈরি করা আছে';

  @override
  String get folderYours => 'আপনার ফোল্ডার';

  @override
  String folderRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি নিয়ম',
      one: '১টি নিয়ম',
    );
    return '$_temp0';
  }

  @override
  String get folderEmptyChats => 'এই ফোল্ডারে কিছু নেই';

  @override
  String get folderEmptyChatsHint => 'নিয়ম মিলে গেলেই চ্যাট এখানে দেখা যাবে।';

  @override
  String get hideFolderTabs => 'ফোল্ডারের সারি লুকান';

  @override
  String get hideFolderTabsHint =>
      'ফোল্ডার থেকে যাবে, কেবল তালিকার উপরের ট্যাবগুলো দেখা যাবে না';

  @override
  String get unarchiveOnNewMessage => 'নতুন বার্তায় ফিরিয়ে আনুন';

  @override
  String get unarchiveOnNewMessageHint =>
      'কেউ লিখলে আর্কাইভ করা চ্যাট তালিকায় ফিরে আসে';

  @override
  String get organizerDeviceOnly =>
      'পিন, আর্কাইভ ও ফোল্ডার কেবল এই ডিভাইসে থাকে, অ্যাকাউন্টের সঙ্গে যায় না।';

  @override
  String get chatPinnedZone => 'পিন করা';

  @override
  String get chatUnarchivedToast => 'তালিকায় ফিরিয়ে আনা হয়েছে';

  @override
  String get searchTabMessages => 'বার্তা';

  @override
  String get searchEverything => 'চ্যাট, মানুষ ও বার্তা খুঁজুন';

  @override
  String get searchRecentQueries => 'সাম্প্রতিক অনুসন্ধান';

  @override
  String get searchRecentChats => 'সম্প্রতি খোলা';

  @override
  String get searchClearHistory => 'মুছুন';

  @override
  String get searchRemoveFromHistory => 'সাম্প্রতিক অনুসন্ধান থেকে সরান';

  @override
  String get searchStartTitle => 'চ্যাট, মানুষ বা বার্তা খুঁজুন';

  @override
  String get searchStartHint =>
      'চ্যাট নাম দিয়ে, মানুষ ইউজারনেম দিয়ে, বার্তা তার লেখা দিয়ে খোঁজা হয়।';

  @override
  String get searchLoadedHistoryOnly => 'লোড হওয়া ইতিহাসে খোঁজা হচ্ছে';

  @override
  String get searchLoadedHistoryExplained =>
      'সার্ভারে বার্তা অনুসন্ধান নেই, তাই এই ডিভাইসে থাকা বার্তাগুলোতেই খোঁজা হয়। আরও পেতে চ্যাট খুলুন।';

  @override
  String get noChatsFound => 'কোনো চ্যাট পাওয়া যায়নি';

  @override
  String get noChatsFoundHint =>
      'ইতিমধ্যে লোড হওয়া চ্যাটগুলোর নাম ও বিবরণ দেখে খোঁজা হয়।';

  @override
  String get noPeopleFoundHint =>
      'অন্য বানানে চেষ্টা করুন, বা ইউজারনেম দিয়ে খুঁজুন।';

  @override
  String get noMessagesFound => 'কোনো বার্তা পাওয়া যায়নি';

  @override
  String get messageSearchFailed => 'বার্তা খোঁজা যায়নি';

  @override
  String searchResultsCapped(int count) {
    return 'প্রথম $countটি মিল দেখানো হচ্ছে';
  }

  @override
  String get searchInChat => 'এই চ্যাটে খুঁজুন';

  @override
  String searchMatchPosition(int current, int total) {
    return '$totalটির মধ্যে $current';
  }

  @override
  String get searchNoMatches => 'কোনো মিল নেই';

  @override
  String get searchOlderMatch => 'আগের মিল';

  @override
  String get searchNewerMatch => 'পরের মিল';

  @override
  String get searchInChatHint => 'এই চ্যাটে খুঁজুন';

  @override
  String get searchChatDescriptionMatch => 'বিবরণে মিলেছে';

  @override
  String get searchOpenChat => 'চ্যাট খুলুন';
}
