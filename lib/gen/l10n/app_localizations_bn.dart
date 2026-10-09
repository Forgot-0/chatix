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
  String get notification_settings => 'বিজ্ঞপ্তির পছন্দ ঠিক করুন';

  @override
  String get localization_demo => 'লোকালাইজেশন ডেমো';

  @override
  String get localization_demo_description =>
      'লোকালাইজেশন কীভাবে কাজ করে দেখুন';

  @override
  String get language_settings => 'ভাষার সেটিংস';

  @override
  String get select_your_language => 'আপনার ভাষা বেছে নিন';

  @override
  String get language_explanation =>
      'বেছে নেওয়া ভাষা পুরো অ্যাপে প্রযোজ্য হবে';

  @override
  String get localization_assets_demo => 'লোকালাইজেশন ও অ্যাসেট';

  @override
  String get current_language => 'বর্তমান ভাষা';

  @override
  String get language_code => 'ভাষার কোড';

  @override
  String get language_name => 'ভাষার নাম';

  @override
  String get formatting_examples => 'ফরম্যাটের উদাহরণ';

  @override
  String get date_full => 'তারিখ (পূর্ণ)';

  @override
  String get date_short => 'তারিখ (সংক্ষিপ্ত)';

  @override
  String get time => 'সময়';

  @override
  String get currency => 'মুদ্রা';

  @override
  String get percent => 'শতাংশ';

  @override
  String get localized_assets => 'লোকালাইজ করা অ্যাসেট';

  @override
  String get localized_assets_explanation =>
      'এই অংশে দেখানো হয়েছে কীভাবে ভাষা অনুযায়ী আলাদা অ্যাসেট লোড করা যায়। ছবি, অডিও ও অন্যান্য ফাইল ভাষাভেদে আলাদা হতে পারে।';

  @override
  String get image_example => 'লোকালাইজ করা ছবির উদাহরণ';

  @override
  String get welcome_image_caption => 'এই ছবিটি আপনার ভাষা অনুযায়ী লোড হয়';

  @override
  String get common_image_example => 'সাধারণ ছবির উদাহরণ';

  @override
  String get common_image_caption => 'এই ছবিটি সব ভাষাতেই এক';

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
  String get messageReact => 'প্রতিক্রিয়া';

  @override
  String get messageCopy => 'লেখা কপি করুন';

  @override
  String get messageCopied => 'কপি হয়েছে';

  @override
  String get linkOpenFailed => 'এই লিংক খোলার মতো কিছু নেই';

  @override
  String get messageDetails => 'বিস্তারিত';

  @override
  String replyingTo(String author) {
    return '$author-কে উত্তর';
  }

  @override
  String forwardedFrom(String author) {
    return '$author থেকে ফরওয়ার্ড';
  }

  @override
  String get forwardedMessage => 'ফরওয়ার্ড করা বার্তা';

  @override
  String get detailsSentAt => 'পাঠানো হয়েছে';

  @override
  String get detailsAuthor => 'থেকে';

  @override
  String get detailsSequence => 'চ্যাটে ক্রমিক';

  @override
  String get detailsEdited => 'সম্পাদিত';

  @override
  String get detailsEditedYes => 'হ্যাঁ';

  @override
  String get detailsDelivery => 'ডেলিভারি';

  @override
  String get detailsAttachments => 'সংযুক্তি';

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
  String newMessagesBelow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'নিচে $countটি নতুন বার্তা',
      one: 'নিচে ১টি নতুন বার্তা',
      zero: 'নতুন বার্তা নেই',
    );
    return '$_temp0';
  }

  @override
  String get connectionReconnecting => 'আবার যুক্ত হচ্ছে…';

  @override
  String get connectionOffline => 'অফলাইন — রিফ্রেশ করতে টানুন';

  @override
  String get attachmentFallbackLabel => 'সংযুক্তি';

  @override
  String get composerJoinToSend => 'বার্তা পাঠাতে এই চ্যাটে যোগ দিন';

  @override
  String get composerBanned => 'এই চ্যাটে আপনি নিষিদ্ধ';

  @override
  String get composerMuted => 'এই চ্যাটে আপনি লিখতে পারবেন না';

  @override
  String get composerAdminsOnly => 'এই চ্যাটে শুধু অ্যাডমিনরা লিখতে পারেন';

  @override
  String get composerNoPermission => 'এখানে বার্তা পাঠানোর অনুমতি আপনার নেই';

  @override
  String attachmentSelection(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি ফাইল',
      one: '১টি ফাইল',
    );
    return '$_temp0, $size';
  }

  @override
  String get attachmentReady => 'পাঠানোর জন্য প্রস্তুত';

  @override
  String attachMediaLimits(int count, String size) {
    return 'সর্বোচ্চ $countটি, প্রতিটি $size পর্যন্ত';
  }

  @override
  String attachDocumentLimits(String size) {
    return 'একটি ফাইল, $size পর্যন্ত';
  }

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
  String get voiceLimitReached => 'সর্বোচ্চ দৈর্ঘ্যে পৌঁছেছে';

  @override
  String get voicePermissionDenied => 'মাইক্রোফোন অ্যাক্সেস বন্ধ';

  @override
  String get voiceMessage => 'ভয়েস বার্তা';

  @override
  String get voicePlay => 'ভয়েস মেসেজ চালান';

  @override
  String get voicePause => 'ভয়েস মেসেজ থামান';

  @override
  String get voiceUnavailable => 'পাওয়া যাচ্ছে না';

  @override
  String get voiceNotListened => 'এখনও শোনা হয়নি';

  @override
  String voiceSpeedLabel(String speed) {
    return 'প্লেব্যাক গতি $speed';
  }

  @override
  String get voiceRecording => 'রেকর্ড করা হচ্ছে';

  @override
  String voiceTimeLeft(String time) {
    return '$time বাকি';
  }

  @override
  String get voiceCancelRecording => 'বাতিল';

  @override
  String get voiceSendRecording => 'ভয়েস মেসেজ পাঠান';

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
  String get searchPeopleHint => 'নাম বা @ইউজারনেম দিয়ে খুঁজুন';

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
  String get messageWaitingToSend => 'পাঠানোর অপেক্ষায়';

  @override
  String get messageNotSent => 'পাঠানো হয়নি';

  @override
  String get connectionBusy => 'সংযোগ করা হচ্ছে…';

  @override
  String get connectionWaitingForNetwork => 'নেটওয়ার্কের অপেক্ষায়';

  @override
  String get wsDiagnostics => 'সংযোগ ডায়াগনস্টিকস';

  @override
  String wsDiagnosticsFrames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি ফ্রেম রেকর্ড হয়েছে',
      one: '১টি ফ্রেম রেকর্ড হয়েছে',
      zero: 'কোনো ফ্রেম রেকর্ড হয়নি',
    );
    return '$_temp0';
  }

  @override
  String get wsDiagnosticsCopied => 'ডায়াগনস্টিকস কপি করা হয়েছে';

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
      'ফোল্ডার কেবল এই ডিভাইসে থাকে, অ্যাকাউন্টের সঙ্গে যায় না। পিন, আর্কাইভ ও নীরব করা চ্যাট যায়।';

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
  String get searchLoadedHistoryOnly => 'এই ডিভাইসে যা আছে তাতে খোঁজা হয়েছে';

  @override
  String get searchLoadedHistoryExplained =>
      'সার্ভারে পৌঁছানো যায়নি, তাই এই ডিভাইসে থাকা বার্তাগুলোতেই খোঁজা হয়েছে।';

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

  @override
  String get reactionSectionRecent => 'সম্প্রতি ব্যবহৃত';

  @override
  String get reactionSectionFaces => 'স্মাইলি';

  @override
  String get reactionSectionPeople => 'মানুষ';

  @override
  String get reactionSectionHearts => 'হৃদয়';

  @override
  String get reactionSectionCelebration => 'উদযাপন';

  @override
  String get reactionSectionFood => 'খাবার';

  @override
  String get reactionSectionNature => 'প্রকৃতি';

  @override
  String get reactionSectionSymbols => 'প্রতীক';

  @override
  String get reactionsNoneAllowed => 'এই চ্যাটে কোনো রিঅ্যাকশন নেই';

  @override
  String reactionsUsed(int used, int limit) {
    return '$limit-এর মধ্যে $used';
  }

  @override
  String reactionMessageLimitReached(Object limit) {
    return 'এই বার্তায় ইতিমধ্যে $limitটি ভিন্ন রিঅ্যাকশন আছে';
  }

  @override
  String get moreReactions => 'আরও রিঅ্যাকশন';

  @override
  String get reactionFailed => 'রিঅ্যাকশন সংরক্ষিত হয়নি';

  @override
  String get reactionTooFast => 'একসাথে অনেক বেশি রিঅ্যাকশন';

  @override
  String get reactionNotAllowed => 'এই রিঅ্যাকশন এখানে অনুমোদিত নয়';

  @override
  String get reactionsNobody => 'এখনো কেউ নয়';

  @override
  String reactionUserFallback(Object id) {
    return 'ব্যবহারকারী $id';
  }

  @override
  String composerCharactersLeft(int count) {
    return '$countটি বাকি';
  }

  @override
  String get composerSendLabel => 'পাঠান';

  @override
  String get composerSaveEditLabel => 'পরিবর্তন সংরক্ষণ করুন';

  @override
  String get composerRecordLabel => 'ভয়েস বার্তা রেকর্ড করতে ধরে রাখুন';

  @override
  String composerReplyingTo(Object name) {
    return '$name-কে উত্তর';
  }

  @override
  String composerSlowModeWait(int seconds) {
    return 'ধীর মোড: $seconds সেকেন্ড বাকি';
  }

  @override
  String composerSlowModeHint(int seconds) {
    return 'এই চ্যাটে প্রতি $seconds সেকেন্ডে একটি বার্তা পাঠানো যায়';
  }

  @override
  String get attachSheetTitle => 'সংযুক্ত করুন';

  @override
  String get attachRecent => 'সাম্প্রতিক';

  @override
  String get attachCamera => 'ক্যামেরা';

  @override
  String get attachVoice => 'ভয়েস বার্তা';

  @override
  String get attachVideoNote => 'ভিডিও নোট';

  @override
  String attachVoiceHint(int seconds) {
    return 'আলাদাভাবে পাঠানো হয়, সর্বোচ্চ $seconds সেকেন্ড';
  }

  @override
  String attachVideoNoteHint(int seconds, int pixels) {
    return 'আলাদাভাবে পাঠানো হয়, সর্বোচ্চ $seconds সেকেন্ড ও $pixels পিক্সেল';
  }

  @override
  String get attachGalleryDenied => 'এখান থেকে বেছে নিতে ছবির অ্যাক্সেস দিন';

  @override
  String get attachGalleryAllow => 'অনুমতি দিন';

  @override
  String attachMediaFull(int count) {
    return 'প্রতি বার্তায় সর্বোচ্চ $countটি ছবি বা ভিডিও';
  }

  @override
  String attachSendCount(int count) {
    return '$countটি সংযুক্ত করুন';
  }

  @override
  String get attachUnavailable => 'ফাইলটি পড়া যায়নি';

  @override
  String videoNoteTooLarge(int pixels) {
    return 'এই ক্যামেরা $pixels পিক্সেলের বেশি রেকর্ড করে, যা ভিডিও নোটের জন্য সার্ভার গ্রহণ করে না';
  }

  @override
  String composerTooLongBy(int count) {
    return 'সীমার চেয়ে $count বেশি';
  }

  @override
  String get videoNoteTapToRecord => 'রেকর্ড করতে ট্যাপ করুন';

  @override
  String get videoNoteNoCamera => 'এই ডিভাইসে রেকর্ড করার ক্যামেরা নেই';

  @override
  String get videoNoteCameraDenied =>
      'ভিডিও নোট রেকর্ড করতে ক্যামেরা ও মাইক্রোফোনের অনুমতি দিন';

  @override
  String get videoNoteCameraFailed => 'ক্যামেরা চালু করা যায়নি';

  @override
  String get videoNoteDiscarded => 'কিছু রেকর্ড হয়নি';

  @override
  String get attachmentOpen => 'খুলুন';

  @override
  String attachmentSavedTo(String path) {
    return '$path-এ সংরক্ষণ করা হয়েছে';
  }

  @override
  String get attachmentSaveFailed => 'এই ফাইলটি সংরক্ষণ করা যায়নি';

  @override
  String get attachmentUploading => 'আপলোড হচ্ছে';

  @override
  String mediaViewerCounter(int index, int count) {
    return '$countটির মধ্যে $index';
  }

  @override
  String get mediaViewerUnavailable => 'এই মিডিয়াটি আর উপলব্ধ নেই';

  @override
  String get mediaPreviewHint => 'যা পাঠাতে চান না তা সরিয়ে ফেলুন';

  @override
  String get mediaPreviewCaptionHint => 'ক্যাপশন যোগ করুন';

  @override
  String get mediaPreviewRemove => 'সরান';

  @override
  String get composerRecordVideoNoteLabel =>
      'ভিডিও বার্তা রেকর্ড করতে চেপে ধরুন';

  @override
  String get composerSwitchToVideoNote => 'ভিডিও বার্তায় যান';

  @override
  String get composerSwitchToVoice => 'ভয়েস বার্তায় যান';

  @override
  String get videoNoteSwitchCamera => 'ক্যামেরা বদলান';

  @override
  String get videoNoteDoubleTapToSwitch => 'ক্যামেরা বদলাতে দুবার আলতো চাপুন';

  @override
  String get videoNoteOpeningCamera => 'ক্যামেরা চালু হচ্ছে…';

  @override
  String get videoNoteHoldToRecord => 'রেকর্ড করতে চেপে ধরুন';

  @override
  String get videoNoteSend => 'ভিডিও বার্তা পাঠান';

  @override
  String get videoNoteRecordingLabel => 'ভিডিও বার্তা রেকর্ড হচ্ছে';

  @override
  String get videoNoteTapForSound => 'শব্দ চালু করতে আলতো চাপুন';

  @override
  String get videoNoteTapToMute => 'নিঃশব্দ করতে আলতো চাপুন';

  @override
  String get videoNoteHoldForFullScreen => 'পূর্ণ পর্দায় দেখতে চেপে ধরুন';

  @override
  String videoNotePlayerLabel(String duration) {
    return 'ভিডিও বার্তা, $duration';
  }

  @override
  String get videoNoteAutoplayOff => 'চালাতে আলতো চাপুন';

  @override
  String get mediaAutoplay => 'ভিডিও বার্তা নিজে থেকে চালু';

  @override
  String get mediaAutoplayHint =>
      'পর্দায় এলে ভিডিও বার্তা নিঃশব্দে চলতে শুরু করে। আলতো চাপলে শব্দ চালু হয়।';

  @override
  String get mediaAutoplayAlways => 'সবসময়';

  @override
  String get mediaAutoplayWifi => 'শুধু Wi-Fi-তে';

  @override
  String get mediaAutoplayNever => 'কখনও নয়';

  @override
  String get videoNotePreview => 'ক্যামেরার প্রিভিউ';

  @override
  String searchTypeMore(int count) {
    return 'অন্তত $countটি অক্ষর লিখুন';
  }

  @override
  String get noMessagesFoundHint =>
      'অনুসন্ধান শুধু বার্তার লেখায় চলে, ফাইলের নাম বা চ্যাটের নামে নয়।';

  @override
  String get chatSettings => 'চ্যাটের সেটিংস';

  @override
  String get chatSettingsNoPermission =>
      'শুধু মালিক বা অ্যাডমিন এই চ্যাট বদলাতে পারেন';

  @override
  String get chatNameCannotBeCleared =>
      'চ্যাটের একবার নাম হয়ে গেলে তা মোছা যায় না';

  @override
  String chatSlowModeRange(int max) {
    return '০ থেকে $max সেকেন্ড';
  }

  @override
  String get chatReactionsPickHint =>
      'যেসব ইমোজি দিয়ে প্রতিক্রিয়া দেওয়া যাবে বেছে নিন';

  @override
  String get chatNotMutedLabel => 'বিজ্ঞপ্তি চালু';

  @override
  String get chatMutedToast => 'এই চ্যাটের বিজ্ঞপ্তি বন্ধ';

  @override
  String get chatUnmutedToast => 'এই চ্যাটের বিজ্ঞপ্তি আবার চালু';

  @override
  String get muteForHour => '১ ঘণ্টা নীরব';

  @override
  String get muteForEightHours => '৮ ঘণ্টা নীরব';

  @override
  String get muteForever => 'আমি নিজে চালু করা পর্যন্ত নীরব';

  @override
  String get leaveChatOwnerStuck =>
      'চ্যাটের নির্মাতা বেরোতে পারেন না, আর এই চ্যাট মোছার অনুমতিও আপনার আর নেই।';

  @override
  String get chatInviteLink => 'আমন্ত্রণ লিংক';

  @override
  String get chatInviteLinkHint =>
      'ChatiX-এ সাইন ইন করা যে কেউ এই লিংক খুলে যোগ দিতে পারেন। এটি কেবল অ্যাপেই খোলে।';

  @override
  String get chatInviteLinkCopied => 'আমন্ত্রণ লিংক কপি হয়েছে';

  @override
  String get sharedMedia => 'মিডিয়া';

  @override
  String get sharedFiles => 'ফাইল';

  @override
  String get sharedLinks => 'লিংক';

  @override
  String get sharedVoice => 'ভয়েস';

  @override
  String get sharedMediaEmpty => 'এখানে এখনো কোনো ছবি বা ভিডিও নেই';

  @override
  String get sharedFilesEmpty => 'এখানে এখনো কোনো ফাইল নেই';

  @override
  String get sharedLinksEmpty => 'এখানে এখনো কোনো লিংক নেই';

  @override
  String get sharedVoiceEmpty => 'এখানে এখনো কোনো ভয়েস বার্তা নেই';

  @override
  String get sharedContentLocalOnly =>
      'এই ডিভাইস চ্যাট থেকে যা নামিয়েছে তা-ই দেখায় — সার্ভারে শেয়ার করা মিডিয়ার কোনো সূচি নেই।';

  @override
  String get chatSettingsUnchanged => 'এখনো কিছু বদলায়নি';

  @override
  String get membersSearchHint => 'সদস্য খুঁজুন';

  @override
  String get membersSearchLoadedOnly =>
      'শুধু এ পর্যন্ত লোড হওয়া সদস্যদের মধ্যেই খোঁজা হয়।';

  @override
  String membersSearchEmpty(String query) {
    return 'এখানে «$query»-এর সাথে কারও মিল নেই';
  }

  @override
  String get membersLoadMore => 'আরও লোড করুন';

  @override
  String get membersSectionAdmins => 'পরিচালনা';

  @override
  String get membersSectionMembers => 'সদস্য';

  @override
  String get membersSectionBanned => 'নিষিদ্ধ সদস্য';

  @override
  String get membersBannedHint =>
      'নিষেধাজ্ঞা না ওঠা পর্যন্ত নিষিদ্ধ ব্যক্তিরা এখানে পড়তে বা লিখতে পারবেন না।';

  @override
  String get membersEmptyTitle => 'দেখানোর মতো সদস্য নেই';

  @override
  String get membersEmptyInvite => 'চ্যাট শুরু করতে কাউকে যোগ করুন।';

  @override
  String get membersEmptyNoInvite =>
      'শুধু আমন্ত্রণের অনুমতি আছে এমন সদস্যরাই এখানে লোক যোগ করতে পারেন।';

  @override
  String get chatRoleOwner => 'মালিক';

  @override
  String get chatRoleAdmin => 'অ্যাডমিন';

  @override
  String get chatRoleEditor => 'সম্পাদক';

  @override
  String get chatRoleDirect => 'সরাসরি';

  @override
  String get chatRoleMember => 'সদস্য';

  @override
  String get chatRoleViewer => 'পাঠক';

  @override
  String get chatRoleUnknown => 'অজানা ভূমিকা';

  @override
  String get memberMutedBadge => 'নীরব';

  @override
  String get memberBannedBadge => 'নিষিদ্ধ';

  @override
  String get memberOpenProfile => 'প্রোফাইল খুলুন';

  @override
  String get memberMessagePrivately => 'ব্যক্তিগতভাবে লিখুন';

  @override
  String memberKickConfirmTitle(String name) {
    return '$name-কে সরাবেন?';
  }

  @override
  String get memberKickConfirmBody =>
      'এই চ্যাটে তাঁর প্রবেশ বন্ধ হবে, তবে পরে আবার যোগ করা যাবে।';

  @override
  String memberRoleChanged(String name, String role) {
    return '$name এখন $role';
  }

  @override
  String memberKicked(String name) {
    return '$name-কে সরানো হয়েছে';
  }

  @override
  String memberBannedToast(String name) {
    return '$name-কে নিষিদ্ধ করা হয়েছে';
  }

  @override
  String memberUnbanned(String name) {
    return '$name-এর নিষেধাজ্ঞা উঠেছে';
  }

  @override
  String get memberActionFailed => 'কাজটি হয়নি। আবার চেষ্টা করুন।';

  @override
  String get roleAssignHint => 'আপনি কেবল নিজের নিচের ভূমিকাগুলো দিতে পারেন।';

  @override
  String get roleOwnerTransferHint =>
      'তালিকায় মালিক নেই: API-তে চ্যাট হস্তান্তরের উপায় নেই।';

  @override
  String get banForHour => 'এক ঘণ্টার জন্য';

  @override
  String get banForDay => 'এক দিনের জন্য';

  @override
  String get banForWeek => 'এক সপ্তাহের জন্য';

  @override
  String get inviteMembersTitle => 'লোক যোগ করুন';

  @override
  String get inviteRoleLabel => 'যোগ দেবেন';

  @override
  String inviteRoomLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'আর $count জনের জায়গা আছে',
      one: 'আর ১ জনের জায়গা আছে',
      zero: 'এই চ্যাট পূর্ণ',
    );
    return '$_temp0';
  }

  @override
  String inviteChatFull(int limit) {
    return 'এই চ্যাটে $limit জন সদস্য ধরে, আর তা পূর্ণ।';
  }

  @override
  String inviteAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count জনকে যোগ করুন',
      one: '১ জনকে যোগ করুন',
    );
    return '$_temp0';
  }

  @override
  String inviteAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count জন যোগ হয়েছেন',
      one: '১ জন যোগ হয়েছেন',
    );
    return '$_temp0';
  }

  @override
  String inviteFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count জনকে যোগ করা যায়নি',
      one: '১ জনকে যোগ করা যায়নি',
    );
    return '$_temp0';
  }

  @override
  String get inviteSearchStart =>
      'নাম বা @username দিয়ে লোক খুঁজে একসাথে সবাইকে যোগ করুন।';

  @override
  String get inviteSelectionFull => 'এই চ্যাটে এর বেশি জায়গা নেই।';

  @override
  String peopleSearchNoneFound(String query) {
    return '«$query»-এর জন্য কাউকে পাওয়া যায়নি';
  }

  @override
  String get peopleSearchHint =>
      'নাম বা @username-এর যেকোনো অংশ দিয়েই খোঁজা যায়।';

  @override
  String get profileShareAction => 'শেয়ার';

  @override
  String get profileShareCopied => 'প্রোফাইলের লিংক কপি হয়েছে';

  @override
  String get profileBirthday => 'জন্মদিন';

  @override
  String get profileEmptyTitle => 'এখানে এখনো কিছু নেই';

  @override
  String get profileEmptyHintSelf =>
      'নিজের সম্পর্কে কয়েকটি কথা লিখুন, যাতে কার সাথে কথা হচ্ছে তা বোঝা যায়।';

  @override
  String get profileEmptyHintOther => 'এই ব্যক্তি তাঁর প্রোফাইল পূরণ করেননি।';

  @override
  String get profileAccount => 'অ্যাকাউন্ট';

  @override
  String get profileAccountNoEmail => 'সাইন ইন করা';

  @override
  String get profilePhoto => 'ছবি';

  @override
  String get profileNoPhoto => 'এখনো ছবি নেই';

  @override
  String get profileOpenLinkFailed => 'এই লিংকটি খোলা যায়নি';

  @override
  String get profileContactCopied => 'ক্লিপবোর্ডে কপি হয়েছে';

  @override
  String get profileCopyAction => 'কপি';

  @override
  String devicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি ডিভাইস',
      one: '১টি ডিভাইস',
      zero: 'কোনো ডিভাইস নেই',
    );
    return '$_temp0';
  }

  @override
  String get changePhoto => 'ছবি বদলান';

  @override
  String get setPhoto => 'ছবি সেট করুন';

  @override
  String get choosePhoto => 'একটি ছবি বেছে নিন';

  @override
  String get avatarCropTitle => 'সরান ও বড় করুন';

  @override
  String get avatarCropHint =>
      'সরাতে টানুন, বড়-ছোট করতে দুই আঙুল ব্যবহার করুন।';

  @override
  String get avatarCropConfirm => 'এই ছবিটি নিন';

  @override
  String get avatarStagePreparing => 'প্রস্তুত হচ্ছে…';

  @override
  String get avatarStageUploading => 'আপলোড হচ্ছে…';

  @override
  String get avatarStageConfirming => 'প্রায় শেষ…';

  @override
  String get avatarStageProcessing => 'ছবিটি প্রক্রিয়া করা হচ্ছে…';

  @override
  String get avatarStageDone => 'ছবি হালনাগাদ হয়েছে';

  @override
  String get avatarProcessingFailed => 'ছবিটি হালনাগাদ করা যায়নি';

  @override
  String get avatarProcessingFailedHint =>
      'সার্ভার এই ছবিটি নেয়নি। অন্য একটি দিন।';

  @override
  String get avatarNotAnImage => 'এই ফাইলটি ছবি নয়';

  @override
  String get avatarTooLarge => 'এই ছবিটি অনেক বড়। ছোট একটি বেছে নিন।';

  @override
  String get avatarUnreadable => 'এই ছবিটি খোলা যায়নি';

  @override
  String get profileEditDetails => 'বিবরণ';

  @override
  String get profileEditLinks => 'লিংক';

  @override
  String get profileEditLinksHint =>
      'লিংক যোগ বা মোছার সাথে সাথেই সংরক্ষিত হয়, নিচের ফর্ম থেকে আলাদাভাবে।';

  @override
  String get profileNoLinks => 'এখনো কোনো লিংক নেই';

  @override
  String get removeLink => 'লিংক সরান';

  @override
  String get clearDateOfBirth => 'জন্মতারিখ মুছুন';

  @override
  String get specializationHint => 'আপনি কী করেন, কয়েকটি শব্দে';

  @override
  String bioCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String get profileSkillsHint => 'প্রতিটি সর্বোচ্চ ৩০ অক্ষর';

  @override
  String get profileSaved => 'প্রোফাইল সংরক্ষিত হয়েছে';

  @override
  String get discardChangesTitle => 'পরিবর্তন বাতিল করবেন?';

  @override
  String get discardChangesMessage => 'এই প্রোফাইলে করা সম্পাদনা হারিয়ে যাবে।';

  @override
  String get discardAction => 'বাতিল';

  @override
  String get keepEditingAction => 'সম্পাদনা চালিয়ে যান';

  @override
  String get camera => 'ক্যামেরা';

  @override
  String get loading => 'লোড হচ্ছে…';

  @override
  String fieldTooLong(int max) {
    return 'সর্বোচ্চ $max অক্ষর';
  }

  @override
  String skillTooLong(String skill, int max) {
    return '«$skill» $max অক্ষরের চেয়ে বড়';
  }

  @override
  String callRoomName(String slug) {
    return 'রুম $slug';
  }

  @override
  String get callJoinExplanation =>
      'এখানে কল মানে একটি রুম: যোগ দিন, আর এই চ্যাটের যে কেউ আপনার সাথে যোগ দিতে পারবেন।';

  @override
  String get callNoIncomingNotice =>
      'ইনকামিং কলের রিং এখনো নেই — সার্ভার সেগুলোর কথা জানায় না।';

  @override
  String get callWaitingForOthers => 'আর কেউ যোগ দেওয়ার অপেক্ষায়…';

  @override
  String get callReconnecting => 'আবার যুক্ত হচ্ছে…';

  @override
  String get callYou => 'আপনি';

  @override
  String callParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count জন অংশগ্রহণকারী',
      one: '১ জন অংশগ্রহণকারী',
      zero: 'এখনো কেউ নেই',
    );
    return '$_temp0';
  }

  @override
  String get callMicrophoneMute => 'মাইক বন্ধ';

  @override
  String get callMicrophoneUnmute => 'মাইক চালু';

  @override
  String get callCameraStart => 'ভিডিও চালু';

  @override
  String get callCameraStop => 'ভিডিও বন্ধ';

  @override
  String get callSpeakerOn => 'স্পিকার';

  @override
  String get callSpeakerOff => 'কানের স্পিকার';

  @override
  String get callLayoutGrid => 'গ্রিড';

  @override
  String get callLayoutSpeaker => 'বক্তার দৃশ্য';

  @override
  String callPinParticipant(String name) {
    return '$name-কে পিন করুন';
  }

  @override
  String callUnpinParticipant(String name) {
    return '$name-এর পিন সরান';
  }

  @override
  String get callMuteForEveryone => 'সবার জন্য নীরব করুন';

  @override
  String get callUnmuteForEveryone => 'কথা বলতে দিন';

  @override
  String get callQualityExcellent => 'চমৎকার সংযোগ';

  @override
  String get callQualityGood => 'ভালো সংযোগ';

  @override
  String get callQualityPoor => 'দুর্বল সংযোগ';

  @override
  String get callQualityLost => 'সংযোগ বিচ্ছিন্ন';

  @override
  String get callMicrophonePermissionTitle =>
      'ChatiX-কে মাইক ব্যবহারের অনুমতি দিন';

  @override
  String get callMicrophonePermissionBody =>
      'ChatiX মাইক ব্যবহার করতে পারলেই অন্যরা আপনাকে শুনতে পাবেন। যেকোনো সময় আবার নীরব করা যাবে।';

  @override
  String get callCameraPermissionTitle =>
      'ChatiX-কে ক্যামেরা ব্যবহারের অনুমতি দিন';

  @override
  String get callCameraPermissionBody =>
      'ক্যামেরা চালু থাকা অবস্থাতেই কেবল আপনার ভিডিও যায়, আর যেকোনো সময় তা বন্ধ করা যায়।';

  @override
  String get callPermissionContinue => 'চালিয়ে যান';

  @override
  String get callPermissionNotNow => 'এখন নয়';

  @override
  String get callPermissionOpenSettings => 'সেটিংস খুলুন';

  @override
  String get callMicrophoneBlocked => 'মাইক বন্ধ: ChatiX-এর অনুমতি নেই।';

  @override
  String get callCameraBlocked => 'ক্যামেরা বন্ধ: ChatiX-এর অনুমতি নেই।';

  @override
  String get callSelfPreview => 'আপনার ক্যামেরা';

  @override
  String get callSelfPreviewHint => 'সরাতে টানুন';

  @override
  String get callShowControls => 'কলের নিয়ন্ত্রণ দেখান';

  @override
  String get callOngoingInChat => 'আপনি এই চ্যাটের একটি কলে আছেন';

  @override
  String get callReturn => 'ফিরে যান';

  @override
  String callMiniPlayerLabel(String name) {
    return '$name-এর সাথে কল';
  }

  @override
  String get callMinimize => 'কল ছোট করুন';

  @override
  String get callDismiss => 'বন্ধ করুন';

  @override
  String get notificationNewMessage => 'নতুন বার্তা';

  @override
  String get notificationReplyHint => 'বার্তা';

  @override
  String get notificationReplyFailed => 'আপনার উত্তর পাঠানো যায়নি';

  @override
  String get notificationActionFailed => 'কাজটি সম্পন্ন করা যায়নি';

  @override
  String get notificationSettingsTitle => 'বিজ্ঞপ্তি';

  @override
  String get notificationSoundTitle => 'শব্দ';

  @override
  String get notificationSoundSubtitle => 'কিছু এলে একটি শব্দ বাজান';

  @override
  String get notificationVibrationTitle => 'কম্পন';

  @override
  String get notificationVibrationSubtitle => 'কিছু এলে কম্পন করুন';

  @override
  String get notificationPreviewTitle => 'বার্তার প্রিভিউ';

  @override
  String get notificationPreviewSubtitle => 'কে লিখেছে এবং কী লিখেছে তা দেখান';

  @override
  String get quietHoursTitle => 'নীরব সময়';

  @override
  String get quietHoursSubtitle => 'বিজ্ঞপ্তি আসবে, তবে শব্দ ছাড়া';

  @override
  String get quietHoursFrom => 'থেকে';

  @override
  String get quietHoursTo => 'পর্যন্ত';

  @override
  String get chatNotificationsTitle => 'চ্যাট অনুযায়ী ব্যতিক্রম';

  @override
  String get chatNotificationsEmpty => 'এখনও কোনো ব্যতিক্রম নেই';

  @override
  String get chatNotificationsEmptyHint =>
      'সব চ্যাট উপরের সেটিংস অনুসরণ করে। কোনোটি বদলাতে সেই চ্যাটে যান।';

  @override
  String get chatNotificationsReset => 'সব রিসেট করুন';

  @override
  String get chatNotificationProfileTitle => 'এই চ্যাটের বিজ্ঞপ্তি';

  @override
  String get chatNotificationProfileAll => 'সব বার্তা';

  @override
  String get chatNotificationProfileMentions => 'শুধু উল্লেখ';

  @override
  String get chatNotificationProfileOff => 'কিছু না';

  @override
  String get notificationPermissionOffTitle => 'বিজ্ঞপ্তি বন্ধ আছে';

  @override
  String get notificationPermissionOffHint =>
      'সিস্টেম সেটিংসে বিজ্ঞপ্তির অনুমতি না দিলে নিচের কিছুই আপনার কাছে পৌঁছাবে না।';

  @override
  String get notificationsEmptyTitle => 'এখনও কোনো বিজ্ঞপ্তি নেই';

  @override
  String get notificationsEmptyMessage =>
      'আমন্ত্রণ, উল্লেখ ও বার্তা এখানে দেখা যাবে।';

  @override
  String get notificationsEmptyUnread => 'অপঠিত কিছু নেই';

  @override
  String get notificationsEmptyRead => 'এখনও কিছু পড়া হয়নি';

  @override
  String get notificationsEmptyFilterHint =>
      'সবকিছু দেখতে ফিল্টার “সব”-এ বদলান।';

  @override
  String get timeJustNow => 'এইমাত্র';

  @override
  String notificationsMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি বিজ্ঞপ্তি পঠিত হিসেবে চিহ্নিত',
      one: '1টি বিজ্ঞপ্তি পঠিত হিসেবে চিহ্নিত',
      zero: 'অপঠিত কিছু ছিল না',
    );
    return '$_temp0';
  }

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count মিনিট আগে',
      one: '1 মিনিট আগে',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ঘণ্টা আগে',
      one: '1 ঘণ্টা আগে',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count দিন আগে',
      one: 'গতকাল',
    );
    return '$_temp0';
  }

  @override
  String get appearanceTitle => 'চেহারা';

  @override
  String get appearanceHint => 'থিম, অ্যাকসেন্ট, ওয়ালপেপার, বাবল ও মিডিয়া';

  @override
  String get appearancePreview => 'প্রিভিউ';

  @override
  String get previewIncomingMessage =>
      'এখানকার সবকিছুই আপনার অ্যাকসেন্ট রং থেকে আঁকা।';

  @override
  String get previewOutgoingMessage => 'কোনো ওয়ালপেপার ছবি নেই। শুধু কোড।';

  @override
  String get previewIncomingReply => 'স্লাইডার নাড়ুন আর দেখুন।';

  @override
  String get amoledTitle => 'কালো (AMOLED)';

  @override
  String get amoledHint =>
      'একদম কালো ব্যাকগ্রাউন্ড। OLED স্ক্রিনে কালো পিক্সেলে কোনো বিদ্যুৎ খরচ হয় না।';

  @override
  String get accentFromAvatar => 'আমার ছবি থেকে রং নিন';

  @override
  String get accentFromAvatarApplied =>
      'আপনার ছবি থেকে অ্যাকসেন্ট নেওয়া হয়েছে।';

  @override
  String get accentFromAvatarEmpty =>
      'আপনার ছবিতে নেওয়ার মতো রং নেই — এটি ধূসর দেখায়।';

  @override
  String get accentFromAvatarMissing => 'আগে একটি প্রোফাইল ছবি যোগ করুন।';

  @override
  String get accentFromAvatarFailed =>
      'আপনার ছবি পড়া যায়নি। আবার চেষ্টা করুন।';

  @override
  String get accentCustom => 'আপনার রং';

  @override
  String get wallpaperNebula => 'নেবুলা';

  @override
  String get wallpaperRibbons => 'রিবন';

  @override
  String get wallpaperPrism => 'প্রিজম';

  @override
  String get wallpaperHalo => 'হ্যালো';

  @override
  String get wallpaperDunes => 'ডিউন';

  @override
  String get wallpaperIntensity => 'তীব্রতা';

  @override
  String get wallpaperPattern => 'প্যাটার্ন';

  @override
  String get appearanceDensity => 'ঘনত্ব';

  @override
  String get appearanceDensityHint => 'সারি ও মেসেজ বাবল কতটা জায়গা নেবে।';

  @override
  String get textSizeHint => 'সিস্টেমের লেখার আকারের উপরে প্রয়োগ হয়।';

  @override
  String get bubbleShape => 'বাবলের আকার';

  @override
  String get bubbleCorners => 'কোণ';

  @override
  String get bubbleAnchor => 'অ্যাঙ্কর কোণ';

  @override
  String get bubbleAnchorHint =>
      'প্রেরকের দিকের কোণ সরু করে, যাতে বাবলটি তার দিকে নির্দেশ করে।';

  @override
  String get mediaSectionTitle => 'মিডিয়া';

  @override
  String get autoDownload => 'স্বয়ংক্রিয় ডাউনলোড';

  @override
  String get autoDownloadHint => 'খোলার আগেই কোন সংযুক্তিগুলো নামানো হবে।';

  @override
  String get autoDownloadPhotos => 'ছবি';

  @override
  String get autoDownloadVideos => 'ভিডিও';

  @override
  String get autoDownloadFiles => 'ফাইল';

  @override
  String get autoDownloadVoice => 'ভয়েস মেসেজ';

  @override
  String get autoDownloadWifi => 'ওয়াই-ফাই';

  @override
  String get autoDownloadMobile => 'মোবাইল ডেটা';

  @override
  String get autoDownloadNever => 'কখনো নয়';

  @override
  String get cacheLimit => 'ক্যাশের সীমা';

  @override
  String get cacheLimitHint =>
      'ডাউনলোড করা সংযুক্তি এই সীমা পর্যন্ত রাখা হয়, তারপর পুরনোগুলো আগে মুছে যায়।';

  @override
  String get cacheEmpty => 'এখনো কিছু ক্যাশে নেই';

  @override
  String get cacheClear => 'ক্যাশ খালি করুন';

  @override
  String get cacheMeasuring => 'হিসাব করা হচ্ছে…';

  @override
  String get appearanceReduceMotionNotice =>
      'আপনার সিস্টেম কম অ্যানিমেশন চাইছে, তাই এখানে কিছু নড়ে না।';

  @override
  String get appearanceHighContrastNotice =>
      'হাই কনট্রাস্ট চালু আছে, তাই লেখা পড়ার সুবিধার্থে ওয়ালপেপার হালকা করে আঁকা হয়।';

  @override
  String cacheInUse(String size) {
    return '$size ব্যবহৃত';
  }

  @override
  String cacheCleared(String size) {
    return '$size খালি হয়েছে';
  }

  @override
  String sizeMegabytes(String value) {
    return '$value MB';
  }

  @override
  String sizeGigabytes(String value) {
    return '$value GB';
  }

  @override
  String get attachmentTapToDownload => 'ডাউনলোড করতে ট্যাপ করুন';

  @override
  String get welcomeHeadline => 'ChatiX-এ স্বাগতম';

  @override
  String get welcomeTagline => 'যে বার্তা আপনার সঙ্গে তাল মিলিয়ে চলে।';

  @override
  String get welcomeGetStarted => 'শুরু করুন';

  @override
  String get welcomeSignIn => 'আমার অ্যাকাউন্ট আছে';

  @override
  String get onboardingSkip => 'এড়িয়ে যান';

  @override
  String get onboardingNext => 'পরবর্তী';

  @override
  String get onboardingDone => 'অ্যাকাউন্ট তৈরি করুন';

  @override
  String get onboardingRealtimeTitle => 'সবকিছু রিয়েল টাইমে';

  @override
  String get onboardingRealtimeBody =>
      'বার্তা, সম্পাদনা আর প্রতিক্রিয়া ঘটার মুহূর্তেই পৌঁছে যায় — আর নেটওয়ার্ক উত্তর দেওয়ার আগেই অ্যাপ সেই আলাপেই খোলে যেখানে আপনি থেমেছিলেন।';

  @override
  String get onboardingTogetherTitle => 'চ্যাট, গ্রুপ, চ্যানেল, কল';

  @override
  String get onboardingTogetherBody =>
      'একজনের সঙ্গে একজন, পাঁচশো জনের গ্রুপ, বা সবার জন্য চ্যানেল — ভয়েস বা ভিডিও কল সবসময় এক ট্যাপ দূরে।';

  @override
  String get onboardingPrivacyTitle => 'কেবল আপনারই';

  @override
  String get onboardingPrivacyBody =>
      'লগ-ইন করা প্রতিটি ডিভাইস দেখুন ও বন্ধ করুন, আঙুলের ছাপ দিয়ে অ্যাপ লক করুন, আর ফাইল পাঠানোর আগে সেগুলো ফোনেই থাকুক।';

  @override
  String onboardingPageOf(int current, int total) {
    return '$total-এর মধ্যে $current নম্বর পাতা';
  }

  @override
  String get loginHeadline => 'আবার স্বাগতম';

  @override
  String get loginSubtitle => 'সাইন ইন করে আলাপ চালিয়ে যান।';

  @override
  String get registerHeadline => 'আপনার অ্যাকাউন্ট তৈরি করুন';

  @override
  String get registerSubtitle => 'প্রায় এক মিনিট লাগে।';

  @override
  String get authOrContinueWith => 'অথবা এর মাধ্যমে চালিয়ে যান';

  @override
  String get authNoAccount => 'অ্যাকাউন্ট নেই?';

  @override
  String get authHaveAccount => 'আগে থেকেই অ্যাকাউন্ট আছে?';

  @override
  String get authErrorWrongLoginData =>
      'ব্যবহারকারীর নাম বা পাসওয়ার্ড ঠিক নয়।';

  @override
  String get authErrorEmailNotConfirmed =>
      'সাইন ইন করার আগে আপনার ইমেল ঠিকানা নিশ্চিত করুন।';

  @override
  String authErrorEmailNotConfirmedFor(String email) {
    return 'সাইন ইন করার আগে $email নিশ্চিত করুন।';
  }

  @override
  String get authResendEmail => 'ইমেলটি আবার পাঠান';

  @override
  String get authErrorTooManyAttempts =>
      'অনেকবার চেষ্টা হয়েছে। এক মিনিট অপেক্ষা করে আবার চেষ্টা করুন।';

  @override
  String get authErrorDuplicateUsername =>
      'এই ব্যবহারকারীর নাম আগেই নেওয়া হয়েছে।';

  @override
  String get authErrorDuplicateEmail =>
      'এই ইমেল দিয়ে আগেই একটি অ্যাকাউন্ট আছে।';

  @override
  String authErrorDuplicateField(String field) {
    return '$field আগে থেকেই ব্যবহৃত হচ্ছে।';
  }

  @override
  String get authErrorPasswordMismatch => 'পাসওয়ার্ড দুটি মিলছে না।';

  @override
  String get authErrorInvalidCode =>
      'এই কোডটি আর কাজ করে না। নতুন একটি চেয়ে নিন।';

  @override
  String get authErrorUserNotFound =>
      'এই তথ্য দিয়ে কোনো অ্যাকাউন্ট পাওয়া যায়নি।';

  @override
  String get authErrorOffline => 'সংযোগ নেই। নেটওয়ার্ক দেখে আবার চেষ্টা করুন।';

  @override
  String get authErrorGeneric => 'কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get passwordStrengthLabel => 'পাসওয়ার্ডের শক্তি';

  @override
  String get passwordStrengthWeak => 'দুর্বল';

  @override
  String get passwordStrengthFair => 'মোটামুটি';

  @override
  String get passwordStrengthGood => 'ভালো';

  @override
  String get passwordStrengthStrong => 'শক্ত';

  @override
  String get passwordShow => 'পাসওয়ার্ড দেখান';

  @override
  String get passwordHide => 'পাসওয়ার্ড লুকান';

  @override
  String get verifyEmailHeadline => 'আপনার ইমেল দেখুন';

  @override
  String verifyEmailSentTo(String email) {
    return 'আমরা $email ঠিকানায় একটি নিশ্চিতকরণ কোড পাঠিয়েছি।';
  }

  @override
  String get verifyEmailSentToYou =>
      'আমরা আপনাকে একটি নিশ্চিতকরণ কোড পাঠিয়েছি।';

  @override
  String get verifyEmailClipboardHint =>
      'ইমেল থেকে কোডটি কপি করুন — ফিরে আসামাত্র ChatiX সেটি তুলে নেবে।';

  @override
  String get verifyEmailCodeFromClipboard => 'ক্লিপবোর্ড থেকে কোড বসানো হয়েছে';

  @override
  String verifyEmailResendIn(int seconds) {
    return '$seconds সেকেন্ড পরে নতুন ইমেল চাইতে পারবেন';
  }

  @override
  String get verifyEmailWrongAddress => 'ঠিকানা ভুল?';

  @override
  String get verifyEmailChangeAddress => 'অন্যটি ব্যবহার করুন';

  @override
  String get biometricUnlockTitle => 'বায়োমেট্রিক দিয়ে আনলক';

  @override
  String get biometricUnlockSubtitle =>
      'ChatiX আবার খুললে আঙুলের ছাপ বা মুখ চাওয়া হবে।';

  @override
  String get biometricUnlockUnavailable =>
      'এই ডিভাইসে কোনো বায়োমেট্রিক সেট করা নেই।';

  @override
  String get biometricUnlockReason => 'ChatiX আনলক করুন';

  @override
  String get biometricUnlockLockedTitle => 'ChatiX লক করা আছে';

  @override
  String get biometricUnlockLockedBody => 'চ্যাটে ফিরতে আনলক করুন।';

  @override
  String get biometricUnlockAction => 'আনলক';

  @override
  String get biometricUnlockFailed => 'যাচাই হয়নি। আবার চেষ্টা করুন।';

  @override
  String get biometricUnlockLockedOut =>
      'বহুবার চেষ্টার পর সিস্টেম বায়োমেট্রিক বন্ধ করে দিয়েছে।';

  @override
  String get biometricUnlockNotEnrolled =>
      'এই ডিভাইসে কোনো আঙুলের ছাপ বা মুখ নথিভুক্ত নেই।';

  @override
  String get biometricUnlockEnableFailed => 'বায়োমেট্রিক চালু করা যায়নি।';

  @override
  String get settingsSecuritySection => 'নিরাপত্তা';

  @override
  String get settingsAccountSection => 'অ্যাকাউন্ট';

  @override
  String get logoutConfirmTitle => 'লগ আউট করবেন?';

  @override
  String get logoutConfirmBody =>
      'এই ডিভাইস আপনার বার্তা, খসড়া ও ডাউনলোড করা ফাইল ভুলে যাবে। আপনার অ্যাকাউন্ট যেমন আছে তেমনই থাকবে।';

  @override
  String get logoutAction => 'লগ আউট';

  @override
  String get logoutFailed => 'লগ আউট করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get logoutInProgress => 'লগ আউট করা হচ্ছে…';

  @override
  String get appearanceFeel => 'অনুভব';

  @override
  String get appearanceHaptics => 'হ্যাপটিক ফিডব্যাক';

  @override
  String get appearanceHapticsHint =>
      'বার্তা পাঠানো, রিঅ্যাকশন বসানো বা কোনও জেসচার সম্পূর্ণ হলে ছোট কম্পন। আপনার ডিভাইসের নিজস্ব কম্পন সেটিং আগের মতোই কার্যকর।';

  @override
  String get failureGeneric => 'কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get failureRateLimited =>
      'অনেক বেশি চেষ্টা হয়েছে। এক মিনিট পরে আবার চেষ্টা করুন।';

  @override
  String get failureNoConnection =>
      'ইন্টারনেট সংযোগ নেই। নেটওয়ার্ক দেখে আবার চেষ্টা করুন।';

  @override
  String get failureTimeout =>
      'সার্ভার সাড়া দিতে অনেক সময় নিচ্ছে। আবার চেষ্টা করুন।';

  @override
  String get failureInsecureSessionCookie =>
      'সার্ভার একটি অনিরাপদ সাইন-ইন কুকি পাঠিয়েছে, তাই সেশন সংরক্ষণ করা হয়নি। এটি সার্ভারের সেটিং — সহায়তার সাথে যোগাযোগ করুন।';

  @override
  String get apiErrorSessionEnded =>
      'আপনার সেশন শেষ হয়েছে। আবার সাইন ইন করুন।';

  @override
  String get apiErrorSessionExpired =>
      'আপনার সেশনের মেয়াদ শেষ। আবার সাইন ইন করুন।';

  @override
  String get apiErrorSessionInvalid =>
      'আপনার সেশন আর বৈধ নয়। আবার সাইন ইন করুন।';

  @override
  String get apiErrorSessionSignedOut =>
      'এই সেশন থেকে সাইন আউট করা হয়েছে। আবার সাইন ইন করুন।';

  @override
  String get apiErrorAccessDenied => 'এটি করার অনুমতি আপনার নেই।';

  @override
  String get apiErrorValidation =>
      'কিছু তথ্য সঠিক নয়। যাচাই করে আবার চেষ্টা করুন।';

  @override
  String get apiErrorNotFoundGeneric =>
      'এটি পাওয়া যায়নি — হয়তো মুছে ফেলা হয়েছে।';

  @override
  String get apiErrorTooLongGeneric => 'মানটি অনেক লম্বা। ছোট করুন।';

  @override
  String get apiErrorLimitExceededGeneric =>
      'সীমা পূর্ণ হয়েছে, তাই এই কাজটি এখন করা যাবে না।';

  @override
  String get apiErrorWrongLoginData => 'ব্যবহারকারীর নাম বা পাসওয়ার্ড ভুল।';

  @override
  String get apiErrorPasswordMismatch => 'পাসওয়ার্ড দুটি মিলছে না।';

  @override
  String get apiErrorDuplicateUser =>
      'এই ব্যবহারকারীর নাম বা ইমেল ইতিমধ্যে ব্যবহৃত।';

  @override
  String get apiErrorEmailNotConfirmed =>
      'সাইন ইনের আগে আপনার ইমেল নিশ্চিত করুন।';

  @override
  String get apiErrorOauthProviderUnsupported =>
      'এই সাইন-ইন সরবরাহকারী সমর্থিত নয়।';

  @override
  String get apiErrorOauthStateNotFound =>
      'সাইন-ইন চেষ্টার মেয়াদ শেষ। আবার চেষ্টা করুন।';

  @override
  String get apiErrorOauthLinkedAnotherUser =>
      'এই অ্যাকাউন্ট আগেই অন্য ব্যবহারকারীর সাথে যুক্ত।';

  @override
  String get apiErrorProfileExists => 'আপনার ইতিমধ্যে একটি প্রোফাইল আছে।';

  @override
  String get apiErrorNotChatMember => 'আপনি এই চ্যাটের সদস্য নন।';

  @override
  String get apiErrorAlreadyChatMember =>
      'এই ব্যক্তি আগে থেকেই এই চ্যাটে আছেন।';

  @override
  String get apiErrorInvalidChatRole => 'এটি বৈধ চ্যাট ভূমিকা নয়।';

  @override
  String get apiErrorDirectChatExists =>
      'এই ব্যক্তির সাথে আপনার আগেই সরাসরি চ্যাট আছে।';

  @override
  String get apiErrorMessageTooLong => 'বার্তাটি অনেক লম্বা। ছোট করুন।';

  @override
  String get apiErrorInvalidMessage => 'এই বার্তাটি এভাবে পাঠানো যাবে না।';

  @override
  String get apiErrorSlowModeLimit =>
      'ধীর মোড চালু — পরের বার্তা পাঠানোর আগে অপেক্ষা করুন।';

  @override
  String get apiErrorSlowModeOutOfRange =>
      'ধীর মোড ০ সেকেন্ড থেকে ২৪ ঘণ্টার মধ্যে হতে হবে।';

  @override
  String get apiErrorAttachmentLimitExceeded =>
      'একটি বার্তায় অনেক বেশি সংযুক্তি।';

  @override
  String get apiErrorAttachmentNotFound => 'এই সংযুক্তিটি আর পাওয়া যাচ্ছে না।';

  @override
  String get apiErrorAttachmentValidation =>
      'এই ফাইলটি সংযুক্ত করা যাবে না — ধরন ও আকার দেখুন।';

  @override
  String get apiErrorEmptyAttachmentUpload =>
      'সংযুক্ত করার জন্য একটি ফাইল বেছে নিন।';

  @override
  String get apiErrorInvalidUploadToken =>
      'আপলোডের মেয়াদ শেষ। ফাইলটি আবার সংযুক্ত করুন।';

  @override
  String get apiErrorAvatarNotImage => 'অবতার একটি ছবির ফাইল হতে হবে।';

  @override
  String get apiErrorActiveCallExists => 'এই চ্যাটে আগে থেকেই একটি কল চলছে।';

  @override
  String get apiErrorNoActiveCall => 'এই চ্যাটে কোনো কল চলছে না।';

  @override
  String get apiErrorLivekitUnauthorized => 'আপনি এই কলে যোগ দিতে পারবেন না।';

  @override
  String get apiErrorLivekitError => 'কল পরিষেবা এখন উপলব্ধ নয়।';

  @override
  String get apiErrorInvalidReaction =>
      'এই ইমোজি প্রতিক্রিয়া হিসেবে ব্যবহার করা যাবে না।';

  @override
  String get apiErrorReactionNotAllowed =>
      'এই চ্যাটে এই প্রতিক্রিয়া অনুমোদিত নয়।';

  @override
  String get apiErrorReactionsDisabled => 'এই চ্যাটে প্রতিক্রিয়া বন্ধ আছে।';

  @override
  String get apiErrorTooManyReactions =>
      'এখানে আর প্রতিক্রিয়া যোগ করা যাবে না।';

  @override
  String get apiErrorMaxLimitCursor =>
      'একসাথে অনেক বেশি চ্যাট পুনরায় শুরু হয়েছে।';

  @override
  String a11yMessageFrom(String author, String time) {
    return '$author-এর বার্তা, $time';
  }

  @override
  String a11yMessageMine(String time) {
    return 'আপনার বার্তা, $time';
  }

  @override
  String get a11ySystemMessage => 'সিস্টেম বার্তা';

  @override
  String a11yReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি প্রতিক্রিয়া',
      one: '১টি প্রতিক্রিয়া',
    );
    return '$_temp0';
  }

  @override
  String get a11yReactionYours => 'আপনারটিসহ';

  @override
  String get a11yMessageActionsHint => 'বার্তার কাজগুলি দেখান';

  @override
  String a11yMessageAttachmentsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি সংযুক্তি',
      one: '১টি সংযুক্তি',
    );
    return '$_temp0';
  }

  @override
  String get reviewPromptTitle => 'অ্যাপটি কেমন লাগছে?';

  @override
  String get reviewPromptBody => 'আপনার মতামত আমাদের জানাবেন?';

  @override
  String get reviewPromptDecline => 'না, ধন্যবাদ';

  @override
  String get reviewPromptAccept => 'অবশ্যই';

  @override
  String get feedbackTitle => 'আপনার মতামত গুরুত্বপূর্ণ';

  @override
  String get feedbackBody =>
      'অ্যাপটি সম্পর্কে আপনার মতামত জানান। ভালো লাগলে স্টোরে একটি রিভিউ আমাদের অনেক সাহায্য করবে।';

  @override
  String get feedbackHint => 'এখানে আপনার মতামত লিখুন';

  @override
  String get feedbackSubmit => 'পাঠান';

  @override
  String get updateRequiredTitle => 'আপডেট প্রয়োজন';

  @override
  String get updateAvailableTitle => 'আপডেট পাওয়া যাচ্ছে';

  @override
  String updateRequiredBody(String version) {
    return 'ChatiX ব্যবহার চালিয়ে যেতে $version সংস্করণ প্রয়োজন।';
  }

  @override
  String updateAvailableBody(String version) {
    return '$version সংস্করণ পাওয়া যাচ্ছে।';
  }

  @override
  String get updateWhatsNew => 'নতুন যা আছে';

  @override
  String get updateLater => 'পরে';

  @override
  String get updateNow => 'এখনই আপডেট করুন';

  @override
  String get updateAction => 'আপডেট';
}
