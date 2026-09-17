// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flutter Riverpod Clean Architecture';

  @override
  String get welcomeMessage => 'Welcome to Flutter Riverpod Clean Architecture';

  @override
  String get home => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get profile => 'Profile';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get systemMode => 'System Mode';

  @override
  String get language => 'Language';

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
  String get logout => 'Logout';

  @override
  String get login => 'Login';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign In';

  @override
  String get register => 'Register';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get tryAgain => 'Try Again';

  @override
  String greeting(String name) {
    return 'Hello, $name!';
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
      other: '$countString items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String lastUpdated(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Last updated: $dateString';
  }

  @override
  String get browsePeople => 'People';

  @override
  String get chatDirect => 'Direct chat';

  @override
  String get chatGroup => 'Group';

  @override
  String get chatSupergroup => 'Supergroup';

  @override
  String get chatChannel => 'Channel';

  @override
  String get chatFallbackTitle => 'Chat';

  @override
  String membersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String get attachmentProcessing => 'Processing…';

  @override
  String get attachmentFailed => 'Upload failed';

  @override
  String get attachmentOpenFailed => 'Could not open this file';

  @override
  String get imageLoadFailed => 'Image unavailable';

  @override
  String get close => 'Close';

  @override
  String get addReaction => 'Add a reaction';

  @override
  String get reactionsDisabled => 'Reactions are off in this chat';

  @override
  String reactionLimitReached(Object limit) {
    return 'You can add up to $limit reactions per message';
  }

  @override
  String get messageNotFound => 'That message is no longer available';

  @override
  String get chatInfo => 'Chat info';

  @override
  String get chatName => 'Name';

  @override
  String get chatDescription => 'Description';

  @override
  String get chatPublic => 'Public chat';

  @override
  String get chatPublicHint => 'Anyone with the link can join';

  @override
  String get chatAdminOnly => 'Admins only';

  @override
  String get chatAdminOnlyHint => 'Only admins can post';

  @override
  String get chatSlowMode => 'Slow mode';

  @override
  String get chatSlowModeOff => 'Off';

  @override
  String chatSlowModeSeconds(Object seconds) {
    return '${seconds}s between messages';
  }

  @override
  String get chatReactionsMode => 'Reactions';

  @override
  String get chatReactionsAll => 'Everyone, any emoji';

  @override
  String get chatReactionsSome => 'Only selected emoji';

  @override
  String get chatReactionsNone => 'Turned off';

  @override
  String get leaveChat => 'Leave chat';

  @override
  String get leaveChatConfirm =>
      'Leave this chat? You will stop receiving its messages.';

  @override
  String get leaveChatOwnerBlocked =>
      'The chat creator cannot leave — delete the chat instead.';

  @override
  String get deleteChat => 'Delete chat';

  @override
  String get deleteChatConfirm =>
      'Delete this chat for everyone? This cannot be undone.';

  @override
  String get saveChanges => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get chatSettingsSaved => 'Chat updated';

  @override
  String get viewMembers => 'Members';

  @override
  String get messageEdited => 'edited';

  @override
  String get messageReply => 'Reply';

  @override
  String get messageForward => 'Forward';

  @override
  String get messageEdit => 'Edit';

  @override
  String get messageDelete => 'Delete';

  @override
  String get messageSelect => 'Select';

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
  String get backToLatest => 'Back to latest messages';

  @override
  String get messageRead => 'Read';

  @override
  String get messageSent => 'Sent';

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get unreadMessages => 'Unread messages';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get editingMessage => 'Editing message';

  @override
  String get scrollToBottom => 'Jump to the newest messages';

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
  String get messageDensity => 'Message density';

  @override
  String get densityCompact => 'Compact';

  @override
  String get densityCozy => 'Cozy';

  @override
  String get densityComfortable => 'Comfortable';

  @override
  String get voiceSlideToCancel => 'Slide left to cancel, up to lock';

  @override
  String get voiceReleaseToCancel => 'Release to cancel';

  @override
  String get voiceRecordingLocked => 'Recording — tap send when you are done';

  @override
  String get voiceLimitReached => 'Maximum length reached';

  @override
  String get voicePermissionDenied => 'Microphone access is off';

  @override
  String get voiceMessage => 'Voice message';

  @override
  String get voicePlay => 'Play voice message';

  @override
  String get voicePause => 'Pause voice message';

  @override
  String get voiceUnavailable => 'Unavailable';

  @override
  String get voiceNotListened => 'Not listened to yet';

  @override
  String voiceSpeedLabel(String speed) {
    return 'Playback speed $speed';
  }

  @override
  String get voiceRecording => 'Recording';

  @override
  String voiceTimeLeft(String time) {
    return '$time left';
  }

  @override
  String get voiceCancelRecording => 'Cancel';

  @override
  String get voiceSendRecording => 'Send voice message';

  @override
  String get attach => 'Attach';

  @override
  String get messageHint => 'Message';

  @override
  String get unknownChat => 'Unknown chat';

  @override
  String get unknownProfile => 'Unknown profile';

  @override
  String get goToChats => 'Go to chats';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String pathDoesNotExist(String path) {
    return '$path does not exist';
  }

  @override
  String get retry => 'Retry';

  @override
  String get clear => 'Clear';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get readAll => 'Read all';

  @override
  String get filter => 'Filter';

  @override
  String get filterAll => 'All';

  @override
  String get filterUnread => 'Unread only';

  @override
  String get filterRead => 'Read only';

  @override
  String get showAll => 'Show all';

  @override
  String get notificationsLoadFailed => 'Could not load your notifications.';

  @override
  String get profiles => 'People';

  @override
  String get searchByName => 'Search by name';

  @override
  String get searchByUsername => 'Search by username';

  @override
  String get searchPeopleHint => 'Search by name or @username';

  @override
  String get profilesLoadFailed => 'Could not load profiles.';

  @override
  String get signInToViewProfile => 'Sign in to view your profile';

  @override
  String get signInToEditProfile => 'Sign in to edit your profile';

  @override
  String get profileAbout => 'About';

  @override
  String get profileSkills => 'Skills';

  @override
  String get profileContacts => 'Contacts';

  @override
  String get sendMessageAction => 'Message';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get displayName => 'Display name';

  @override
  String get specialization => 'Specialization';

  @override
  String get bio => 'Bio';

  @override
  String get dateOfBirth => 'Date of birth';

  @override
  String get addContact => 'Add contact';

  @override
  String get contactProvider => 'Provider (e.g. telegram)';

  @override
  String get contactHandle => 'Contact (e.g. @handle)';

  @override
  String get skillsHint => 'Type a skill and press enter';

  @override
  String get photoLibraryFailed => 'Could not open the photo library';

  @override
  String get chats => 'Chats';

  @override
  String get searchChatsAndPeople => 'Search chats and people';

  @override
  String get chatsLoadFailed => 'Could not load your chats.';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get noChatsYetHint => 'Start a conversation and it will show up here.';

  @override
  String get newChat => 'New chat';

  @override
  String get chatTypeDirect => 'Direct';

  @override
  String get chatTypeGroup => 'Group';

  @override
  String get chatTypeSuper => 'Super';

  @override
  String get chatTypeChannel => 'Channel';

  @override
  String get chatPublicHintCreate => 'Anyone can find and join this chat';

  @override
  String get chatSlowModeSecondsField => 'Slow mode (seconds)';

  @override
  String get createChat => 'Create chat';

  @override
  String get membersTitle => 'Members';

  @override
  String get membersLoadFailed => 'Failed to load members';

  @override
  String get addMember => 'Add member';

  @override
  String get changeRole => 'Change role';

  @override
  String get banMember => 'Ban';

  @override
  String get banMemberTitle => 'Ban member';

  @override
  String get kickMember => 'Remove';

  @override
  String get banReason => 'Reason (optional)';

  @override
  String get banUntil => 'Set date';

  @override
  String get searchPeople => 'People';

  @override
  String get noPeopleFound => 'No people found';

  @override
  String get callConnecting => 'Connecting…';

  @override
  String get callJoin => 'Join call';

  @override
  String get callEnded => 'Call ended';

  @override
  String get callRejoin => 'Rejoin';

  @override
  String get callLeave => 'Leave';

  @override
  String get callTitle => 'Call';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String deleteMessagesTitle(int count) {
    return 'Delete $count messages?';
  }

  @override
  String get cannotBeUndone => 'This cannot be undone.';

  @override
  String get chatLoadFailed => 'Failed to load chat';

  @override
  String get attachMedia => 'Photos & videos';

  @override
  String get attachDocument => 'Document';

  @override
  String get messageForwarded => 'Message forwarded';

  @override
  String get forwardTo => 'Forward to';

  @override
  String get noOtherChats => 'No other chats';

  @override
  String get chatsLoadFailedShort => 'Could not load chats';

  @override
  String get messageWaitingToSend => 'Waiting to send';

  @override
  String get messageNotSent => 'Not sent';

  @override
  String get connectionBusy => 'Connecting…';

  @override
  String get connectionWaitingForNetwork => 'Waiting for network';

  @override
  String get wsDiagnostics => 'Connection diagnostics';

  @override
  String wsDiagnosticsFrames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frames recorded',
      one: '1 frame recorded',
      zero: 'No frames recorded',
    );
    return '$_temp0';
  }

  @override
  String get wsDiagnosticsCopied => 'Diagnostics copied';

  @override
  String get discard => 'Discard';

  @override
  String get reactedTitle => 'Reacted';

  @override
  String get noReactionsYet => 'Nobody has reacted with this yet';

  @override
  String get showMore => 'Show more';

  @override
  String get bulkForwarding => 'Forwarding';

  @override
  String get bulkDeleting => 'Deleting';

  @override
  String bulkProgress(String label, int done, int total) {
    return '$label $done of $total…';
  }

  @override
  String bulkComplete(String label, int total) {
    return '$label complete ($total)';
  }

  @override
  String bulkPartial(int done, int total, int failed, String reason) {
    return '$done of $total succeeded — $failed failed: $reason';
  }

  @override
  String get callTokenUnavailable => 'Could not start the call';

  @override
  String get loginTitle => 'Login';

  @override
  String get emailOrUsername => 'Email or username';

  @override
  String get emailOrUsernameHint => 'you@example.com or your username';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get logIn => 'Log In';

  @override
  String get username => 'Username';

  @override
  String get usernameHint => '4-100 characters';

  @override
  String get emailHint => 'Enter your email';

  @override
  String get passwordRule => '8+ chars, upper/lower/digit/special';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get confirmPasswordHint => 'Confirm your password';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get setNewPassword => 'Set new password';

  @override
  String get resetCode => 'Reset code';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get passwordUpdated => 'Password updated — please log in.';

  @override
  String get sendCode => 'Send code';

  @override
  String get haveCodeAlready => 'I already have a code';

  @override
  String get resetCodeSent => 'Check your email for a reset code.';

  @override
  String get verifyEmailTitle => 'Verify email';

  @override
  String get verifyEmailHint => 'Paste the token from the email we sent you.';

  @override
  String get verificationToken => 'Verification token';

  @override
  String get verify => 'Verify';

  @override
  String get resendLimitHint => 'We can resend it — up to 3 times per hour.';

  @override
  String get resendVerification => 'Resend verification email';

  @override
  String get emailVerified => 'Email verified';

  @override
  String get verificationSent => 'Verification email sent — check your inbox.';

  @override
  String get browserOpenFailed => 'Could not open the browser for sign-in';

  @override
  String continueWith(String provider) {
    return 'Continue with $provider';
  }

  @override
  String get peopleSearchFailed => 'Could not search for people';

  @override
  String get startChatFailed => 'Could not start a chat with this person';

  @override
  String get profileLoadFailed => 'Could not load this profile';

  @override
  String get myProfileLoadFailed => 'Could not load your profile';

  @override
  String get saveChangesFailed => 'Could not save changes';

  @override
  String get avatarUpdateFailed => 'Could not update avatar';

  @override
  String get oauthCancelled => 'Sign-in was cancelled';

  @override
  String get oauthCancelledHint =>
      'Nothing was changed. Try again, or use your username and password.';

  @override
  String get oauthFailed => 'Could not finish signing in';

  @override
  String get oauthFailedHint =>
      'Sign in with your username and password instead.';

  @override
  String get realtimeRejected => 'Live updates are off for this chat';

  @override
  String get forwardComment => 'Add a comment (optional)';

  @override
  String get forwardAction => 'Forward';

  @override
  String get banDuration => 'How long';

  @override
  String get banForever => 'Permanently';

  @override
  String get banUntilDate => 'Until a date';

  @override
  String get banLift => 'Lift the ban';

  @override
  String get banLiftHint =>
      'Sends a past date, which the server reads as an unban';

  @override
  String get banPickDate => 'Pick a date';

  @override
  String get myDevices => 'My devices';

  @override
  String get devicesLoadFailed => 'Could not load your devices.';

  @override
  String get noDevices => 'No active sessions';

  @override
  String get deviceActive => 'Active';

  @override
  String get deviceInactive => 'Signed out';

  @override
  String deviceLastActive(String date) {
    return 'Last active $date';
  }

  @override
  String get designSystem => 'Design system';

  @override
  String get accentColor => 'Accent color';

  @override
  String get chatWallpaper => 'Chat wallpaper';

  @override
  String get wallpaperAurora => 'Aurora';

  @override
  String get wallpaperMesh => 'Mesh';

  @override
  String get wallpaperPlain => 'Plain';

  @override
  String get textSize => 'Text size';

  @override
  String get textSizeSmall => 'Small';

  @override
  String get textSizeDefault => 'Default';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get textSizeExtraLarge => 'Extra large';

  @override
  String get resetAppearance => 'Reset appearance';

  @override
  String get showcaseAccents => 'Accents';

  @override
  String get showcaseNeutrals => 'Neutrals';

  @override
  String get showcaseNeutralsLight => 'Light ramp';

  @override
  String get showcaseNeutralsDark => 'Dark ramp';

  @override
  String get showcaseRadii => 'Radii';

  @override
  String get showcaseSpacing => 'Spacing';

  @override
  String get showcaseElevation => 'Elevation';

  @override
  String get showcaseMotion => 'Motion';

  @override
  String get showcaseMotionFast => 'Fast';

  @override
  String get showcaseMotionBase => 'Base';

  @override
  String get showcaseMotionSlow => 'Slow';

  @override
  String get showcaseMotionReplay => 'Replay';

  @override
  String get showcaseTypography => 'Typography';

  @override
  String get showcaseTabularFigures => 'Tabular figures';

  @override
  String get showcaseBubbles => 'Message bubbles';

  @override
  String get showcaseReactions => 'Reactions';

  @override
  String get showcaseAuthors => 'Author accents';

  @override
  String get showcaseComponents => 'Components';

  @override
  String get showcaseIncomingSample => 'Incoming: warm surface, one hairline.';

  @override
  String get showcaseStackedSample => 'Second message in the same run.';

  @override
  String get showcaseOutgoingSample => 'Outgoing: accent gradient.';

  @override
  String get messageSending => 'Sending';

  @override
  String get onlineNow => 'Online';

  @override
  String userTyping(String name) {
    return '$name is typing…';
  }

  @override
  String severalTyping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people are typing…',
      one: '1 person is typing…',
    );
    return '$_temp0';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String get contacts => 'Contacts';

  @override
  String get profileSettingsHint => 'Your name, avatar and contact details';

  @override
  String get noChatSelected => 'No chat selected';

  @override
  String get noChatSelectedHint =>
      'Pick a conversation from the list to start reading.';

  @override
  String get newDirectChat => 'New direct chat';

  @override
  String get newGroup => 'New group';

  @override
  String get newChannel => 'New channel';

  @override
  String get quickActionsHint => 'Start something new';

  @override
  String unreadMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
      zero: 'No unread messages',
    );
    return '$_temp0';
  }

  @override
  String unreadNotificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new notifications',
      one: '1 new notification',
      zero: 'No new notifications',
    );
    return '$_temp0';
  }

  @override
  String get noContactsFound => 'Nobody matches that name';

  @override
  String get noContactsFoundHint =>
      'Try a shorter or differently spelled name.';

  @override
  String get noContactsYet => 'No people to show yet';

  @override
  String get previewYou => 'You';

  @override
  String get previewPhoto => 'Photo';

  @override
  String get previewVideo => 'Video';

  @override
  String get previewVoice => 'Voice message';

  @override
  String get previewVideoNote => 'Video message';

  @override
  String get previewFile => 'File';

  @override
  String get previewNoText => 'Message';

  @override
  String get draftLabel => 'Draft:';

  @override
  String get markAsRead => 'Mark as read';

  @override
  String get archiveChat => 'Archive';

  @override
  String get unarchiveChat => 'Unarchive';

  @override
  String get pinChat => 'Pin';

  @override
  String get unpinChat => 'Unpin';

  @override
  String get muteChat => 'Mute';

  @override
  String get unmuteChat => 'Unmute';

  @override
  String get archivedChats => 'Archived';

  @override
  String get chatPinnedLabel => 'Pinned';

  @override
  String get chatMutedLabel => 'Notifications off';

  @override
  String get chatArchivedToast => 'Chat archived';

  @override
  String get chatDeletedToast => 'Chat deleted';

  @override
  String get undo => 'Undo';

  @override
  String get allChatsArchived => 'Everything is archived';

  @override
  String previewVoiceWithDuration(String duration) {
    return 'Voice message $duration';
  }

  @override
  String archivedChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '1 chat',
    );
    return '$_temp0';
  }

  @override
  String get chatFolders => 'Folders';

  @override
  String get chatFoldersAll => 'All chats';

  @override
  String get folderPresetUnread => 'Unread';

  @override
  String get folderPresetPersonal => 'Personal';

  @override
  String get folderPresetGroups => 'Groups';

  @override
  String get folderPresetChannels => 'Channels';

  @override
  String get folderPresetNoReply => 'Awaiting my reply';

  @override
  String get newFolder => 'New folder';

  @override
  String get editFolder => 'Edit folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get folderIcon => 'Icon';

  @override
  String get folderRules => 'Rules';

  @override
  String get folderMatchModeTitle => 'A chat belongs here when';

  @override
  String get folderMatchAll => 'It meets every rule';

  @override
  String get folderMatchAny => 'It meets any rule';

  @override
  String get addFolderRule => 'Add rule';

  @override
  String get removeFolderRule => 'Remove rule';

  @override
  String get folderRuleChatType => 'Chat type';

  @override
  String folderRuleChatTypeIn(String types) {
    return 'Type is $types';
  }

  @override
  String get folderRuleUnread => 'Has unread messages';

  @override
  String get folderRuleRead => 'Has nothing unread';

  @override
  String get folderRulePinned => 'Is pinned';

  @override
  String get folderRuleNotPinned => 'Is not pinned';

  @override
  String get folderRuleNoReply => 'Waiting for my reply';

  @override
  String folderRuleNoReplyDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Waiting for my reply for over $days days',
      one: 'Waiting for my reply for over 1 day',
      zero: 'Waiting for my reply',
    );
    return '$_temp0';
  }

  @override
  String get folderRuleDaysLabel => 'Days without my reply';

  @override
  String get folderRuleDaysAny => 'Any';

  @override
  String get folderRuleMember => 'Includes a person';

  @override
  String folderRuleMemberNamed(String name) {
    return 'Includes $name';
  }

  @override
  String get folderRulePickPerson => 'Choose a person';

  @override
  String get folderRuleNoPeople =>
      'People appear here once you have chats with them';

  @override
  String get folderRuleMemberLocalNote =>
      'Matches on what the chat list already knows: you, anyone whose roster is loaded, the last sender and the chat\'s creator.';

  @override
  String get deleteFolder => 'Delete folder';

  @override
  String get deleteFolderConfirm =>
      'Delete this folder? The chats in it stay where they are.';

  @override
  String get folderNameRequired => 'Give the folder a name';

  @override
  String folderNameTooLong(int count) {
    return 'Folder names are limited to $count characters';
  }

  @override
  String get folderRulesRequired => 'Add at least one rule';

  @override
  String folderLimitReached(int count) {
    return 'You can keep up to $count folders';
  }

  @override
  String pinLimitReached(int count) {
    return 'Only $count chats can be pinned. Unpin one first.';
  }

  @override
  String get foldersEmpty => 'No folders yet';

  @override
  String get foldersEmptyHint =>
      'A folder is a set of rules, not a list. Chats join and leave it on their own.';

  @override
  String get folderReadyMade => 'Ready-made';

  @override
  String get folderYours => 'Your folders';

  @override
  String folderRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return '$_temp0';
  }

  @override
  String get folderEmptyChats => 'Nothing in this folder';

  @override
  String get folderEmptyChatsHint =>
      'Chats show up here as soon as they meet its rules.';

  @override
  String get hideFolderTabs => 'Hide the folder strip';

  @override
  String get hideFolderTabsHint =>
      'Keeps your folders without showing the tabs above the list';

  @override
  String get unarchiveOnNewMessage => 'Bring back on new message';

  @override
  String get unarchiveOnNewMessageHint =>
      'An archived chat returns to the list when someone writes in it';

  @override
  String get organizerDeviceOnly =>
      'Folders are kept on this device and do not follow your account. Pins, the archive and silenced chats do.';

  @override
  String get chatPinnedZone => 'Pinned';

  @override
  String get chatUnarchivedToast => 'Moved back to the list';

  @override
  String get searchTabMessages => 'Messages';

  @override
  String get searchEverything => 'Search chats, people and messages';

  @override
  String get searchRecentQueries => 'Recent searches';

  @override
  String get searchRecentChats => 'Recently opened';

  @override
  String get searchClearHistory => 'Clear';

  @override
  String get searchRemoveFromHistory => 'Remove from recent searches';

  @override
  String get searchStartTitle => 'Find a chat, a person or a message';

  @override
  String get searchStartHint =>
      'Chats are matched by name, people by username, messages by what they say.';

  @override
  String get searchLoadedHistoryOnly => 'Searched what is on this device';

  @override
  String get searchLoadedHistoryExplained =>
      'The server could not be reached, so this searched the messages already on this device.';

  @override
  String get noChatsFound => 'No chats found';

  @override
  String get noChatsFoundHint =>
      'Chats are matched by name and description, among the ones already loaded.';

  @override
  String get noPeopleFoundHint =>
      'Try another spelling, or search by username.';

  @override
  String get noMessagesFound => 'No messages found';

  @override
  String get messageSearchFailed => 'Could not search messages';

  @override
  String get searchInChat => 'Search in this chat';

  @override
  String searchMatchPosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String get searchNoMatches => 'No matches';

  @override
  String get searchOlderMatch => 'Older match';

  @override
  String get searchNewerMatch => 'Newer match';

  @override
  String get searchInChatHint => 'Search in this chat';

  @override
  String get searchChatDescriptionMatch => 'Matched in the description';

  @override
  String get searchOpenChat => 'Open chat';

  @override
  String get reactionSectionRecent => 'Recently used';

  @override
  String get reactionSectionFaces => 'Smileys';

  @override
  String get reactionSectionPeople => 'People';

  @override
  String get reactionSectionHearts => 'Hearts';

  @override
  String get reactionSectionCelebration => 'Celebration';

  @override
  String get reactionSectionFood => 'Food';

  @override
  String get reactionSectionNature => 'Nature';

  @override
  String get reactionSectionSymbols => 'Symbols';

  @override
  String get reactionsNoneAllowed => 'No reactions are available in this chat';

  @override
  String reactionsUsed(int used, int limit) {
    return '$used of $limit';
  }

  @override
  String reactionMessageLimitReached(Object limit) {
    return 'This message already has $limit different reactions';
  }

  @override
  String get moreReactions => 'More reactions';

  @override
  String get reactionFailed => 'Reaction not saved';

  @override
  String get reactionTooFast => 'Too many reactions at once';

  @override
  String get reactionNotAllowed => 'That reaction is not allowed here';

  @override
  String get reactionsNobody => 'Nobody yet';

  @override
  String reactionUserFallback(Object id) {
    return 'User $id';
  }

  @override
  String composerCharactersLeft(int count) {
    return '$count left';
  }

  @override
  String get composerSendLabel => 'Send';

  @override
  String get composerSaveEditLabel => 'Save changes';

  @override
  String get composerRecordLabel => 'Hold to record a voice message';

  @override
  String composerReplyingTo(Object name) {
    return 'Reply to $name';
  }

  @override
  String composerSlowModeWait(int seconds) {
    return 'Slow mode: ${seconds}s to wait';
  }

  @override
  String composerSlowModeHint(int seconds) {
    return 'This chat allows one message every $seconds s';
  }

  @override
  String get attachSheetTitle => 'Attach';

  @override
  String get attachRecent => 'Recent';

  @override
  String get attachCamera => 'Camera';

  @override
  String get attachVoice => 'Voice message';

  @override
  String get attachVideoNote => 'Video note';

  @override
  String attachVoiceHint(int seconds) {
    return 'Sent on its own, up to $seconds s';
  }

  @override
  String attachVideoNoteHint(int seconds, int pixels) {
    return 'Sent on its own, up to $seconds s and $pixels px';
  }

  @override
  String get attachGalleryDenied => 'Allow photo access to pick from here';

  @override
  String get attachGalleryAllow => 'Allow';

  @override
  String attachMediaFull(int count) {
    return 'Up to $count photos or videos per message';
  }

  @override
  String attachSendCount(int count) {
    return 'Attach $count';
  }

  @override
  String get attachUnavailable => 'That file could not be read';

  @override
  String videoNoteTooLarge(int pixels) {
    return 'This camera records above $pixels px, which the server rejects for video notes';
  }

  @override
  String composerTooLongBy(int count) {
    return '$count over the limit';
  }

  @override
  String get videoNoteTapToRecord => 'Tap to record';

  @override
  String get videoNoteNoCamera => 'This device has no camera to record with';

  @override
  String get videoNoteCameraDenied =>
      'Allow camera and microphone access to record a video note';

  @override
  String get videoNoteCameraFailed => 'The camera could not be started';

  @override
  String get videoNoteDiscarded => 'Nothing was recorded';

  @override
  String get attachmentOpen => 'Open';

  @override
  String attachmentSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get attachmentSaveFailed => 'Could not save this file';

  @override
  String get attachmentUploading => 'Uploading';

  @override
  String mediaViewerCounter(int index, int count) {
    return '$index of $count';
  }

  @override
  String get mediaViewerUnavailable => 'This media is no longer available';

  @override
  String get mediaPreviewHint => 'Remove anything you did not mean to send';

  @override
  String get mediaPreviewCaptionHint => 'Add a caption';

  @override
  String get mediaPreviewRemove => 'Remove';

  @override
  String get composerRecordVideoNoteLabel => 'Hold to record a video note';

  @override
  String get composerSwitchToVideoNote => 'Switch to video note';

  @override
  String get composerSwitchToVoice => 'Switch to voice message';

  @override
  String get videoNoteSwitchCamera => 'Switch camera';

  @override
  String get videoNoteDoubleTapToSwitch => 'Double-tap to switch camera';

  @override
  String get videoNoteOpeningCamera => 'Opening the camera…';

  @override
  String get videoNoteHoldToRecord => 'Hold to record';

  @override
  String get videoNoteSend => 'Send video note';

  @override
  String get videoNoteRecordingLabel => 'Recording a video note';

  @override
  String get videoNoteTapForSound => 'Tap for sound';

  @override
  String get videoNoteTapToMute => 'Tap to mute';

  @override
  String get videoNoteHoldForFullScreen => 'Hold for full screen';

  @override
  String videoNotePlayerLabel(String duration) {
    return 'Video note, $duration';
  }

  @override
  String get videoNoteAutoplayOff => 'Tap to play';

  @override
  String get mediaAutoplay => 'Autoplay video notes';

  @override
  String get mediaAutoplayHint =>
      'Video notes start silently when they scroll into view. Sound comes on when you tap one.';

  @override
  String get mediaAutoplayAlways => 'Always';

  @override
  String get mediaAutoplayWifi => 'Wi-Fi only';

  @override
  String get mediaAutoplayNever => 'Never';

  @override
  String get videoNotePreview => 'Camera preview';

  @override
  String searchTypeMore(int count) {
    return 'Type at least $count characters';
  }

  @override
  String get noMessagesFoundHint =>
      'Search looks inside what was said, not at file names or chat titles.';

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

  @override
  String get notificationNewMessage => 'New message';

  @override
  String get notificationReplyHint => 'Message';

  @override
  String get notificationReplyFailed => 'Your reply was not sent';

  @override
  String get notificationActionFailed => 'That could not be done';

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get notificationSoundTitle => 'Sound';

  @override
  String get notificationSoundSubtitle => 'Play a sound when something arrives';

  @override
  String get notificationVibrationTitle => 'Vibration';

  @override
  String get notificationVibrationSubtitle => 'Vibrate when something arrives';

  @override
  String get notificationPreviewTitle => 'Message preview';

  @override
  String get notificationPreviewSubtitle => 'Show who wrote and what they said';

  @override
  String get quietHoursTitle => 'Quiet hours';

  @override
  String get quietHoursSubtitle =>
      'Notifications still arrive, just without a sound';

  @override
  String get quietHoursFrom => 'From';

  @override
  String get quietHoursTo => 'Until';

  @override
  String get chatNotificationsTitle => 'Per-chat exceptions';

  @override
  String get chatNotificationsEmpty => 'No exceptions yet';

  @override
  String get chatNotificationsEmptyHint =>
      'Every chat follows the settings above. Change one from inside the chat.';

  @override
  String get chatNotificationsReset => 'Reset all';

  @override
  String get chatNotificationProfileTitle => 'Notifications from this chat';

  @override
  String get chatNotificationProfileAll => 'All messages';

  @override
  String get chatNotificationProfileMentions => 'Mentions only';

  @override
  String get chatNotificationProfileOff => 'Nothing';

  @override
  String get notificationPermissionOffTitle => 'Notifications are switched off';

  @override
  String get notificationPermissionOffHint =>
      'Nothing below can reach you until you allow notifications in system settings.';

  @override
  String get notificationsEmptyTitle => 'No notifications yet';

  @override
  String get notificationsEmptyMessage =>
      'Invites, mentions and messages show up here.';

  @override
  String get notificationsEmptyUnread => 'Nothing unread';

  @override
  String get notificationsEmptyRead => 'Nothing read yet';

  @override
  String get notificationsEmptyFilterHint =>
      'Switch the filter to “All” to see everything.';

  @override
  String get timeJustNow => 'Just now';

  @override
  String notificationsMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications marked as read',
      one: '1 notification marked as read',
      zero: 'Nothing was unread',
    );
    return '$_temp0';
  }

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hr ago',
      one: '1 hr ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'Yesterday',
    );
    return '$_temp0';
  }
}
