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
