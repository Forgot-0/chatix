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
  String get messageReact => 'React';

  @override
  String get messageCopy => 'Copy text';

  @override
  String get messageCopied => 'Copied';

  @override
  String get linkOpenFailed => 'Nothing here can open that link';

  @override
  String get messageDetails => 'Details';

  @override
  String replyingTo(String author) {
    return 'Replying to $author';
  }

  @override
  String forwardedFrom(String author) {
    return 'Forwarded from $author';
  }

  @override
  String get forwardedMessage => 'Forwarded message';

  @override
  String get detailsSentAt => 'Sent';

  @override
  String get detailsAuthor => 'From';

  @override
  String get detailsSequence => 'Number in chat';

  @override
  String get detailsEdited => 'Edited';

  @override
  String get detailsEditedYes => 'Yes';

  @override
  String get detailsDelivery => 'Delivery';

  @override
  String get detailsAttachments => 'Attachments';

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
      other: '$count new messages below',
      one: '1 new message below',
      zero: 'No new messages',
    );
    return '$_temp0';
  }

  @override
  String get connectionReconnecting => 'Reconnecting…';

  @override
  String get connectionOffline => 'Offline — pull to refresh';

  @override
  String get attachmentFallbackLabel => 'Attachment';

  @override
  String get composerJoinToSend => 'Join this chat to send messages';

  @override
  String get composerBanned => 'You are banned from this chat';

  @override
  String get composerMuted => 'You are muted in this chat';

  @override
  String get composerAdminsOnly => 'Only admins can post in this chat';

  @override
  String get composerNoPermission =>
      'You do not have permission to send messages here';

  @override
  String attachmentSelection(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0, $size';
  }

  @override
  String get attachmentReady => 'Ready to send';

  @override
  String attachMediaLimits(int count, String size) {
    return 'Up to $count, $size each';
  }

  @override
  String attachDocumentLimits(String size) {
    return 'One file, up to $size';
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
  String get chatSettings => 'Chat settings';

  @override
  String get chatSettingsNoPermission =>
      'Only an owner or admin can change this chat';

  @override
  String get chatNameCannotBeCleared =>
      'A name cannot be removed once the chat has one';

  @override
  String chatSlowModeRange(int max) {
    return '0 to $max seconds';
  }

  @override
  String get chatReactionsPickHint => 'Pick the emoji people may react with';

  @override
  String get chatNotMutedLabel => 'Notifications on';

  @override
  String get chatMutedToast => 'Notifications off for this chat';

  @override
  String get chatUnmutedToast => 'Notifications back on for this chat';

  @override
  String get muteForHour => 'Mute for 1 hour';

  @override
  String get muteForEightHours => 'Mute for 8 hours';

  @override
  String get muteForever => 'Mute until I turn it back on';

  @override
  String get leaveChatOwnerStuck =>
      'The chat creator cannot leave, and you no longer have permission to delete this chat.';

  @override
  String get chatInviteLink => 'Invite link';

  @override
  String get chatInviteLinkHint =>
      'Anyone signed in to ChatiX can open this link and join. It only opens in the app.';

  @override
  String get chatInviteLinkCopied => 'Invite link copied';

  @override
  String get sharedMedia => 'Media';

  @override
  String get sharedFiles => 'Files';

  @override
  String get sharedLinks => 'Links';

  @override
  String get sharedVoice => 'Voice';

  @override
  String get sharedMediaEmpty => 'No photos or videos here yet';

  @override
  String get sharedFilesEmpty => 'No files here yet';

  @override
  String get sharedLinksEmpty => 'No links here yet';

  @override
  String get sharedVoiceEmpty => 'No voice messages here yet';

  @override
  String get sharedContentLocalOnly =>
      'Shows what this device has loaded from the chat — the server has no shared-media index.';

  @override
  String get chatSettingsUnchanged => 'Nothing has changed yet';

  @override
  String get membersSearchHint => 'Search members';

  @override
  String get membersSearchLoadedOnly =>
      'Only the members loaded so far are searched.';

  @override
  String membersSearchEmpty(String query) {
    return 'No one here matches “$query”';
  }

  @override
  String get membersLoadMore => 'Load more people';

  @override
  String get membersSectionAdmins => 'Administration';

  @override
  String get membersSectionMembers => 'Members';

  @override
  String get membersSectionBanned => 'Banned members';

  @override
  String get membersBannedHint =>
      'Banned people cannot read or write here until the ban is lifted.';

  @override
  String get membersEmptyTitle => 'No members to show';

  @override
  String get membersEmptyInvite => 'Add someone to get this chat started.';

  @override
  String get membersEmptyNoInvite =>
      'Only members with the invite permission can add people here.';

  @override
  String get chatRoleOwner => 'Owner';

  @override
  String get chatRoleAdmin => 'Admin';

  @override
  String get chatRoleEditor => 'Editor';

  @override
  String get chatRoleDirect => 'Direct';

  @override
  String get chatRoleMember => 'Member';

  @override
  String get chatRoleViewer => 'Viewer';

  @override
  String get chatRoleUnknown => 'Unknown role';

  @override
  String get memberMutedBadge => 'Muted';

  @override
  String get memberBannedBadge => 'Banned';

  @override
  String get memberOpenProfile => 'Open profile';

  @override
  String get memberMessagePrivately => 'Message privately';

  @override
  String memberKickConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get memberKickConfirmBody =>
      'They lose access to this chat, but can be added again later.';

  @override
  String memberRoleChanged(String name, String role) {
    return '$name is now $role';
  }

  @override
  String memberKicked(String name) {
    return '$name was removed';
  }

  @override
  String memberBannedToast(String name) {
    return '$name was banned';
  }

  @override
  String memberUnbanned(String name) {
    return 'The ban on $name was lifted';
  }

  @override
  String get memberActionFailed => 'That did not go through. Please try again.';

  @override
  String get roleAssignHint => 'You can only assign roles below your own.';

  @override
  String get roleOwnerTransferHint =>
      'Owner is not in the list: the API has no way to hand a chat over.';

  @override
  String get banForHour => 'For an hour';

  @override
  String get banForDay => 'For a day';

  @override
  String get banForWeek => 'For a week';

  @override
  String get inviteMembersTitle => 'Add people';

  @override
  String get inviteRoleLabel => 'They join as';

  @override
  String inviteRoomLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Room for $count more people',
      one: 'Room for 1 more person',
      zero: 'This chat is full',
    );
    return '$_temp0';
  }

  @override
  String inviteChatFull(int limit) {
    return 'This chat holds $limit members, and it is full.';
  }

  @override
  String inviteAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count people',
      one: 'Add 1 person',
    );
    return '$_temp0';
  }

  @override
  String inviteAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people added',
      one: '1 person added',
    );
    return '$_temp0';
  }

  @override
  String inviteFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people could not be added',
      one: '1 person could not be added',
    );
    return '$_temp0';
  }

  @override
  String get inviteSearchStart =>
      'Find people by name or @username, then add them all at once.';

  @override
  String get inviteSelectionFull => 'That is everyone this chat has room for.';

  @override
  String peopleSearchNoneFound(String query) {
    return 'No one found for “$query”';
  }

  @override
  String get peopleSearchHint =>
      'Search matches any part of a name or @username.';

  @override
  String get profileShareAction => 'Share';

  @override
  String get profileShareCopied => 'Profile link copied';

  @override
  String get profileBirthday => 'Birthday';

  @override
  String get profileEmptyTitle => 'Nothing here yet';

  @override
  String get profileEmptyHintSelf =>
      'Add a few words about yourself so people know who they are talking to.';

  @override
  String get profileEmptyHintOther =>
      'This person has not filled in their profile.';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileAccountNoEmail => 'Signed in';

  @override
  String get profilePhoto => 'Photo';

  @override
  String get profileNoPhoto => 'No photo yet';

  @override
  String get profileOpenLinkFailed => 'Could not open this link';

  @override
  String get profileContactCopied => 'Copied to clipboard';

  @override
  String get profileCopyAction => 'Copy';

  @override
  String devicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
      zero: 'No devices',
    );
    return '$_temp0';
  }

  @override
  String get changePhoto => 'Change photo';

  @override
  String get choosePhoto => 'Choose a photo';

  @override
  String get avatarCropTitle => 'Move and scale';

  @override
  String get avatarCropHint => 'Drag to move, pinch to zoom.';

  @override
  String get avatarCropConfirm => 'Use photo';

  @override
  String get avatarStagePreparing => 'Preparing…';

  @override
  String get avatarStageUploading => 'Uploading…';

  @override
  String get avatarStageConfirming => 'Almost done…';

  @override
  String get avatarStageProcessing => 'Processing the photo…';

  @override
  String get avatarStageDone => 'Photo updated';

  @override
  String get avatarProcessingFailed => 'Could not update the photo';

  @override
  String get avatarProcessingFailedHint =>
      'The server did not accept that picture. Try another one.';

  @override
  String get avatarNotAnImage => 'That file is not an image';

  @override
  String get avatarTooLarge => 'That picture is too large. Pick a smaller one.';

  @override
  String get avatarUnreadable => 'That picture could not be opened';

  @override
  String get profileEditDetails => 'Details';

  @override
  String get profileEditLinks => 'Links';

  @override
  String get profileEditLinksHint =>
      'Links are saved the moment you add or remove one, separately from the form below.';

  @override
  String get profileNoLinks => 'No links yet';

  @override
  String get removeLink => 'Remove link';

  @override
  String get clearDateOfBirth => 'Clear date of birth';

  @override
  String get specializationHint => 'What you do, in a few words';

  @override
  String bioCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String get profileSkillsHint => 'Up to 30 characters each';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesMessage =>
      'Your edits to this profile will be lost.';

  @override
  String get discardAction => 'Discard';

  @override
  String get keepEditingAction => 'Keep editing';

  @override
  String get camera => 'Camera';

  @override
  String get loading => 'Loading…';

  @override
  String fieldTooLong(int max) {
    return 'At most $max characters';
  }

  @override
  String skillTooLong(String skill, int max) {
    return '“$skill” is longer than $max characters';
  }

  @override
  String callRoomName(String slug) {
    return 'Room $slug';
  }

  @override
  String get callJoinExplanation =>
      'A call here is a room: join it, and anyone else in this chat can join you.';

  @override
  String get callNoIncomingNotice =>
      'Ringing for incoming calls is not available yet — the server does not announce them.';

  @override
  String get callWaitingForOthers => 'Waiting for someone else to join…';

  @override
  String get callReconnecting => 'Reconnecting…';

  @override
  String get callYou => 'You';

  @override
  String callParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
      zero: 'No one here yet',
    );
    return '$_temp0';
  }

  @override
  String get callMicrophoneMute => 'Mute';

  @override
  String get callMicrophoneUnmute => 'Unmute';

  @override
  String get callCameraStart => 'Start video';

  @override
  String get callCameraStop => 'Stop video';

  @override
  String get callSpeakerOn => 'Speaker';

  @override
  String get callSpeakerOff => 'Earpiece';

  @override
  String get callLayoutGrid => 'Grid';

  @override
  String get callLayoutSpeaker => 'Speaker view';

  @override
  String callPinParticipant(String name) {
    return 'Pin $name';
  }

  @override
  String callUnpinParticipant(String name) {
    return 'Unpin $name';
  }

  @override
  String get callMuteForEveryone => 'Mute for everyone';

  @override
  String get callUnmuteForEveryone => 'Let them speak';

  @override
  String get callQualityExcellent => 'Excellent connection';

  @override
  String get callQualityGood => 'Good connection';

  @override
  String get callQualityPoor => 'Weak connection';

  @override
  String get callQualityLost => 'Connection lost';

  @override
  String get callMicrophonePermissionTitle => 'Let ChatiX use the microphone';

  @override
  String get callMicrophonePermissionBody =>
      'The others can only hear you if ChatiX may use the microphone. You can mute yourself again at any time.';

  @override
  String get callCameraPermissionTitle => 'Let ChatiX use the camera';

  @override
  String get callCameraPermissionBody =>
      'Your video is only sent while the camera is on, and you can turn it off at any time.';

  @override
  String get callPermissionContinue => 'Continue';

  @override
  String get callPermissionNotNow => 'Not now';

  @override
  String get callPermissionOpenSettings => 'Open settings';

  @override
  String get callMicrophoneBlocked =>
      'Microphone is off: ChatiX has no permission for it.';

  @override
  String get callCameraBlocked =>
      'Camera is off: ChatiX has no permission for it.';

  @override
  String get callSelfPreview => 'Your camera';

  @override
  String get callSelfPreviewHint => 'Drag to move';

  @override
  String get callShowControls => 'Show call controls';

  @override
  String get callOngoingInChat => 'You are in a call in this chat';

  @override
  String get callReturn => 'Return';

  @override
  String callMiniPlayerLabel(String name) {
    return 'Call with $name';
  }

  @override
  String get callMinimize => 'Minimize call';

  @override
  String get callDismiss => 'Dismiss';
}
