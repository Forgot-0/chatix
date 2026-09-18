import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';

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
    Locale('es'),
    Locale('fr'),
    Locale('de'),
    Locale('ja'),
    Locale('bn'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Flutter Riverpod Clean Architecture'**
  String get appTitle;

  /// The welcome message displayed on the home screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to Flutter Riverpod Clean Architecture'**
  String get welcomeMessage;

  /// Label for the home tab or button
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Label for the settings tab or button
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Label for the profile tab or button
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Label for the dark mode option
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Label for the light mode option
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// Label for the system theme mode option
  ///
  /// In en, this message translates to:
  /// **'System Mode'**
  String get systemMode;

  /// Label for the language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Label for changing the application language
  ///
  /// In en, this message translates to:
  /// **'Change application language'**
  String get change_language;

  /// Label for theme selection
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Label for changing the application theme
  ///
  /// In en, this message translates to:
  /// **'Change application theme'**
  String get change_theme;

  /// Label for notifications settings
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Label for notification settings description
  ///
  /// In en, this message translates to:
  /// **'Configure notification preferences'**
  String get notification_settings;

  /// Label for the localization demo option
  ///
  /// In en, this message translates to:
  /// **'Localization Demo'**
  String get localization_demo;

  /// Description for the localization demo option
  ///
  /// In en, this message translates to:
  /// **'View localization features in action'**
  String get localization_demo_description;

  /// Title for the language settings screen
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get language_settings;

  /// Instruction to select a language
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get select_your_language;

  /// Explanation of the language selection effects
  ///
  /// In en, this message translates to:
  /// **'The selected language will be applied across the entire application'**
  String get language_explanation;

  /// Title for the localization assets demo screen
  ///
  /// In en, this message translates to:
  /// **'Localization & Assets Demo'**
  String get localization_assets_demo;

  /// Label for displaying current language info
  ///
  /// In en, this message translates to:
  /// **'Current Language'**
  String get current_language;

  /// Label for language code
  ///
  /// In en, this message translates to:
  /// **'Language code'**
  String get language_code;

  /// Label for language name
  ///
  /// In en, this message translates to:
  /// **'Language name'**
  String get language_name;

  /// Title for formatting examples section
  ///
  /// In en, this message translates to:
  /// **'Formatting Examples'**
  String get formatting_examples;

  /// Label for full date format example
  ///
  /// In en, this message translates to:
  /// **'Date (full)'**
  String get date_full;

  /// Label for short date format example
  ///
  /// In en, this message translates to:
  /// **'Date (short)'**
  String get date_short;

  /// Label for time format example
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Label for currency format example
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// Label for percent format example
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get percent;

  /// Title for localized assets section
  ///
  /// In en, this message translates to:
  /// **'Localized Assets'**
  String get localized_assets;

  /// Explanation of localized assets feature
  ///
  /// In en, this message translates to:
  /// **'This section demonstrates how to load different assets based on the selected language. Images, audio, and other resources can be language-specific.'**
  String get localized_assets_explanation;

  /// Title for localized image example
  ///
  /// In en, this message translates to:
  /// **'Localized Image Example'**
  String get image_example;

  /// Caption for the welcome image example
  ///
  /// In en, this message translates to:
  /// **'This image is loaded based on your selected language'**
  String get welcome_image_caption;

  /// Title for common image example
  ///
  /// In en, this message translates to:
  /// **'Common Image Example'**
  String get common_image_example;

  /// Caption for the common image example
  ///
  /// In en, this message translates to:
  /// **'This image is the same across all languages'**
  String get common_image_caption;

  /// Label for the logout button
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Label for the login button
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Label for the email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Label for the password field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Label for the sign in button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Label for the register button
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Label for the forgot password button
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// Label for the try again button
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// A greeting message with the person's name
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}!'**
  String greeting(String name);

  /// A plural message based on an item count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String itemCount(num count);

  /// When something was last updated
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String lastUpdated(DateTime date);

  /// Tooltip for the action that opens the people directory
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get browsePeople;

  /// Fallback title for a 1:1 chat with an unidentified peer
  ///
  /// In en, this message translates to:
  /// **'Direct chat'**
  String get chatDirect;

  /// Fallback title for a group chat
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get chatGroup;

  /// Fallback title for a supergroup chat
  ///
  /// In en, this message translates to:
  /// **'Supergroup'**
  String get chatSupergroup;

  /// Fallback title for a channel
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get chatChannel;

  /// Generic fallback when a chat has no name at all
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatFallbackTitle;

  /// Member count shown under a chat title
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No members} =1{1 member} other{{count} members}}'**
  String membersCount(num count);

  /// Attachment is still being validated by the backend
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get attachmentProcessing;

  /// Attachment ended in attachment_status = error
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get attachmentFailed;

  /// Shown when the download URL could not be fetched or launched
  ///
  /// In en, this message translates to:
  /// **'Could not open this file'**
  String get attachmentOpenFailed;

  /// Placeholder when an image attachment fails to render
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get imageLoadFailed;

  /// Generic close action
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Tooltip/label for opening the emoji reaction panel
  ///
  /// In en, this message translates to:
  /// **'Add a reaction'**
  String get addReaction;

  /// Chat reactions_mode = none
  ///
  /// In en, this message translates to:
  /// **'Reactions are off in this chat'**
  String get reactionsDisabled;

  /// MAX_REACTIONS_PER_USER_PER_MESSAGE reached
  ///
  /// In en, this message translates to:
  /// **'You can add up to {limit} reactions per message'**
  String reactionLimitReached(Object limit);

  /// Jump target was deleted or is out of reach
  ///
  /// In en, this message translates to:
  /// **'That message is no longer available'**
  String get messageNotFound;

  /// Title of the chat information screen
  ///
  /// In en, this message translates to:
  /// **'Chat info'**
  String get chatInfo;

  /// Chat name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get chatName;

  /// Chat description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get chatDescription;

  /// is_public toggle
  ///
  /// In en, this message translates to:
  /// **'Public chat'**
  String get chatPublic;

  /// is_public explanation
  ///
  /// In en, this message translates to:
  /// **'Anyone with the link can join'**
  String get chatPublicHint;

  /// admin_only toggle
  ///
  /// In en, this message translates to:
  /// **'Admins only'**
  String get chatAdminOnly;

  /// admin_only explanation
  ///
  /// In en, this message translates to:
  /// **'Only admins can post'**
  String get chatAdminOnlyHint;

  /// slow_mode_seconds field label
  ///
  /// In en, this message translates to:
  /// **'Slow mode'**
  String get chatSlowMode;

  /// slow_mode_seconds = 0
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get chatSlowModeOff;

  /// slow_mode_seconds value
  ///
  /// In en, this message translates to:
  /// **'{seconds}s between messages'**
  String chatSlowModeSeconds(Object seconds);

  /// reactions_mode field label
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get chatReactionsMode;

  /// reactions_mode = all
  ///
  /// In en, this message translates to:
  /// **'Everyone, any emoji'**
  String get chatReactionsAll;

  /// reactions_mode = some
  ///
  /// In en, this message translates to:
  /// **'Only selected emoji'**
  String get chatReactionsSome;

  /// reactions_mode = none
  ///
  /// In en, this message translates to:
  /// **'Turned off'**
  String get chatReactionsNone;

  /// Leave action
  ///
  /// In en, this message translates to:
  /// **'Leave chat'**
  String get leaveChat;

  /// Leave confirmation body
  ///
  /// In en, this message translates to:
  /// **'Leave this chat? You will stop receiving its messages.'**
  String get leaveChatConfirm;

  /// created_by is locked in by the backend
  ///
  /// In en, this message translates to:
  /// **'The chat creator cannot leave — delete the chat instead.'**
  String get leaveChatOwnerBlocked;

  /// Delete action
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get deleteChat;

  /// Delete confirmation body
  ///
  /// In en, this message translates to:
  /// **'Delete this chat for everyone? This cannot be undone.'**
  String get deleteChatConfirm;

  /// Save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveChanges;

  /// Generic cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Snackbar after a successful PATCH /chats/{id}/
  ///
  /// In en, this message translates to:
  /// **'Chat updated'**
  String get chatSettingsSaved;

  /// Row that opens the member list
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get viewMembers;

  /// Marker next to the timestamp of an edited message
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get messageEdited;

  /// Message action: reply
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get messageReply;

  /// Message action: forward
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get messageForward;

  /// Message action: edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get messageEdit;

  /// Message action: delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get messageDelete;

  /// Message action: enter selection mode
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get messageSelect;

  /// Context menu action that opens the reaction picker
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get messageReact;

  /// Context menu action that puts the message text on the clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get messageCopy;

  /// Confirmation after copying message text
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get messageCopied;

  /// Shown when a tapped link in a message has no app to handle it
  ///
  /// In en, this message translates to:
  /// **'Nothing here can open that link'**
  String get linkOpenFailed;

  /// Context menu action that opens the message details sheet
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get messageDetails;

  /// Accessibility label on a quoted reply
  ///
  /// In en, this message translates to:
  /// **'Replying to {author}'**
  String replyingTo(String author);

  /// Header above a forwarded message whose original author is known
  ///
  /// In en, this message translates to:
  /// **'Forwarded from {author}'**
  String forwardedFrom(String author);

  /// Header above a forwarded message whose origin the server could not resolve
  ///
  /// In en, this message translates to:
  /// **'Forwarded message'**
  String get forwardedMessage;

  /// Message details row: the full date and time
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get detailsSentAt;

  /// Message details row: who wrote it
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get detailsAuthor;

  /// Message details row: the per-chat seq, which deep links and read cursors count in
  ///
  /// In en, this message translates to:
  /// **'Number in chat'**
  String get detailsSequence;

  /// Message details row label for an edited message
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get detailsEdited;

  /// Value of the edited row in message details
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get detailsEditedYes;

  /// Message details row: sending, sent or read
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get detailsDelivery;

  /// Heading above the per-attachment status list in message details
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get detailsAttachments;

  /// Returns from a jumped-to history window to the live tail
  ///
  /// In en, this message translates to:
  /// **'Back to latest messages'**
  String get backToLatest;

  /// Accessibility label for the double read tick
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get messageRead;

  /// Accessibility label for the single sent tick
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get messageSent;

  /// Date separator for messages sent today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// Date separator for messages sent yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateYesterday;

  /// Separator above the first unread message
  ///
  /// In en, this message translates to:
  /// **'Unread messages'**
  String get unreadMessages;

  /// Empty state in a chat with no history
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// Banner above the composer while editing
  ///
  /// In en, this message translates to:
  /// **'Editing message'**
  String get editingMessage;

  /// Tooltip on the scroll-to-bottom button
  ///
  /// In en, this message translates to:
  /// **'Jump to the newest messages'**
  String get scrollToBottom;

  /// Badge on the jump-to-bottom button, counting what arrived while the reader was up in the history
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No new messages} =1{1 new message below} other{{count} new messages below}}'**
  String newMessagesBelow(int count);

  /// Banner while the realtime socket is coming back
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get connectionReconnecting;

  /// Banner while the realtime socket is down
  ///
  /// In en, this message translates to:
  /// **'Offline — pull to refresh'**
  String get connectionOffline;

  /// Stands in for the text of a message that has none, such as one that is only a file
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get attachmentFallbackLabel;

  /// Why the composer is disabled: the reader is not a member
  ///
  /// In en, this message translates to:
  /// **'Join this chat to send messages'**
  String get composerJoinToSend;

  /// Why the composer is disabled
  ///
  /// In en, this message translates to:
  /// **'You are banned from this chat'**
  String get composerBanned;

  /// Why the composer is disabled
  ///
  /// In en, this message translates to:
  /// **'You are muted in this chat'**
  String get composerMuted;

  /// Why the composer is disabled
  ///
  /// In en, this message translates to:
  /// **'Only admins can post in this chat'**
  String get composerAdminsOnly;

  /// Why the composer is disabled, when no more specific reason applies
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to send messages here'**
  String get composerNoPermission;

  /// Summary of what is staged in the attachment bar
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}, {size}'**
  String attachmentSelection(int count, String size);

  /// Attachment bar state: every slot confirmed
  ///
  /// In en, this message translates to:
  /// **'Ready to send'**
  String get attachmentReady;

  /// Limits shown under the photo and video option
  ///
  /// In en, this message translates to:
  /// **'Up to {count}, {size} each'**
  String attachMediaLimits(int count, String size);

  /// Limits shown under the document option
  ///
  /// In en, this message translates to:
  /// **'One file, up to {size}'**
  String attachDocumentLimits(String size);

  /// Settings row for chat density
  ///
  /// In en, this message translates to:
  /// **'Message density'**
  String get messageDensity;

  /// Density option
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get densityCompact;

  /// Density option — the default
  ///
  /// In en, this message translates to:
  /// **'Cozy'**
  String get densityCozy;

  /// Density option
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get densityComfortable;

  /// Hint while holding the mic
  ///
  /// In en, this message translates to:
  /// **'Slide left to cancel, up to lock'**
  String get voiceSlideToCancel;

  /// Hint once the finger passed the cancel threshold
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get voiceReleaseToCancel;

  /// Hint while recording hands-free
  ///
  /// In en, this message translates to:
  /// **'Recording — tap send when you are done'**
  String get voiceRecordingLocked;

  /// Shown when the 600 s cap stopped the recording and it is waiting to be sent or discarded
  ///
  /// In en, this message translates to:
  /// **'Maximum length reached'**
  String get voiceLimitReached;

  /// Mic permission was refused
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off'**
  String get voicePermissionDenied;

  /// Label for a voice attachment
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessage;

  /// Button that starts a voice message
  ///
  /// In en, this message translates to:
  /// **'Play voice message'**
  String get voicePlay;

  /// Button that pauses a voice message
  ///
  /// In en, this message translates to:
  /// **'Pause voice message'**
  String get voicePause;

  /// Shown instead of the duration when a voice message could not be fetched
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get voiceUnavailable;

  /// Semantics label for the dot marking a voice message this device has not played yet
  ///
  /// In en, this message translates to:
  /// **'Not listened to yet'**
  String get voiceNotListened;

  /// Semantics label of the playback speed button, e.g. 1.5x
  ///
  /// In en, this message translates to:
  /// **'Playback speed {speed}'**
  String voiceSpeedLabel(String speed);

  /// Semantics label of the live waveform while recording
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get voiceRecording;

  /// Countdown shown in the last 30 seconds before the 600 s cap, as m:ss
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String voiceTimeLeft(String time);

  /// Button that throws away a hands-free recording
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get voiceCancelRecording;

  /// Button that sends a hands-free recording
  ///
  /// In en, this message translates to:
  /// **'Send voice message'**
  String get voiceSendRecording;

  /// Tooltip for the attachment button
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// Composer placeholder
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// Invalid chat route
  ///
  /// In en, this message translates to:
  /// **'Unknown chat'**
  String get unknownChat;

  /// Invalid profile route
  ///
  /// In en, this message translates to:
  /// **'Unknown profile'**
  String get unknownProfile;

  /// Recovery action on an invalid route
  ///
  /// In en, this message translates to:
  /// **'Go to chats'**
  String get goToChats;

  /// 404 screen title
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFound;

  /// 404 detail
  ///
  /// In en, this message translates to:
  /// **'{path} does not exist'**
  String pathDoesNotExist(String path);

  /// Generic retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Clears a search field
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Generic add action
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Generic save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Marks every notification read
  ///
  /// In en, this message translates to:
  /// **'Read all'**
  String get readAll;

  /// Notification filter menu
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// Notification filter: everything
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// Notification filter
  ///
  /// In en, this message translates to:
  /// **'Unread only'**
  String get filterUnread;

  /// Notification filter
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get filterRead;

  /// Clears the notification filter
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// Notification list error
  ///
  /// In en, this message translates to:
  /// **'Could not load your notifications.'**
  String get notificationsLoadFailed;

  /// Profile directory title
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get profiles;

  /// Profile search placeholder
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get searchByName;

  /// Member search placeholder
  ///
  /// In en, this message translates to:
  /// **'Search by username'**
  String get searchByUsername;

  /// People search placeholder: one field matches display name or username
  ///
  /// In en, this message translates to:
  /// **'Search by name or @username'**
  String get searchPeopleHint;

  /// Profile list error
  ///
  /// In en, this message translates to:
  /// **'Could not load profiles.'**
  String get profilesLoadFailed;

  /// Signed-out profile screen
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your profile'**
  String get signInToViewProfile;

  /// Signed-out profile editor
  ///
  /// In en, this message translates to:
  /// **'Sign in to edit your profile'**
  String get signInToEditProfile;

  /// Profile bio section
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAbout;

  /// Profile skills section
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get profileSkills;

  /// Profile contacts section
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get profileContacts;

  /// Starts a direct chat from a profile
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get sendMessageAction;

  /// Profile editor title
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// Profile field
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// Profile field
  ///
  /// In en, this message translates to:
  /// **'Specialization'**
  String get specialization;

  /// Profile field
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// Profile field
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirth;

  /// Adds a profile contact
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// Contact provider field
  ///
  /// In en, this message translates to:
  /// **'Provider (e.g. telegram)'**
  String get contactProvider;

  /// Contact value field
  ///
  /// In en, this message translates to:
  /// **'Contact (e.g. @handle)'**
  String get contactHandle;

  /// Skills input hint
  ///
  /// In en, this message translates to:
  /// **'Type a skill and press enter'**
  String get skillsHint;

  /// Image picker failure
  ///
  /// In en, this message translates to:
  /// **'Could not open the photo library'**
  String get photoLibraryFailed;

  /// Chat list title
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// Search entry point
  ///
  /// In en, this message translates to:
  /// **'Search chats and people'**
  String get searchChatsAndPeople;

  /// Chat list error
  ///
  /// In en, this message translates to:
  /// **'Could not load your chats.'**
  String get chatsLoadFailed;

  /// Empty chat list title
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// Empty chat list body
  ///
  /// In en, this message translates to:
  /// **'Start a conversation and it will show up here.'**
  String get noChatsYetHint;

  /// Creates a chat
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// Chat type option
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get chatTypeDirect;

  /// Chat type option
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get chatTypeGroup;

  /// Chat type option (supergroup)
  ///
  /// In en, this message translates to:
  /// **'Super'**
  String get chatTypeSuper;

  /// Chat type option
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get chatTypeChannel;

  /// is_public explanation on create
  ///
  /// In en, this message translates to:
  /// **'Anyone can find and join this chat'**
  String get chatPublicHintCreate;

  /// slow_mode_seconds field
  ///
  /// In en, this message translates to:
  /// **'Slow mode (seconds)'**
  String get chatSlowModeSecondsField;

  /// Submits the create-chat form
  ///
  /// In en, this message translates to:
  /// **'Create chat'**
  String get createChat;

  /// Member list title
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersTitle;

  /// Member list error
  ///
  /// In en, this message translates to:
  /// **'Failed to load members'**
  String get membersLoadFailed;

  /// Invites someone to the chat
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get addMember;

  /// Member role action
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get changeRole;

  /// Bans a member
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get banMember;

  /// Ban dialog title
  ///
  /// In en, this message translates to:
  /// **'Ban member'**
  String get banMemberTitle;

  /// Kicks a member
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get kickMember;

  /// Ban reason field
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get banReason;

  /// Picks a ban expiry
  ///
  /// In en, this message translates to:
  /// **'Set date'**
  String get banUntil;

  /// Search results section
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchPeople;

  /// Empty people search
  ///
  /// In en, this message translates to:
  /// **'No people found'**
  String get noPeopleFound;

  /// Call is being established
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get callConnecting;

  /// Joins the LiveKit room
  ///
  /// In en, this message translates to:
  /// **'Join call'**
  String get callJoin;

  /// Call finished
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callEnded;

  /// Rejoins after disconnect
  ///
  /// In en, this message translates to:
  /// **'Rejoin'**
  String get callRejoin;

  /// Leaves the call
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get callLeave;

  /// Call screen fallback title
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callTitle;

  /// Selection app bar title
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// Bulk delete confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete {count} messages?'**
  String deleteMessagesTitle(int count);

  /// Destructive confirmation body
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get cannotBeUndone;

  /// Chat detail error
  ///
  /// In en, this message translates to:
  /// **'Failed to load chat'**
  String get chatLoadFailed;

  /// Attachment source
  ///
  /// In en, this message translates to:
  /// **'Photos & videos'**
  String get attachMedia;

  /// Attachment source
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get attachDocument;

  /// Forward success
  ///
  /// In en, this message translates to:
  /// **'Message forwarded'**
  String get messageForwarded;

  /// Forward target picker title
  ///
  /// In en, this message translates to:
  /// **'Forward to'**
  String get forwardTo;

  /// Forward picker empty
  ///
  /// In en, this message translates to:
  /// **'No other chats'**
  String get noOtherChats;

  /// Forward picker error
  ///
  /// In en, this message translates to:
  /// **'Could not load chats'**
  String get chatsLoadFailedShort;

  /// Shown on a queued message that is between retries
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get messageWaitingToSend;

  /// Fallback label on a message the queue gave up on
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get messageNotSent;

  /// Connection strip: the app is reaching the chat gateway
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectionBusy;

  /// Connection strip: there is no network to reach the gateway over
  ///
  /// In en, this message translates to:
  /// **'Waiting for network'**
  String get connectionWaitingForNetwork;

  /// Settings entry, shown only while protocol recording is on
  ///
  /// In en, this message translates to:
  /// **'Connection diagnostics'**
  String get wsDiagnostics;

  /// How much of the WebSocket session has been captured
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No frames recorded} =1{1 frame recorded} other{{count} frames recorded}}'**
  String wsDiagnosticsFrames(int count);

  /// Confirmation after copying the WebSocket session dump
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied'**
  String get wsDiagnosticsCopied;

  /// Drops a failed pending message
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Who-reacted sheet title
  ///
  /// In en, this message translates to:
  /// **'Reacted'**
  String get reactedTitle;

  /// Empty who-reacted sheet
  ///
  /// In en, this message translates to:
  /// **'Nobody has reacted with this yet'**
  String get noReactionsYet;

  /// Loads the next page
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// Bulk progress label
  ///
  /// In en, this message translates to:
  /// **'Forwarding'**
  String get bulkForwarding;

  /// Bulk progress label
  ///
  /// In en, this message translates to:
  /// **'Deleting'**
  String get bulkDeleting;

  /// Bulk progress body
  ///
  /// In en, this message translates to:
  /// **'{label} {done} of {total}…'**
  String bulkProgress(String label, int done, int total);

  /// Bulk success
  ///
  /// In en, this message translates to:
  /// **'{label} complete ({total})'**
  String bulkComplete(String label, int total);

  /// Bulk partial failure
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} succeeded — {failed} failed: {reason}'**
  String bulkPartial(int done, int total, int failed, String reason);

  /// Join call failure
  ///
  /// In en, this message translates to:
  /// **'Could not start the call'**
  String get callTokenUnavailable;

  /// Login screen title
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// Login identifier field
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get emailOrUsername;

  /// Login identifier hint
  ///
  /// In en, this message translates to:
  /// **'you@example.com or your username'**
  String get emailOrUsernameHint;

  /// Password field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// Login submit
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// Register field
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Username rule
  ///
  /// In en, this message translates to:
  /// **'4-100 characters'**
  String get usernameHint;

  /// Email field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailHint;

  /// Password complexity rule
  ///
  /// In en, this message translates to:
  /// **'8+ chars, upper/lower/digit/special'**
  String get passwordRule;

  /// Register field
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// Confirm field hint
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get confirmPasswordHint;

  /// OAuth callback title
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// OAuth callback action
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// Reset confirm title
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get setNewPassword;

  /// Reset token field
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get resetCode;

  /// Reset field
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// Reset field
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// Reset submit / title
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// Reset success
  ///
  /// In en, this message translates to:
  /// **'Password updated — please log in.'**
  String get passwordUpdated;

  /// Requests a reset code
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// Skips to reset confirm
  ///
  /// In en, this message translates to:
  /// **'I already have a code'**
  String get haveCodeAlready;

  /// Reset request success
  ///
  /// In en, this message translates to:
  /// **'Check your email for a reset code.'**
  String get resetCodeSent;

  /// Email verification title
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyEmailTitle;

  /// Verification instructions
  ///
  /// In en, this message translates to:
  /// **'Paste the token from the email we sent you.'**
  String get verifyEmailHint;

  /// Verification field
  ///
  /// In en, this message translates to:
  /// **'Verification token'**
  String get verificationToken;

  /// Verification submit
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// Resend rate limit
  ///
  /// In en, this message translates to:
  /// **'We can resend it — up to 3 times per hour.'**
  String get resendLimitHint;

  /// Resend action
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get resendVerification;

  /// Verification success
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get emailVerified;

  /// Verification resend success
  ///
  /// In en, this message translates to:
  /// **'Verification email sent — check your inbox.'**
  String get verificationSent;

  /// OAuth launch failure
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser for sign-in'**
  String get browserOpenFailed;

  /// OAuth provider button
  ///
  /// In en, this message translates to:
  /// **'Continue with {provider}'**
  String continueWith(String provider);

  /// Profile search failure
  ///
  /// In en, this message translates to:
  /// **'Could not search for people'**
  String get peopleSearchFailed;

  /// Direct chat creation failure
  ///
  /// In en, this message translates to:
  /// **'Could not start a chat with this person'**
  String get startChatFailed;

  /// Single profile failure
  ///
  /// In en, this message translates to:
  /// **'Could not load this profile'**
  String get profileLoadFailed;

  /// Own profile failure
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile'**
  String get myProfileLoadFailed;

  /// Profile save failure
  ///
  /// In en, this message translates to:
  /// **'Could not save changes'**
  String get saveChangesFailed;

  /// Avatar upload failure
  ///
  /// In en, this message translates to:
  /// **'Could not update avatar'**
  String get avatarUpdateFailed;

  /// OAuth was aborted by the user
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled'**
  String get oauthCancelled;

  /// OAuth cancel detail
  ///
  /// In en, this message translates to:
  /// **'Nothing was changed. Try again, or use your username and password.'**
  String get oauthCancelledHint;

  /// OAuth failed
  ///
  /// In en, this message translates to:
  /// **'Could not finish signing in'**
  String get oauthFailed;

  /// OAuth failure detail
  ///
  /// In en, this message translates to:
  /// **'Sign in with your username and password instead.'**
  String get oauthFailedHint;

  /// ws.error NOT_CHAT_MEMBER banner
  ///
  /// In en, this message translates to:
  /// **'Live updates are off for this chat'**
  String get realtimeRejected;

  /// Forward comment field
  ///
  /// In en, this message translates to:
  /// **'Add a comment (optional)'**
  String get forwardComment;

  /// Confirms the forward
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forwardAction;

  /// Ban duration section
  ///
  /// In en, this message translates to:
  /// **'How long'**
  String get banDuration;

  /// banned_to = null
  ///
  /// In en, this message translates to:
  /// **'Permanently'**
  String get banForever;

  /// banned_to = future
  ///
  /// In en, this message translates to:
  /// **'Until a date'**
  String get banUntilDate;

  /// banned_to = past
  ///
  /// In en, this message translates to:
  /// **'Lift the ban'**
  String get banLift;

  /// banned_to past semantics
  ///
  /// In en, this message translates to:
  /// **'Sends a past date, which the server reads as an unban'**
  String get banLiftHint;

  /// Opens the date picker
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get banPickDate;

  /// Sessions screen title
  ///
  /// In en, this message translates to:
  /// **'My devices'**
  String get myDevices;

  /// Sessions list error
  ///
  /// In en, this message translates to:
  /// **'Could not load your devices.'**
  String get devicesLoadFailed;

  /// Empty sessions list
  ///
  /// In en, this message translates to:
  /// **'No active sessions'**
  String get noDevices;

  /// Session is active
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get deviceActive;

  /// Session is no longer active
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get deviceInactive;

  /// Session last activity
  ///
  /// In en, this message translates to:
  /// **'Last active {date}'**
  String deviceLastActive(String date);

  /// Title of the design-system showcase screen
  ///
  /// In en, this message translates to:
  /// **'Design system'**
  String get designSystem;

  /// Label for the accent colour picker in appearance settings
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// Label for the chat wallpaper picker
  ///
  /// In en, this message translates to:
  /// **'Chat wallpaper'**
  String get chatWallpaper;

  /// Wallpaper option: colour blooms with a lattice
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get wallpaperAurora;

  /// Wallpaper option: colour blooms only
  ///
  /// In en, this message translates to:
  /// **'Mesh'**
  String get wallpaperMesh;

  /// Wallpaper option: flat surface
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get wallpaperPlain;

  /// Label for the in-app text scale control
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// Text scale option
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textSizeSmall;

  /// Text scale option
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get textSizeDefault;

  /// Text scale option
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textSizeLarge;

  /// Text scale option
  ///
  /// In en, this message translates to:
  /// **'Extra large'**
  String get textSizeExtraLarge;

  /// Button that restores the default appearance settings
  ///
  /// In en, this message translates to:
  /// **'Reset appearance'**
  String get resetAppearance;

  /// Showcase section: brand accent colours
  ///
  /// In en, this message translates to:
  /// **'Accents'**
  String get showcaseAccents;

  /// Showcase section: the neutral ramps
  ///
  /// In en, this message translates to:
  /// **'Neutrals'**
  String get showcaseNeutrals;

  /// Label for the light neutral ramp
  ///
  /// In en, this message translates to:
  /// **'Light ramp'**
  String get showcaseNeutralsLight;

  /// Label for the dark neutral ramp
  ///
  /// In en, this message translates to:
  /// **'Dark ramp'**
  String get showcaseNeutralsDark;

  /// Showcase section: corner radius scale
  ///
  /// In en, this message translates to:
  /// **'Radii'**
  String get showcaseRadii;

  /// Showcase section: spacing scale
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get showcaseSpacing;

  /// Showcase section: elevation levels
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get showcaseElevation;

  /// Showcase section: animation durations
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get showcaseMotion;

  /// Name of the fast animation duration
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get showcaseMotionFast;

  /// Name of the default animation duration
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get showcaseMotionBase;

  /// Name of the slow animation duration
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get showcaseMotionSlow;

  /// Button that replays the motion demo
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get showcaseMotionReplay;

  /// Showcase section: text styles
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get showcaseTypography;

  /// Label above the tabular digit sample
  ///
  /// In en, this message translates to:
  /// **'Tabular figures'**
  String get showcaseTabularFigures;

  /// Showcase section: chat bubbles
  ///
  /// In en, this message translates to:
  /// **'Message bubbles'**
  String get showcaseBubbles;

  /// Showcase section: reaction chips
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get showcaseReactions;

  /// Showcase section: per-author colours
  ///
  /// In en, this message translates to:
  /// **'Author accents'**
  String get showcaseAuthors;

  /// Showcase section: common components
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get showcaseComponents;

  /// Sample text inside an incoming bubble
  ///
  /// In en, this message translates to:
  /// **'Incoming: warm surface, one hairline.'**
  String get showcaseIncomingSample;

  /// Sample text inside a stacked incoming bubble
  ///
  /// In en, this message translates to:
  /// **'Second message in the same run.'**
  String get showcaseStackedSample;

  /// Sample text inside an outgoing bubble
  ///
  /// In en, this message translates to:
  /// **'Outgoing: accent gradient.'**
  String get showcaseOutgoingSample;

  /// Semantic label for the clock tick on a message that has not reached the server yet
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get messageSending;

  /// Semantic label for the presence dot on an avatar
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get onlineNow;

  /// Header subtitle while one person types
  ///
  /// In en, this message translates to:
  /// **'{name} is typing…'**
  String userTyping(String name);

  /// Header subtitle while several people type
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person is typing…} other{{count} people are typing…}}'**
  String severalTyping(int count);

  /// Attachment count on a message that is still being sent
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attachment} other{{count} attachments}}'**
  String attachmentsCount(int count);

  /// Label for the contacts tab
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// Subtitle of the profile row in settings
  ///
  /// In en, this message translates to:
  /// **'Your name, avatar and contact details'**
  String get profileSettingsHint;

  /// Title of the placeholder pane shown next to the chat list before a chat is picked
  ///
  /// In en, this message translates to:
  /// **'No chat selected'**
  String get noChatSelected;

  /// Body of the placeholder pane shown next to the chat list
  ///
  /// In en, this message translates to:
  /// **'Pick a conversation from the list to start reading.'**
  String get noChatSelectedHint;

  /// Quick action: start a one-to-one chat
  ///
  /// In en, this message translates to:
  /// **'New direct chat'**
  String get newDirectChat;

  /// Quick action: create a group
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// Quick action: create a channel
  ///
  /// In en, this message translates to:
  /// **'New channel'**
  String get newChannel;

  /// Accessibility hint for long-pressing the chats tab
  ///
  /// In en, this message translates to:
  /// **'Start something new'**
  String get quickActionsHint;

  /// Accessible label for the unread badge on the chats tab
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No unread messages} =1{1 unread message} other{{count} unread messages}}'**
  String unreadMessagesCount(int count);

  /// Accessible label for the badge on the notifications tab
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No new notifications} =1{1 new notification} other{{count} new notifications}}'**
  String unreadNotificationsCount(int count);

  /// Empty state on the contacts tab when a search matches nobody
  ///
  /// In en, this message translates to:
  /// **'Nobody matches that name'**
  String get noContactsFound;

  /// Advice under the empty contacts search result
  ///
  /// In en, this message translates to:
  /// **'Try a shorter or differently spelled name.'**
  String get noContactsFoundHint;

  /// Empty state on the contacts tab before anything is loaded
  ///
  /// In en, this message translates to:
  /// **'No people to show yet'**
  String get noContactsYet;

  /// Author of the last message in a group when it was the reader
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get previewYou;

  /// Chat row preview of a photo sent without a caption
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get previewPhoto;

  /// Chat row preview of a video sent without a caption
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get previewVideo;

  /// Chat row preview of a voice message of unknown length
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get previewVoice;

  /// Chat row preview of a round video note
  ///
  /// In en, this message translates to:
  /// **'Video message'**
  String get previewVideoNote;

  /// Chat row preview of a document whose filename is unknown
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get previewFile;

  /// Chat row preview of a message with neither text nor a known attachment
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get previewNoText;

  /// Prefix of the chat row preview when unsent text is waiting in the composer
  ///
  /// In en, this message translates to:
  /// **'Draft:'**
  String get draftLabel;

  /// Quick action on a chat row that clears its unread count
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get markAsRead;

  /// Quick action that moves a chat into the archive section
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveChat;

  /// Quick action that moves a chat back out of the archive
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchiveChat;

  /// Quick action that keeps a chat at the top of the list
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pinChat;

  /// Quick action that releases a pinned chat back into the list
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpinChat;

  /// Quick action that turns off notifications for a chat on this device
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get muteChat;

  /// Quick action that turns notifications for a chat back on
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmuteChat;

  /// Header of the collapsed section holding archived chats
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedChats;

  /// Accessible label of the pin marker on a chat row
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get chatPinnedLabel;

  /// Accessible label of the muted marker on a chat row
  ///
  /// In en, this message translates to:
  /// **'Notifications off'**
  String get chatMutedLabel;

  /// Confirmation shown after a chat is archived
  ///
  /// In en, this message translates to:
  /// **'Chat archived'**
  String get chatArchivedToast;

  /// Confirmation shown after a chat is deleted for everyone
  ///
  /// In en, this message translates to:
  /// **'Chat deleted'**
  String get chatDeletedToast;

  /// Action on a confirmation snackbar that reverses what just happened
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Shown when the only chats left are in the archive
  ///
  /// In en, this message translates to:
  /// **'Everything is archived'**
  String get allChatsArchived;

  /// Chat row preview of a voice message, with its length as m:ss
  ///
  /// In en, this message translates to:
  /// **'Voice message {duration}'**
  String previewVoiceWithDuration(String duration);

  /// How many chats are inside the archive section
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chat} other{{count} chats}}'**
  String archivedChatsCount(int count);

  /// Title of the screen that manages the chat list's folders
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get chatFolders;

  /// The first tab of the folder strip, which filters nothing
  ///
  /// In en, this message translates to:
  /// **'All chats'**
  String get chatFoldersAll;

  /// Ready-made folder holding chats with unread messages
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get folderPresetUnread;

  /// Ready-made folder holding one-to-one chats
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get folderPresetPersonal;

  /// Ready-made folder holding group and supergroup chats
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get folderPresetGroups;

  /// Ready-made folder holding channels
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get folderPresetChannels;

  /// Ready-made folder holding chats whose last message is not mine
  ///
  /// In en, this message translates to:
  /// **'Awaiting my reply'**
  String get folderPresetNoReply;

  /// Action that opens the editor for a folder that does not exist yet
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// Title of the editor when an existing folder is open in it
  ///
  /// In en, this message translates to:
  /// **'Edit folder'**
  String get editFolder;

  /// Label of the folder title field
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// Label of the icon picker in the folder editor
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get folderIcon;

  /// Heading of the rule list in the folder editor
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get folderRules;

  /// Heading of the choice between matching every rule and matching any
  ///
  /// In en, this message translates to:
  /// **'A chat belongs here when'**
  String get folderMatchModeTitle;

  /// Match mode where all of a folder's rules have to hold
  ///
  /// In en, this message translates to:
  /// **'It meets every rule'**
  String get folderMatchAll;

  /// Match mode where one of a folder's rules is enough
  ///
  /// In en, this message translates to:
  /// **'It meets any rule'**
  String get folderMatchAny;

  /// Action that opens the list of rule kinds to add one
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get addFolderRule;

  /// Accessible label of the button that drops a rule from a folder
  ///
  /// In en, this message translates to:
  /// **'Remove rule'**
  String get removeFolderRule;

  /// Rule that keeps chats of the chosen kinds
  ///
  /// In en, this message translates to:
  /// **'Chat type'**
  String get folderRuleChatType;

  /// Summary of a chat type rule, listing the types it accepts
  ///
  /// In en, this message translates to:
  /// **'Type is {types}'**
  String folderRuleChatTypeIn(String types);

  /// Rule that keeps chats with something unread in them
  ///
  /// In en, this message translates to:
  /// **'Has unread messages'**
  String get folderRuleUnread;

  /// Rule that keeps chats that are fully read
  ///
  /// In en, this message translates to:
  /// **'Has nothing unread'**
  String get folderRuleRead;

  /// Rule that keeps pinned chats
  ///
  /// In en, this message translates to:
  /// **'Is pinned'**
  String get folderRulePinned;

  /// Rule that keeps chats that are not pinned
  ///
  /// In en, this message translates to:
  /// **'Is not pinned'**
  String get folderRuleNotPinned;

  /// Rule kind matching chats whose last message is not mine
  ///
  /// In en, this message translates to:
  /// **'Waiting for my reply'**
  String get folderRuleNoReply;

  /// Summary of the no-reply rule, including how long it has waited
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Waiting for my reply} =1{Waiting for my reply for over 1 day} other{Waiting for my reply for over {days} days}}'**
  String folderRuleNoReplyDays(int days);

  /// Label of the slider that sets how long a chat has waited
  ///
  /// In en, this message translates to:
  /// **'Days without my reply'**
  String get folderRuleDaysLabel;

  /// Value of the no-reply slider that accepts a message of any age
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get folderRuleDaysAny;

  /// Rule kind matching chats that a chosen person is in
  ///
  /// In en, this message translates to:
  /// **'Includes a person'**
  String get folderRuleMember;

  /// Summary of a member rule, naming the person it looks for
  ///
  /// In en, this message translates to:
  /// **'Includes {name}'**
  String folderRuleMemberNamed(String name);

  /// Title of the sheet that picks the person a member rule looks for
  ///
  /// In en, this message translates to:
  /// **'Choose a person'**
  String get folderRulePickPerson;

  /// Shown in the person picker when no chat has named anyone yet
  ///
  /// In en, this message translates to:
  /// **'People appear here once you have chats with them'**
  String get folderRuleNoPeople;

  /// Explains the limits of the member rule, which cannot fetch rosters
  ///
  /// In en, this message translates to:
  /// **'Matches on what the chat list already knows: you, anyone whose roster is loaded, the last sender and the chat\'s creator.'**
  String get folderRuleMemberLocalNote;

  /// Action that removes a folder
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get deleteFolder;

  /// Confirmation asked before a folder is removed
  ///
  /// In en, this message translates to:
  /// **'Delete this folder? The chats in it stay where they are.'**
  String get deleteFolderConfirm;

  /// Validation shown when a folder is saved without a title
  ///
  /// In en, this message translates to:
  /// **'Give the folder a name'**
  String get folderNameRequired;

  /// Validation shown when a folder title is too long
  ///
  /// In en, this message translates to:
  /// **'Folder names are limited to {count} characters'**
  String folderNameTooLong(int count);

  /// Validation shown when a folder is saved with no rules
  ///
  /// In en, this message translates to:
  /// **'Add at least one rule'**
  String get folderRulesRequired;

  /// Shown when adding one more folder would pass the limit
  ///
  /// In en, this message translates to:
  /// **'You can keep up to {count} folders'**
  String folderLimitReached(int count);

  /// Shown when pinning a chat would pass the pinned zone's limit
  ///
  /// In en, this message translates to:
  /// **'Only {count} chats can be pinned. Unpin one first.'**
  String pinLimitReached(int count);

  /// Title of the empty state on the folders screen
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get foldersEmpty;

  /// Explains what a folder is on the empty folders screen
  ///
  /// In en, this message translates to:
  /// **'A folder is a set of rules, not a list. Chats join and leave it on their own.'**
  String get foldersEmptyHint;

  /// Heading of the presets that can be added in one tap
  ///
  /// In en, this message translates to:
  /// **'Ready-made'**
  String get folderReadyMade;

  /// Heading of the list of folders already added
  ///
  /// In en, this message translates to:
  /// **'Your folders'**
  String get folderYours;

  /// How many rules a folder holds
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule} other{{count} rules}}'**
  String folderRuleCount(int count);

  /// Title shown when the selected folder matches no chat
  ///
  /// In en, this message translates to:
  /// **'Nothing in this folder'**
  String get folderEmptyChats;

  /// Explains that a folder fills itself, on its empty state
  ///
  /// In en, this message translates to:
  /// **'Chats show up here as soon as they meet its rules.'**
  String get folderEmptyChatsHint;

  /// Switch that keeps the folders but takes the tabs off the chat list
  ///
  /// In en, this message translates to:
  /// **'Hide the folder strip'**
  String get hideFolderTabs;

  /// Explains what hiding the folder strip does
  ///
  /// In en, this message translates to:
  /// **'Keeps your folders without showing the tabs above the list'**
  String get hideFolderTabsHint;

  /// Switch that returns an archived chat to the list when someone writes
  ///
  /// In en, this message translates to:
  /// **'Bring back on new message'**
  String get unarchiveOnNewMessage;

  /// Explains what bringing a chat back on a new message does
  ///
  /// In en, this message translates to:
  /// **'An archived chat returns to the list when someone writes in it'**
  String get unarchiveOnNewMessageHint;

  /// Says that the organizer's state is local, since the API stores none of it
  ///
  /// In en, this message translates to:
  /// **'Folders are kept on this device and do not follow your account. Pins, the archive and silenced chats do.'**
  String get organizerDeviceOnly;

  /// Header of the block at the top of the list holding pinned chats
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get chatPinnedZone;

  /// Confirms that a chat has left the archive
  ///
  /// In en, this message translates to:
  /// **'Moved back to the list'**
  String get chatUnarchivedToast;

  /// Tab of the search screen listing matching messages
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get searchTabMessages;

  /// Placeholder of the single search field
  ///
  /// In en, this message translates to:
  /// **'Search chats, people and messages'**
  String get searchEverything;

  /// Heading over the searches someone ran before
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecentQueries;

  /// Heading over the chats someone opened most recently
  ///
  /// In en, this message translates to:
  /// **'Recently opened'**
  String get searchRecentChats;

  /// Action that empties the list of recent searches
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClearHistory;

  /// Accessible label of the button that drops one recent search
  ///
  /// In en, this message translates to:
  /// **'Remove from recent searches'**
  String get searchRemoveFromHistory;

  /// Title shown when the search field is still empty
  ///
  /// In en, this message translates to:
  /// **'Find a chat, a person or a message'**
  String get searchStartTitle;

  /// Explains what each tab of the search covers
  ///
  /// In en, this message translates to:
  /// **'Chats are matched by name, people by username, messages by what they say.'**
  String get searchStartHint;

  /// Notice saying message search covers only what this device has loaded
  ///
  /// In en, this message translates to:
  /// **'Searched what is on this device'**
  String get searchLoadedHistoryOnly;

  /// Explains why message search is limited to the device
  ///
  /// In en, this message translates to:
  /// **'The server could not be reached, so this searched the messages already on this device.'**
  String get searchLoadedHistoryExplained;

  /// Title shown when no loaded chat matches the query
  ///
  /// In en, this message translates to:
  /// **'No chats found'**
  String get noChatsFound;

  /// Explains what the chats tab searches
  ///
  /// In en, this message translates to:
  /// **'Chats are matched by name and description, among the ones already loaded.'**
  String get noChatsFoundHint;

  /// Suggestion shown when a people search comes back empty
  ///
  /// In en, this message translates to:
  /// **'Try another spelling, or search by username.'**
  String get noPeopleFoundHint;

  /// Title shown when no loaded message matches the query
  ///
  /// In en, this message translates to:
  /// **'No messages found'**
  String get noMessagesFound;

  /// Fallback error message when the message search fails
  ///
  /// In en, this message translates to:
  /// **'Could not search messages'**
  String get messageSearchFailed;

  /// Action in a chat's header that opens the search inside it
  ///
  /// In en, this message translates to:
  /// **'Search in this chat'**
  String get searchInChat;

  /// Which match of how many the chat is parked on
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String searchMatchPosition(int current, int total);

  /// Shown in the in-chat search when nothing loaded matches
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get searchNoMatches;

  /// Button that moves to the previous match further back in time
  ///
  /// In en, this message translates to:
  /// **'Older match'**
  String get searchOlderMatch;

  /// Button that moves to the next, more recent match
  ///
  /// In en, this message translates to:
  /// **'Newer match'**
  String get searchNewerMatch;

  /// Placeholder of the search field inside a chat
  ///
  /// In en, this message translates to:
  /// **'Search in this chat'**
  String get searchInChatHint;

  /// Explains a chat result whose name does not contain the query
  ///
  /// In en, this message translates to:
  /// **'Matched in the description'**
  String get searchChatDescriptionMatch;

  /// Accessible label of a message result that opens its chat
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get searchOpenChat;

  /// Catalog sheet: this device's own history
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get reactionSectionRecent;

  /// Catalog sheet section: faces
  ///
  /// In en, this message translates to:
  /// **'Smileys'**
  String get reactionSectionFaces;

  /// Catalog sheet section: hands and people
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get reactionSectionPeople;

  /// Catalog sheet section: hearts
  ///
  /// In en, this message translates to:
  /// **'Hearts'**
  String get reactionSectionHearts;

  /// Catalog sheet section: celebration
  ///
  /// In en, this message translates to:
  /// **'Celebration'**
  String get reactionSectionCelebration;

  /// Catalog sheet section: food
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get reactionSectionFood;

  /// Catalog sheet section: nature and animals
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get reactionSectionNature;

  /// Catalog sheet section: symbols
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get reactionSectionSymbols;

  /// reactions_mode = some with a white list the catalog does not cover
  ///
  /// In en, this message translates to:
  /// **'No reactions are available in this chat'**
  String get reactionsNoneAllowed;

  /// Catalog sheet counter: reactions of mine out of MAX_REACTIONS_PER_USER_PER_MESSAGE
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit}'**
  String reactionsUsed(int used, int limit);

  /// MAX_DISTINCT_REACTIONS_PER_MESSAGE reached
  ///
  /// In en, this message translates to:
  /// **'This message already has {limit} different reactions'**
  String reactionMessageLimitReached(Object limit);

  /// Quick bar button that opens the full catalog sheet
  ///
  /// In en, this message translates to:
  /// **'More reactions'**
  String get moreReactions;

  /// Quiet toast after an optimistic reaction was rolled back
  ///
  /// In en, this message translates to:
  /// **'Reaction not saved'**
  String get reactionFailed;

  /// Quiet toast for 429 on the reactions endpoint
  ///
  /// In en, this message translates to:
  /// **'Too many reactions at once'**
  String get reactionTooFast;

  /// Quiet toast for REACTION_NOT_ALLOWED / INVALID_REACTION
  ///
  /// In en, this message translates to:
  /// **'That reaction is not allowed here'**
  String get reactionNotAllowed;

  /// Who-reacted sheet: a tab whose page came back empty
  ///
  /// In en, this message translates to:
  /// **'Nobody yet'**
  String get reactionsNobody;

  /// Who-reacted row for a user id the roster does not cover
  ///
  /// In en, this message translates to:
  /// **'User {id}'**
  String reactionUserFallback(Object id);

  /// Counter shown near the 4096-character cap (api-docs 5.4)
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String composerCharactersLeft(int count);

  /// Accessible label of the send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get composerSendLabel;

  /// Accessible label of the send button while editing
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get composerSaveEditLabel;

  /// Accessible label of the microphone button
  ///
  /// In en, this message translates to:
  /// **'Hold to record a voice message'**
  String get composerRecordLabel;

  /// Context banner title while replying
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}'**
  String composerReplyingTo(Object name);

  /// Countdown on the send button while slow mode holds it
  ///
  /// In en, this message translates to:
  /// **'Slow mode: {seconds}s to wait'**
  String composerSlowModeWait(int seconds);

  /// Explains why the send button counts down
  ///
  /// In en, this message translates to:
  /// **'This chat allows one message every {seconds} s'**
  String composerSlowModeHint(int seconds);

  /// Title of the composer attachment sheet
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attachSheetTitle;

  /// Header of the recent-gallery strip
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get attachRecent;

  /// Attachment sheet row that opens the camera
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachCamera;

  /// Attachment sheet row that records a voice message
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get attachVoice;

  /// Attachment sheet row that records a video note
  ///
  /// In en, this message translates to:
  /// **'Video note'**
  String get attachVideoNote;

  /// Subtitle of the voice row: it is exclusive (api-docs 5.5)
  ///
  /// In en, this message translates to:
  /// **'Sent on its own, up to {seconds} s'**
  String attachVoiceHint(int seconds);

  /// Subtitle of the video note row
  ///
  /// In en, this message translates to:
  /// **'Sent on its own, up to {seconds} s and {pixels} px'**
  String attachVideoNoteHint(int seconds, int pixels);

  /// Shown in place of the strip when photo access was refused
  ///
  /// In en, this message translates to:
  /// **'Allow photo access to pick from here'**
  String get attachGalleryDenied;

  /// Button that asks for the photo grant again
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get attachGalleryAllow;

  /// Tapping one more photo past MAX_MEDIA_PER_MESSAGE
  ///
  /// In en, this message translates to:
  /// **'Up to {count} photos or videos per message'**
  String attachMediaFull(int count);

  /// Confirm button of the attachment sheet
  ///
  /// In en, this message translates to:
  /// **'Attach {count}'**
  String attachSendCount(int count);

  /// A picked gallery item could not be read back
  ///
  /// In en, this message translates to:
  /// **'That file could not be read'**
  String get attachUnavailable;

  /// Captured video note exceeds the 640 px cap the server enforces
  ///
  /// In en, this message translates to:
  /// **'This camera records above {pixels} px, which the server rejects for video notes'**
  String videoNoteTooLarge(int pixels);

  /// Counter once the message is past the 4096-character cap
  ///
  /// In en, this message translates to:
  /// **'{count} over the limit'**
  String composerTooLongBy(int count);

  /// Video note recorder: what the shutter does
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get videoNoteTapToRecord;

  /// Video note recorder: the device has no camera
  ///
  /// In en, this message translates to:
  /// **'This device has no camera to record with'**
  String get videoNoteNoCamera;

  /// Video note recorder: camera or mic grant refused
  ///
  /// In en, this message translates to:
  /// **'Allow camera and microphone access to record a video note'**
  String get videoNoteCameraDenied;

  /// Video note recorder: the camera would not open
  ///
  /// In en, this message translates to:
  /// **'The camera could not be started'**
  String get videoNoteCameraFailed;

  /// Quiet toast when a take was too short or unusable
  ///
  /// In en, this message translates to:
  /// **'Nothing was recorded'**
  String get videoNoteDiscarded;

  /// Action on a document attachment: hand it to the platform
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get attachmentOpen;

  /// Confirmation after an attachment was copied to the device, with the full path
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String attachmentSavedTo(String path);

  /// The attachment could not be downloaded or copied to the device
  ///
  /// In en, this message translates to:
  /// **'Could not save this file'**
  String get attachmentSaveFailed;

  /// Label on the progress ring of a file whose bytes are going out
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get attachmentUploading;

  /// Where the open photo sits in the chat’s media, shown in the viewer
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String mediaViewerCounter(int index, int count);

  /// The viewer was opened on media that is no longer in the loaded history
  ///
  /// In en, this message translates to:
  /// **'This media is no longer available'**
  String get mediaViewerUnavailable;

  /// Explains that tiles can be dropped on the pre-send preview screen
  ///
  /// In en, this message translates to:
  /// **'Remove anything you did not mean to send'**
  String get mediaPreviewHint;

  /// Placeholder of the album caption field; the caption becomes the message content
  ///
  /// In en, this message translates to:
  /// **'Add a caption'**
  String get mediaPreviewCaptionHint;

  /// Tooltip on the button that drops one file from a staged album
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get mediaPreviewRemove;

  /// Accessible label of the composer button while it is in video-note mode
  ///
  /// In en, this message translates to:
  /// **'Hold to record a video note'**
  String get composerRecordVideoNoteLabel;

  /// Tooltip on the microphone button: tapping it swaps the recorder for the camera
  ///
  /// In en, this message translates to:
  /// **'Switch to video note'**
  String get composerSwitchToVideoNote;

  /// Tooltip on the camera button: tapping it swaps the camera back for the microphone
  ///
  /// In en, this message translates to:
  /// **'Switch to voice message'**
  String get composerSwitchToVoice;

  /// Turns the camera around while framing a video note
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get videoNoteSwitchCamera;

  /// Says that a double tap on the circle turns the camera around
  ///
  /// In en, this message translates to:
  /// **'Double-tap to switch camera'**
  String get videoNoteDoubleTapToSwitch;

  /// Shown for the moment between the thumb going down and the camera waking
  ///
  /// In en, this message translates to:
  /// **'Opening the camera…'**
  String get videoNoteOpeningCamera;

  /// Hint under the composer circle before a take starts
  ///
  /// In en, this message translates to:
  /// **'Hold to record'**
  String get videoNoteHoldToRecord;

  /// Button that sends a finished video note
  ///
  /// In en, this message translates to:
  /// **'Send video note'**
  String get videoNoteSend;

  /// Accessible label of the live circle while a video note is being recorded
  ///
  /// In en, this message translates to:
  /// **'Recording a video note'**
  String get videoNoteRecordingLabel;

  /// Hint on a video note playing silently in the feed
  ///
  /// In en, this message translates to:
  /// **'Tap for sound'**
  String get videoNoteTapForSound;

  /// Hint on a video note that currently has sound
  ///
  /// In en, this message translates to:
  /// **'Tap to mute'**
  String get videoNoteTapToMute;

  /// Hint that a long press opens the video note full screen
  ///
  /// In en, this message translates to:
  /// **'Hold for full screen'**
  String get videoNoteHoldForFullScreen;

  /// Accessible label of a video note in the feed
  ///
  /// In en, this message translates to:
  /// **'Video note, {duration}'**
  String videoNotePlayerLabel(String duration);

  /// Shown on a video note that will not start on its own
  ///
  /// In en, this message translates to:
  /// **'Tap to play'**
  String get videoNoteAutoplayOff;

  /// Settings section: when video notes may start playing by themselves
  ///
  /// In en, this message translates to:
  /// **'Autoplay video notes'**
  String get mediaAutoplay;

  /// Explains what autoplay does and how sound is turned on
  ///
  /// In en, this message translates to:
  /// **'Video notes start silently when they scroll into view. Sound comes on when you tap one.'**
  String get mediaAutoplayHint;

  /// Autoplay on any connection
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get mediaAutoplayAlways;

  /// Autoplay only on an unmetered connection
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get mediaAutoplayWifi;

  /// Never autoplay
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get mediaAutoplayNever;

  /// Accessible label of the live camera circle before a take starts
  ///
  /// In en, this message translates to:
  /// **'Camera preview'**
  String get videoNotePreview;

  /// Hint shown when the query is shorter than the server accepts
  ///
  /// In en, this message translates to:
  /// **'Type at least {count} characters'**
  String searchTypeMore(int count);

  /// Explains what the message search covers
  ///
  /// In en, this message translates to:
  /// **'Search looks inside what was said, not at file names or chat titles.'**
  String get noMessagesFoundHint;

  /// Title of the screen behind PATCH /chats/{id}/
  ///
  /// In en, this message translates to:
  /// **'Chat settings'**
  String get chatSettings;

  /// Shown instead of the settings form without chat:update
  ///
  /// In en, this message translates to:
  /// **'Only an owner or admin can change this chat'**
  String get chatSettingsNoPermission;

  /// The API cannot unset name/description (api-docs 5.2)
  ///
  /// In en, this message translates to:
  /// **'A name cannot be removed once the chat has one'**
  String get chatNameCannotBeCleared;

  /// Allowed range for slow_mode_seconds
  ///
  /// In en, this message translates to:
  /// **'0 to {max} seconds'**
  String chatSlowModeRange(int max);

  /// Shown above the allowed_reactions picker
  ///
  /// In en, this message translates to:
  /// **'Pick the emoji people may react with'**
  String get chatReactionsPickHint;

  /// Opposite of chatMutedLabel
  ///
  /// In en, this message translates to:
  /// **'Notifications on'**
  String get chatNotMutedLabel;

  /// Confirmation after muting
  ///
  /// In en, this message translates to:
  /// **'Notifications off for this chat'**
  String get chatMutedToast;

  /// Confirmation after unmuting
  ///
  /// In en, this message translates to:
  /// **'Notifications back on for this chat'**
  String get chatUnmutedToast;

  /// Mute duration option
  ///
  /// In en, this message translates to:
  /// **'Mute for 1 hour'**
  String get muteForHour;

  /// Mute duration option
  ///
  /// In en, this message translates to:
  /// **'Mute for 8 hours'**
  String get muteForEightHours;

  /// Mute duration option: a date far in the future
  ///
  /// In en, this message translates to:
  /// **'Mute until I turn it back on'**
  String get muteForever;

  /// Shown to a creator who has lost chat:delete
  ///
  /// In en, this message translates to:
  /// **'The chat creator cannot leave, and you no longer have permission to delete this chat.'**
  String get leaveChatOwnerStuck;

  /// Heading of the invite link block on a public chat
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get chatInviteLink;

  /// Explains what the invite link can and cannot do
  ///
  /// In en, this message translates to:
  /// **'Anyone signed in to ChatiX can open this link and join. It only opens in the app.'**
  String get chatInviteLinkHint;

  /// Toast after copying the invite link
  ///
  /// In en, this message translates to:
  /// **'Invite link copied'**
  String get chatInviteLinkCopied;

  /// Shared content tab: photos and videos
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get sharedMedia;

  /// Shared content tab: documents
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get sharedFiles;

  /// Shared content tab: web addresses found in messages
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get sharedLinks;

  /// Shared content tab: voice messages
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get sharedVoice;

  /// Empty shared media tab
  ///
  /// In en, this message translates to:
  /// **'No photos or videos here yet'**
  String get sharedMediaEmpty;

  /// Empty shared files tab
  ///
  /// In en, this message translates to:
  /// **'No files here yet'**
  String get sharedFilesEmpty;

  /// Empty shared links tab
  ///
  /// In en, this message translates to:
  /// **'No links here yet'**
  String get sharedLinksEmpty;

  /// Empty shared voice tab
  ///
  /// In en, this message translates to:
  /// **'No voice messages here yet'**
  String get sharedVoiceEmpty;

  /// Footer under every shared content tab
  ///
  /// In en, this message translates to:
  /// **'Shows what this device has loaded from the chat — the server has no shared-media index.'**
  String get sharedContentLocalOnly;

  /// Shown when Save is pressed with no edits to send
  ///
  /// In en, this message translates to:
  /// **'Nothing has changed yet'**
  String get chatSettingsUnchanged;

  /// Placeholder of the member list's search field
  ///
  /// In en, this message translates to:
  /// **'Search members'**
  String get membersSearchHint;

  /// Note under member search: the API has no server-side member search
  ///
  /// In en, this message translates to:
  /// **'Only the members loaded so far are searched.'**
  String get membersSearchLoadedOnly;

  /// No description provided for @membersSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one here matches “{query}”'**
  String membersSearchEmpty(String query);

  /// Fetches the next page of members while a search is on
  ///
  /// In en, this message translates to:
  /// **'Load more people'**
  String get membersLoadMore;

  /// Heading over owner, admin and editor in the member list
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get membersSectionAdmins;

  /// Heading over everyone else in the member list
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersSectionMembers;

  /// Heading over banned members
  ///
  /// In en, this message translates to:
  /// **'Banned members'**
  String get membersSectionBanned;

  /// Explains the banned section
  ///
  /// In en, this message translates to:
  /// **'Banned people cannot read or write here until the ban is lifted.'**
  String get membersBannedHint;

  /// Empty member list heading
  ///
  /// In en, this message translates to:
  /// **'No members to show'**
  String get membersEmptyTitle;

  /// Empty member list, with the invite permission
  ///
  /// In en, this message translates to:
  /// **'Add someone to get this chat started.'**
  String get membersEmptyInvite;

  /// Empty member list, without the invite permission
  ///
  /// In en, this message translates to:
  /// **'Only members with the invite permission can add people here.'**
  String get membersEmptyNoInvite;

  /// Chat role 1
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get chatRoleOwner;

  /// Chat role 2
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get chatRoleAdmin;

  /// Chat role 3
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get chatRoleEditor;

  /// Chat role 4, both sides of a one-to-one chat
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get chatRoleDirect;

  /// Chat role 5
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get chatRoleMember;

  /// Chat role 6, a channel subscriber
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get chatRoleViewer;

  /// Chat role the client does not know
  ///
  /// In en, this message translates to:
  /// **'Unknown role'**
  String get chatRoleUnknown;

  /// Badge on a member a moderator has silenced
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get memberMutedBadge;

  /// Badge on a banned member
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get memberBannedBadge;

  /// Member action
  ///
  /// In en, this message translates to:
  /// **'Open profile'**
  String get memberOpenProfile;

  /// Member action: open or start a one-to-one chat
  ///
  /// In en, this message translates to:
  /// **'Message privately'**
  String get memberMessagePrivately;

  /// No description provided for @memberKickConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String memberKickConfirmTitle(String name);

  /// Body of the remove-member confirmation
  ///
  /// In en, this message translates to:
  /// **'They lose access to this chat, but can be added again later.'**
  String get memberKickConfirmBody;

  /// No description provided for @memberRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} is now {role}'**
  String memberRoleChanged(String name, String role);

  /// No description provided for @memberKicked.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed'**
  String memberKicked(String name);

  /// No description provided for @memberBannedToast.
  ///
  /// In en, this message translates to:
  /// **'{name} was banned'**
  String memberBannedToast(String name);

  /// No description provided for @memberUnbanned.
  ///
  /// In en, this message translates to:
  /// **'The ban on {name} was lifted'**
  String memberUnbanned(String name);

  /// Fallback message when a moderation action fails
  ///
  /// In en, this message translates to:
  /// **'That did not go through. Please try again.'**
  String get memberActionFailed;

  /// Footnote in the role picker (api-docs 5.3)
  ///
  /// In en, this message translates to:
  /// **'You can only assign roles below your own.'**
  String get roleAssignHint;

  /// Footnote in the role picker shown to the owner
  ///
  /// In en, this message translates to:
  /// **'Owner is not in the list: the API has no way to hand a chat over.'**
  String get roleOwnerTransferHint;

  /// Ban duration option
  ///
  /// In en, this message translates to:
  /// **'For an hour'**
  String get banForHour;

  /// Ban duration option
  ///
  /// In en, this message translates to:
  /// **'For a day'**
  String get banForDay;

  /// Ban duration option
  ///
  /// In en, this message translates to:
  /// **'For a week'**
  String get banForWeek;

  /// Title of the member invite screen
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get inviteMembersTitle;

  /// Label over the role picker on the invite screen
  ///
  /// In en, this message translates to:
  /// **'They join as'**
  String get inviteRoleLabel;

  /// No description provided for @inviteRoomLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{This chat is full} =1{Room for 1 more person} other{Room for {count} more people}}'**
  String inviteRoomLeft(int count);

  /// No description provided for @inviteChatFull.
  ///
  /// In en, this message translates to:
  /// **'This chat holds {limit} members, and it is full.'**
  String inviteChatFull(int limit);

  /// No description provided for @inviteAddSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 person} other{Add {count} people}}'**
  String inviteAddSelected(int count);

  /// No description provided for @inviteAddedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person added} other{{count} people added}}'**
  String inviteAddedCount(int count);

  /// No description provided for @inviteFailedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person could not be added} other{{count} people could not be added}}'**
  String inviteFailedCount(int count);

  /// Empty state of the invite screen
  ///
  /// In en, this message translates to:
  /// **'Find people by name or @username, then add them all at once.'**
  String get inviteSearchStart;

  /// Shown when the selection has reached the chat's member limit
  ///
  /// In en, this message translates to:
  /// **'That is everyone this chat has room for.'**
  String get inviteSelectionFull;

  /// No description provided for @peopleSearchNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No one found for “{query}”'**
  String peopleSearchNoneFound(String query);

  /// Hint under an empty people-search result
  ///
  /// In en, this message translates to:
  /// **'Search matches any part of a name or @username.'**
  String get peopleSearchHint;

  /// Action that shares a link to a profile
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get profileShareAction;

  /// No description provided for @profileShareCopied.
  ///
  /// In en, this message translates to:
  /// **'Profile link copied'**
  String get profileShareCopied;

  /// No description provided for @profileBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get profileBirthday;

  /// Shown on a profile with no bio, skills or links
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get profileEmptyTitle;

  /// No description provided for @profileEmptyHintSelf.
  ///
  /// In en, this message translates to:
  /// **'Add a few words about yourself so people know who they are talking to.'**
  String get profileEmptyHintSelf;

  /// No description provided for @profileEmptyHintOther.
  ///
  /// In en, this message translates to:
  /// **'This person has not filled in their profile.'**
  String get profileEmptyHintOther;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccount;

  /// Account row subtitle when no email is known
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get profileAccountNoEmail;

  /// Title of the full-screen avatar viewer
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get profilePhoto;

  /// No description provided for @profileNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'No photo yet'**
  String get profileNoPhoto;

  /// No description provided for @profileOpenLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this link'**
  String get profileOpenLinkFailed;

  /// No description provided for @profileContactCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get profileContactCopied;

  /// No description provided for @profileCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get profileCopyAction;

  /// No description provided for @devicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No devices} =1{1 device} other{{count} devices}}'**
  String devicesCount(int count);

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get choosePhoto;

  /// No description provided for @avatarCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Move and scale'**
  String get avatarCropTitle;

  /// No description provided for @avatarCropHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to move, pinch to zoom.'**
  String get avatarCropHint;

  /// No description provided for @avatarCropConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use photo'**
  String get avatarCropConfirm;

  /// No description provided for @avatarStagePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get avatarStagePreparing;

  /// No description provided for @avatarStageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get avatarStageUploading;

  /// No description provided for @avatarStageConfirming.
  ///
  /// In en, this message translates to:
  /// **'Almost done…'**
  String get avatarStageConfirming;

  /// No description provided for @avatarStageProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing the photo…'**
  String get avatarStageProcessing;

  /// No description provided for @avatarStageDone.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get avatarStageDone;

  /// The upload went through but the server never produced an avatar
  ///
  /// In en, this message translates to:
  /// **'Could not update the photo'**
  String get avatarProcessingFailed;

  /// No description provided for @avatarProcessingFailedHint.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept that picture. Try another one.'**
  String get avatarProcessingFailedHint;

  /// No description provided for @avatarNotAnImage.
  ///
  /// In en, this message translates to:
  /// **'That file is not an image'**
  String get avatarNotAnImage;

  /// No description provided for @avatarTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That picture is too large. Pick a smaller one.'**
  String get avatarTooLarge;

  /// No description provided for @avatarUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That picture could not be opened'**
  String get avatarUnreadable;

  /// Section heading of the profile edit form
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get profileEditDetails;

  /// Section heading for the social links of a profile
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get profileEditLinks;

  /// No description provided for @profileEditLinksHint.
  ///
  /// In en, this message translates to:
  /// **'Links are saved the moment you add or remove one, separately from the form below.'**
  String get profileEditLinksHint;

  /// No description provided for @profileNoLinks.
  ///
  /// In en, this message translates to:
  /// **'No links yet'**
  String get profileNoLinks;

  /// No description provided for @removeLink.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get removeLink;

  /// No description provided for @clearDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Clear date of birth'**
  String get clearDateOfBirth;

  /// No description provided for @specializationHint.
  ///
  /// In en, this message translates to:
  /// **'What you do, in a few words'**
  String get specializationHint;

  /// No description provided for @bioCounter.
  ///
  /// In en, this message translates to:
  /// **'{count}/{max}'**
  String bioCounter(int count, int max);

  /// No description provided for @profileSkillsHint.
  ///
  /// In en, this message translates to:
  /// **'Up to 30 characters each'**
  String get profileSkillsHint;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Your edits to this profile will be lost.'**
  String get discardChangesMessage;

  /// No description provided for @discardAction.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardAction;

  /// No description provided for @keepEditingAction.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditingAction;

  /// Photo source: take a new picture
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// Placeholder while a value is still being fetched
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @fieldTooLong.
  ///
  /// In en, this message translates to:
  /// **'At most {max} characters'**
  String fieldTooLong(int max);

  /// No description provided for @skillTooLong.
  ///
  /// In en, this message translates to:
  /// **'“{skill}” is longer than {max} characters'**
  String skillTooLong(String skill, int max);

  /// LiveKit room slug shown under the call title
  ///
  /// In en, this message translates to:
  /// **'Room {slug}'**
  String callRoomName(String slug);

  /// Explains the join-a-room model on the call screen
  ///
  /// In en, this message translates to:
  /// **'A call here is a room: join it, and anyone else in this chat can join you.'**
  String get callJoinExplanation;

  /// Honest note about missing call_* events (api-docs 5.6)
  ///
  /// In en, this message translates to:
  /// **'Ringing for incoming calls is not available yet — the server does not announce them.'**
  String get callNoIncomingNotice;

  /// Shown while alone in the room
  ///
  /// In en, this message translates to:
  /// **'Waiting for someone else to join…'**
  String get callWaitingForOthers;

  /// LiveKit is rebuilding the connection
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get callReconnecting;

  /// Label for the local participant's tile
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get callYou;

  /// How many people are in the room
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No one here yet} =1{1 participant} other{{count} participants}}'**
  String callParticipantsCount(int count);

  /// Turns the local microphone off
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get callMicrophoneMute;

  /// Turns the local microphone on
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get callMicrophoneUnmute;

  /// Turns the local camera on
  ///
  /// In en, this message translates to:
  /// **'Start video'**
  String get callCameraStart;

  /// Turns the local camera off
  ///
  /// In en, this message translates to:
  /// **'Stop video'**
  String get callCameraStop;

  /// Audio goes out of the loudspeaker
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get callSpeakerOn;

  /// Audio goes out of the earpiece
  ///
  /// In en, this message translates to:
  /// **'Earpiece'**
  String get callSpeakerOff;

  /// Equal-sized tiles layout
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get callLayoutGrid;

  /// One large tile plus a filmstrip
  ///
  /// In en, this message translates to:
  /// **'Speaker view'**
  String get callLayoutSpeaker;

  /// Pins a participant to the large tile
  ///
  /// In en, this message translates to:
  /// **'Pin {name}'**
  String callPinParticipant(String name);

  /// Releases the pinned participant
  ///
  /// In en, this message translates to:
  /// **'Unpin {name}'**
  String callUnpinParticipant(String name);

  /// Moderator mutes a participant server-side
  ///
  /// In en, this message translates to:
  /// **'Mute for everyone'**
  String get callMuteForEveryone;

  /// Moderator lifts a server-side mute
  ///
  /// In en, this message translates to:
  /// **'Let them speak'**
  String get callUnmuteForEveryone;

  /// Connection quality label
  ///
  /// In en, this message translates to:
  /// **'Excellent connection'**
  String get callQualityExcellent;

  /// Connection quality label
  ///
  /// In en, this message translates to:
  /// **'Good connection'**
  String get callQualityGood;

  /// Connection quality label
  ///
  /// In en, this message translates to:
  /// **'Weak connection'**
  String get callQualityPoor;

  /// Connection quality label
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get callQualityLost;

  /// Rationale dialog title before the OS microphone prompt
  ///
  /// In en, this message translates to:
  /// **'Let ChatiX use the microphone'**
  String get callMicrophonePermissionTitle;

  /// Rationale dialog body for the microphone
  ///
  /// In en, this message translates to:
  /// **'The others can only hear you if ChatiX may use the microphone. You can mute yourself again at any time.'**
  String get callMicrophonePermissionBody;

  /// Rationale dialog title before the OS camera prompt
  ///
  /// In en, this message translates to:
  /// **'Let ChatiX use the camera'**
  String get callCameraPermissionTitle;

  /// Rationale dialog body for the camera
  ///
  /// In en, this message translates to:
  /// **'Your video is only sent while the camera is on, and you can turn it off at any time.'**
  String get callCameraPermissionBody;

  /// Proceeds to the platform permission prompt
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get callPermissionContinue;

  /// Declines the rationale dialog
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get callPermissionNotNow;

  /// Sends the user to the app settings page
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get callPermissionOpenSettings;

  /// Banner after the microphone permission was refused
  ///
  /// In en, this message translates to:
  /// **'Microphone is off: ChatiX has no permission for it.'**
  String get callMicrophoneBlocked;

  /// Banner after the camera permission was refused
  ///
  /// In en, this message translates to:
  /// **'Camera is off: ChatiX has no permission for it.'**
  String get callCameraBlocked;

  /// Accessibility label for the floating self preview
  ///
  /// In en, this message translates to:
  /// **'Your camera'**
  String get callSelfPreview;

  /// Accessibility hint for the draggable self preview
  ///
  /// In en, this message translates to:
  /// **'Drag to move'**
  String get callSelfPreviewHint;

  /// Accessibility action that brings the auto-hidden bar back
  ///
  /// In en, this message translates to:
  /// **'Show call controls'**
  String get callShowControls;

  /// Banner in the chat while this device is in its call
  ///
  /// In en, this message translates to:
  /// **'You are in a call in this chat'**
  String get callOngoingInChat;

  /// Goes back to the call screen
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get callReturn;

  /// Accessibility label for the floating mini player
  ///
  /// In en, this message translates to:
  /// **'Call with {name}'**
  String callMiniPlayerLabel(String name);

  /// Leaves the call screen without leaving the call
  ///
  /// In en, this message translates to:
  /// **'Minimize call'**
  String get callMinimize;

  /// Dismisses a call error banner
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get callDismiss;

  /// Body of a chat notification whose text is unavailable or hidden.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notificationNewMessage;

  /// Placeholder in the direct-reply field of a notification.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get notificationReplyHint;

  /// Shown when a reply typed into the notification shade could not be sent.
  ///
  /// In en, this message translates to:
  /// **'Your reply was not sent'**
  String get notificationReplyFailed;

  /// Shown when a notification action other than replying could not be carried out.
  ///
  /// In en, this message translates to:
  /// **'That could not be done'**
  String get notificationActionFailed;

  /// Title of the notification settings screen.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationSettingsTitle;

  /// Toggle: play a sound for notifications.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get notificationSoundTitle;

  /// Explains the notification sound toggle.
  ///
  /// In en, this message translates to:
  /// **'Play a sound when something arrives'**
  String get notificationSoundSubtitle;

  /// Toggle: vibrate for notifications.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get notificationVibrationTitle;

  /// Explains the notification vibration toggle.
  ///
  /// In en, this message translates to:
  /// **'Vibrate when something arrives'**
  String get notificationVibrationSubtitle;

  /// Toggle: show message text inside notifications.
  ///
  /// In en, this message translates to:
  /// **'Message preview'**
  String get notificationPreviewTitle;

  /// Explains the message preview toggle.
  ///
  /// In en, this message translates to:
  /// **'Show who wrote and what they said'**
  String get notificationPreviewSubtitle;

  /// Section title for the nightly silent window.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get quietHoursTitle;

  /// Explains that quiet hours silence notifications rather than hide them.
  ///
  /// In en, this message translates to:
  /// **'Notifications still arrive, just without a sound'**
  String get quietHoursSubtitle;

  /// Start of the quiet hours window.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get quietHoursFrom;

  /// End of the quiet hours window.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get quietHoursTo;

  /// Section listing chats whose notification profile differs from the default.
  ///
  /// In en, this message translates to:
  /// **'Per-chat exceptions'**
  String get chatNotificationsTitle;

  /// Empty state for the per-chat exceptions list.
  ///
  /// In en, this message translates to:
  /// **'No exceptions yet'**
  String get chatNotificationsEmpty;

  /// Tells the reader where a per-chat exception is set.
  ///
  /// In en, this message translates to:
  /// **'Every chat follows the settings above. Change one from inside the chat.'**
  String get chatNotificationsEmptyHint;

  /// Button that clears every per-chat notification exception.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get chatNotificationsReset;

  /// Title of the per-chat notification profile picker.
  ///
  /// In en, this message translates to:
  /// **'Notifications from this chat'**
  String get chatNotificationProfileTitle;

  /// Per-chat profile: notify about every message.
  ///
  /// In en, this message translates to:
  /// **'All messages'**
  String get chatNotificationProfileAll;

  /// Per-chat profile: notify only about mentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions only'**
  String get chatNotificationProfileMentions;

  /// Per-chat profile: no notifications at all.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get chatNotificationProfileOff;

  /// Banner shown when the system has notifications switched off for this app.
  ///
  /// In en, this message translates to:
  /// **'Notifications are switched off'**
  String get notificationPermissionOffTitle;

  /// Explains that the system grant is missing and settings below cannot take effect.
  ///
  /// In en, this message translates to:
  /// **'Nothing below can reach you until you allow notifications in system settings.'**
  String get notificationPermissionOffHint;

  /// Empty state title on the notifications screen.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmptyTitle;

  /// Empty state body on the notifications screen.
  ///
  /// In en, this message translates to:
  /// **'Invites, mentions and messages show up here.'**
  String get notificationsEmptyMessage;

  /// Empty state title when the unread filter is on.
  ///
  /// In en, this message translates to:
  /// **'Nothing unread'**
  String get notificationsEmptyUnread;

  /// Empty state title when the read filter is on.
  ///
  /// In en, this message translates to:
  /// **'Nothing read yet'**
  String get notificationsEmptyRead;

  /// Tells the reader that a filter is hiding everything else.
  ///
  /// In en, this message translates to:
  /// **'Switch the filter to “All” to see everything.'**
  String get notificationsEmptyFilterHint;

  /// Relative timestamp for something that happened moments ago.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// Confirms how many notifications the "read all" button marked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing was unread} =1{1 notification marked as read} other{{count} notifications marked as read}}'**
  String notificationsMarkedRead(int count);

  /// Relative timestamp in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min ago} other{{count} min ago}}'**
  String timeMinutesAgo(int count);

  /// Relative timestamp in hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hr ago} other{{count} hr ago}}'**
  String timeHoursAgo(int count);

  /// Relative timestamp in days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Yesterday} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// The appearance settings screen's title.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// Subtitle of the entry that opens appearance settings.
  ///
  /// In en, this message translates to:
  /// **'Theme, accent, wallpaper, bubbles and media'**
  String get appearanceHint;

  /// Heading over the live sample conversation on the appearance screen.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get appearancePreview;

  /// Sample incoming message in the appearance preview.
  ///
  /// In en, this message translates to:
  /// **'Everything here is drawn from your accent.'**
  String get previewIncomingMessage;

  /// Sample outgoing message in the appearance preview.
  ///
  /// In en, this message translates to:
  /// **'No wallpaper images. Just code.'**
  String get previewOutgoingMessage;

  /// Second sample incoming message in the appearance preview.
  ///
  /// In en, this message translates to:
  /// **'Slide the knobs and watch.'**
  String get previewIncomingReply;

  /// Switch that makes the dark theme true black.
  ///
  /// In en, this message translates to:
  /// **'Black (AMOLED)'**
  String get amoledTitle;

  /// Explains what the AMOLED switch does.
  ///
  /// In en, this message translates to:
  /// **'True black backgrounds. On an OLED screen the black pixels cost no power at all.'**
  String get amoledHint;

  /// Button that seeds the accent from the user's avatar.
  ///
  /// In en, this message translates to:
  /// **'Take the colour from my photo'**
  String get accentFromAvatar;

  /// Confirms the eyedropper found a colour and applied it.
  ///
  /// In en, this message translates to:
  /// **'Accent taken from your photo.'**
  String get accentFromAvatarApplied;

  /// Shown when the avatar holds no usable accent.
  ///
  /// In en, this message translates to:
  /// **'Your photo has no colour to take — it reads as grey.'**
  String get accentFromAvatarEmpty;

  /// Shown when the eyedropper is pressed with no avatar set.
  ///
  /// In en, this message translates to:
  /// **'Add a profile photo first.'**
  String get accentFromAvatarMissing;

  /// Shown when the avatar image could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Could not read your photo. Try again.'**
  String get accentFromAvatarFailed;

  /// Label for an accent that is not one of the curated eight.
  ///
  /// In en, this message translates to:
  /// **'Your colour'**
  String get accentCustom;

  /// Name of the nebula chat wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Nebula'**
  String get wallpaperNebula;

  /// Name of the ribbons chat wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Ribbons'**
  String get wallpaperRibbons;

  /// Name of the prism chat wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Prism'**
  String get wallpaperPrism;

  /// Name of the halo chat wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Halo'**
  String get wallpaperHalo;

  /// Name of the dunes chat wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Dunes'**
  String get wallpaperDunes;

  /// Slider controlling how strongly the wallpaper pattern is painted.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get wallpaperIntensity;

  /// Slider controlling the wallpaper's arrangement.
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get wallpaperPattern;

  /// Section heading for list and bubble spacing.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get appearanceDensity;

  /// Explains the density setting.
  ///
  /// In en, this message translates to:
  /// **'How much room rows and message bubbles take.'**
  String get appearanceDensityHint;

  /// Explains that the app's text scale multiplies the platform one.
  ///
  /// In en, this message translates to:
  /// **'Applied on top of your system text size.'**
  String get textSizeHint;

  /// Section heading for the message bubble geometry.
  ///
  /// In en, this message translates to:
  /// **'Bubble shape'**
  String get bubbleShape;

  /// Slider controlling the message bubble corner radius.
  ///
  /// In en, this message translates to:
  /// **'Corners'**
  String get bubbleCorners;

  /// Switch that pulls a bubble's corner tight on the sender's side.
  ///
  /// In en, this message translates to:
  /// **'Anchor corner'**
  String get bubbleAnchor;

  /// Explains the anchor corner switch.
  ///
  /// In en, this message translates to:
  /// **'Pulls the last bubble of a run tight on the sender\'s side, so it points at whoever sent it.'**
  String get bubbleAnchorHint;

  /// Section heading for the media settings.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get mediaSectionTitle;

  /// Heading for the per-kind auto-download settings.
  ///
  /// In en, this message translates to:
  /// **'Auto-download'**
  String get autoDownload;

  /// Explains auto-download.
  ///
  /// In en, this message translates to:
  /// **'Which attachments are fetched before you open them.'**
  String get autoDownloadHint;

  /// Auto-download row for photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get autoDownloadPhotos;

  /// Auto-download row for videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get autoDownloadVideos;

  /// Auto-download row for documents.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get autoDownloadFiles;

  /// Auto-download row for voice messages.
  ///
  /// In en, this message translates to:
  /// **'Voice messages'**
  String get autoDownloadVoice;

  /// Auto-download on an unmetered connection only.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get autoDownloadWifi;

  /// Auto-download on any connection, mobile data included.
  ///
  /// In en, this message translates to:
  /// **'Mobile data'**
  String get autoDownloadMobile;

  /// Auto-download off; the attachment waits for a tap.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get autoDownloadNever;

  /// Heading for the attachment cache size limit.
  ///
  /// In en, this message translates to:
  /// **'Cache limit'**
  String get cacheLimit;

  /// Explains the cache limit.
  ///
  /// In en, this message translates to:
  /// **'Downloaded attachments are kept until they pass this, then the oldest go first.'**
  String get cacheLimitHint;

  /// Shown when the attachment cache holds no files.
  ///
  /// In en, this message translates to:
  /// **'Nothing cached yet'**
  String get cacheEmpty;

  /// Button that empties the attachment cache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get cacheClear;

  /// Shown while the cache size is being counted.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get cacheMeasuring;

  /// Notice shown on the appearance screen when reduced motion is on.
  ///
  /// In en, this message translates to:
  /// **'Your system asks for reduced motion, so nothing here animates.'**
  String get appearanceReduceMotionNotice;

  /// Notice shown on the appearance screen when high contrast is on.
  ///
  /// In en, this message translates to:
  /// **'High contrast is on, so wallpapers are painted quietly to keep text readable.'**
  String get appearanceHighContrastNotice;

  /// Shows how much disk the attachment cache holds.
  ///
  /// In en, this message translates to:
  /// **'{size} in use'**
  String cacheInUse(String size);

  /// Confirms how much disk clearing the cache freed.
  ///
  /// In en, this message translates to:
  /// **'Freed {size}'**
  String cacheCleared(String size);

  /// A size in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String sizeMegabytes(String value);

  /// A size in gigabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String sizeGigabytes(String value);

  /// Shown over an attachment that auto-download is holding back until the reader asks for it.
  ///
  /// In en, this message translates to:
  /// **'Tap to download'**
  String get attachmentTapToDownload;

  /// Headline on the first launch screen.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ChatiX'**
  String get welcomeHeadline;

  /// One-line promise under the welcome headline.
  ///
  /// In en, this message translates to:
  /// **'Messages that keep up with you.'**
  String get welcomeTagline;

  /// Button that opens the onboarding pages.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get welcomeGetStarted;

  /// Button that skips onboarding straight to sign in.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get welcomeSignIn;

  /// Dismisses the onboarding pages.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Advances to the next onboarding page.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Last onboarding button; opens registration.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get onboardingDone;

  /// Title of the first onboarding page.
  ///
  /// In en, this message translates to:
  /// **'Everything in real time'**
  String get onboardingRealtimeTitle;

  /// Body of the first onboarding page.
  ///
  /// In en, this message translates to:
  /// **'Messages, edits and reactions arrive the moment they happen — and the app opens on the conversation you left, before the network even answers.'**
  String get onboardingRealtimeBody;

  /// Title of the second onboarding page.
  ///
  /// In en, this message translates to:
  /// **'Chats, groups, channels, calls'**
  String get onboardingTogetherTitle;

  /// Body of the second onboarding page.
  ///
  /// In en, this message translates to:
  /// **'One to one, a group of five hundred, or a channel for everyone — with a voice or video call always one tap away.'**
  String get onboardingTogetherBody;

  /// Title of the third onboarding page.
  ///
  /// In en, this message translates to:
  /// **'Only yours'**
  String get onboardingPrivacyTitle;

  /// Body of the third onboarding page.
  ///
  /// In en, this message translates to:
  /// **'See every signed-in device and end any of them, lock the app behind your fingerprint, and keep files on the phone until you send them.'**
  String get onboardingPrivacyBody;

  /// Screen-reader label for the onboarding page indicator.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String onboardingPageOf(int current, int total);

  /// Headline of the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginHeadline;

  /// Subtitle of the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep the conversation going.'**
  String get loginSubtitle;

  /// Headline of the registration screen.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerHeadline;

  /// Subtitle of the registration screen.
  ///
  /// In en, this message translates to:
  /// **'It takes about a minute.'**
  String get registerSubtitle;

  /// Divider above the OAuth provider buttons.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get authOrContinueWith;

  /// Precedes the link to registration.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// Precedes the link to sign in.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHaveAccount;

  /// Shown for WRONG_LOGIN_DATA.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password.'**
  String get authErrorWrongLoginData;

  /// Shown for EMAIL_NOT_CONFIRMED with no address in the detail.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address before signing in.'**
  String get authErrorEmailNotConfirmed;

  /// Shown for EMAIL_NOT_CONFIRMED, naming the address from the error detail.
  ///
  /// In en, this message translates to:
  /// **'Confirm {email} before signing in.'**
  String authErrorEmailNotConfirmedFor(String email);

  /// Action offered next to the unconfirmed-email error.
  ///
  /// In en, this message translates to:
  /// **'Send the email again'**
  String get authResendEmail;

  /// Shown for HTTP 429, which carries a bare {detail} instead of an error envelope.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get authErrorTooManyAttempts;

  /// Shown for DUPLICATE_USER on the username field.
  ///
  /// In en, this message translates to:
  /// **'This username is already taken.'**
  String get authErrorDuplicateUsername;

  /// Shown for DUPLICATE_USER on the email field.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get authErrorDuplicateEmail;

  /// Shown for DUPLICATE_USER on a field the client does not know.
  ///
  /// In en, this message translates to:
  /// **'{field} is already in use.'**
  String authErrorDuplicateField(String field);

  /// Shown for PASSWORD_MISMATCH.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get authErrorPasswordMismatch;

  /// Shown for INVALID_TOKEN / EXPIRED_TOKEN on a verification or reset code.
  ///
  /// In en, this message translates to:
  /// **'This code is no longer valid. Ask for a new one.'**
  String get authErrorInvalidCode;

  /// Shown for NOT_FOUND_USER.
  ///
  /// In en, this message translates to:
  /// **'We could not find an account with these details.'**
  String get authErrorUserNotFound;

  /// Shown when the request never reached the server.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get authErrorOffline;

  /// Fallback for an auth failure with no friendlier wording.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

  /// Label above the password strength meter.
  ///
  /// In en, this message translates to:
  /// **'Password strength'**
  String get passwordStrengthLabel;

  /// Weakest password strength level.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// Second password strength level.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordStrengthFair;

  /// Third password strength level.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get passwordStrengthGood;

  /// Strongest password strength level.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// Tooltip on the reveal-password button.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get passwordShow;

  /// Tooltip on the hide-password button.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get passwordHide;

  /// Headline of the email confirmation screen.
  ///
  /// In en, this message translates to:
  /// **'Check your mail'**
  String get verifyEmailHeadline;

  /// Says where the confirmation code went.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation code to {email}.'**
  String verifyEmailSentTo(String email);

  /// Said when the address is not known to this screen.
  ///
  /// In en, this message translates to:
  /// **'We sent you a confirmation code.'**
  String get verifyEmailSentToYou;

  /// Explains the clipboard auto-check.
  ///
  /// In en, this message translates to:
  /// **'Copy the code from the email — ChatiX picks it up as soon as you come back.'**
  String get verifyEmailClipboardHint;

  /// Confirms that the code was filled in automatically.
  ///
  /// In en, this message translates to:
  /// **'Code taken from the clipboard'**
  String get verifyEmailCodeFromClipboard;

  /// Countdown on the disabled resend button.
  ///
  /// In en, this message translates to:
  /// **'You can ask for a new email in {seconds}s'**
  String verifyEmailResendIn(int seconds);

  /// Precedes the change-address action.
  ///
  /// In en, this message translates to:
  /// **'Wrong address?'**
  String get verifyEmailWrongAddress;

  /// Opens the field for another email address.
  ///
  /// In en, this message translates to:
  /// **'Use a different one'**
  String get verifyEmailChangeAddress;

  /// Settings switch for the app lock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get biometricUnlockTitle;

  /// Explains what the app lock switch does.
  ///
  /// In en, this message translates to:
  /// **'Ask for a fingerprint or face scan when ChatiX is reopened.'**
  String get biometricUnlockSubtitle;

  /// Subtitle of the disabled app lock switch.
  ///
  /// In en, this message translates to:
  /// **'No biometrics are set up on this device.'**
  String get biometricUnlockUnavailable;

  /// Reason shown in the system biometric prompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock ChatiX'**
  String get biometricUnlockReason;

  /// Headline of the lock screen.
  ///
  /// In en, this message translates to:
  /// **'ChatiX is locked'**
  String get biometricUnlockLockedTitle;

  /// Body of the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Unlock to get back to your chats.'**
  String get biometricUnlockLockedBody;

  /// Button on the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get biometricUnlockAction;

  /// Shown after a failed biometric attempt.
  ///
  /// In en, this message translates to:
  /// **'The check did not pass. Try again.'**
  String get biometricUnlockFailed;

  /// Shown when the platform locks biometrics out.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are blocked by the system after too many attempts.'**
  String get biometricUnlockLockedOut;

  /// Shown when biometrics exist but nothing is enrolled.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint or face is enrolled on this device.'**
  String get biometricUnlockNotEnrolled;

  /// Shown when enabling the app lock fails its confirming scan.
  ///
  /// In en, this message translates to:
  /// **'Biometrics could not be turned on.'**
  String get biometricUnlockEnableFailed;

  /// Section header above the app lock switch.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecuritySection;

  /// Section header above the sign-out entry.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// Title of the sign-out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get logoutConfirmTitle;

  /// Body of the sign-out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'This device forgets your messages, drafts and downloaded files. Your account stays as it is.'**
  String get logoutConfirmBody;

  /// Confirming button of the sign-out dialog.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logoutAction;

  /// Shown when the sign-out request fails.
  ///
  /// In en, this message translates to:
  /// **'Could not sign out. Try again.'**
  String get logoutFailed;

  /// Shown while the sign-out is running.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get logoutInProgress;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'bn',
    'de',
    'en',
    'es',
    'fr',
    'ja',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
