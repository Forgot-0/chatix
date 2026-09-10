// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Flutter Riverpod Saubere Architektur';

  @override
  String get welcomeMessage =>
      'Willkommen bei Flutter Riverpod Saubere Architektur';

  @override
  String get home => 'Startseite';

  @override
  String get settings => 'Einstellungen';

  @override
  String get profile => 'Profil';

  @override
  String get darkMode => 'Dunkelmodus';

  @override
  String get lightMode => 'Hellmodus';

  @override
  String get systemMode => 'Systemmodus';

  @override
  String get language => 'Sprache';

  @override
  String get change_language => 'Sprache ändern';

  @override
  String get theme => 'Design';

  @override
  String get change_theme => 'Design ändern';

  @override
  String get notifications => 'Benachrichtigungen';

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
  String get logout => 'Abmelden';

  @override
  String get login => 'Anmelden';

  @override
  String get email => 'E-Mail';

  @override
  String get password => 'Passwort';

  @override
  String get signIn => 'Einloggen';

  @override
  String get register => 'Registrieren';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get errorOccurred => 'Ein Fehler ist aufgetreten';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String greeting(String name) {
    return 'Hallo, $name!';
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
      other: '$countString Elemente',
      one: '1 Element',
      zero: 'Keine Elemente',
    );
    return '$_temp0';
  }

  @override
  String lastUpdated(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Zuletzt aktualisiert: $dateString';
  }

  @override
  String get browsePeople => 'Personen';

  @override
  String get chatDirect => 'Direktchat';

  @override
  String get chatGroup => 'Gruppe';

  @override
  String get chatSupergroup => 'Supergruppe';

  @override
  String get chatChannel => 'Kanal';

  @override
  String get chatFallbackTitle => 'Chat';

  @override
  String membersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
      zero: 'Keine Mitglieder',
    );
    return '$_temp0';
  }

  @override
  String get attachmentProcessing => 'Wird verarbeitet…';

  @override
  String get attachmentFailed => 'Upload fehlgeschlagen';

  @override
  String get attachmentOpenFailed => 'Datei konnte nicht geöffnet werden';

  @override
  String get imageLoadFailed => 'Bild nicht verfügbar';

  @override
  String get close => 'Schließen';

  @override
  String get addReaction => 'Reaktion hinzufügen';

  @override
  String get reactionsDisabled => 'Reaktionen sind in diesem Chat deaktiviert';

  @override
  String reactionLimitReached(Object limit) {
    return 'Du kannst bis zu $limit Reaktionen pro Nachricht hinzufügen';
  }

  @override
  String get messageNotFound => 'Diese Nachricht ist nicht mehr verfügbar';

  @override
  String get chatInfo => 'Chat-Info';

  @override
  String get chatName => 'Name';

  @override
  String get chatDescription => 'Beschreibung';

  @override
  String get chatPublic => 'Öffentlicher Chat';

  @override
  String get chatPublicHint => 'Jeder mit dem Link kann beitreten';

  @override
  String get chatAdminOnly => 'Nur Admins';

  @override
  String get chatAdminOnlyHint => 'Nur Admins können schreiben';

  @override
  String get chatSlowMode => 'Langsamer Modus';

  @override
  String get chatSlowModeOff => 'Aus';

  @override
  String chatSlowModeSeconds(Object seconds) {
    return '${seconds}s zwischen Nachrichten';
  }

  @override
  String get chatReactionsMode => 'Reaktionen';

  @override
  String get chatReactionsAll => 'Alle, jedes Emoji';

  @override
  String get chatReactionsSome => 'Nur ausgewählte Emojis';

  @override
  String get chatReactionsNone => 'Deaktiviert';

  @override
  String get leaveChat => 'Chat verlassen';

  @override
  String get leaveChatConfirm =>
      'Diesen Chat verlassen? Du erhältst keine Nachrichten mehr.';

  @override
  String get leaveChatOwnerBlocked =>
      'Der Ersteller kann den Chat nicht verlassen — lösche ihn stattdessen.';

  @override
  String get deleteChat => 'Chat löschen';

  @override
  String get deleteChatConfirm =>
      'Diesen Chat für alle löschen? Das lässt sich nicht rückgängig machen.';

  @override
  String get saveChanges => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get chatSettingsSaved => 'Chat aktualisiert';

  @override
  String get viewMembers => 'Mitglieder';

  @override
  String get messageEdited => 'bearbeitet';

  @override
  String get messageReply => 'Antworten';

  @override
  String get messageForward => 'Weiterleiten';

  @override
  String get messageEdit => 'Bearbeiten';

  @override
  String get messageDelete => 'Löschen';

  @override
  String get messageSelect => 'Auswählen';

  @override
  String get backToLatest => 'Zurück zu den neuesten Nachrichten';

  @override
  String get messageRead => 'Gelesen';

  @override
  String get messageSent => 'Gesendet';

  @override
  String get dateToday => 'Heute';

  @override
  String get dateYesterday => 'Gestern';

  @override
  String get unreadMessages => 'Ungelesene Nachrichten';

  @override
  String get noMessagesYet => 'Noch keine Nachrichten';

  @override
  String get editingMessage => 'Nachricht wird bearbeitet';

  @override
  String get scrollToBottom => 'Zu den neuesten Nachrichten springen';

  @override
  String get messageDensity => 'Nachrichtendichte';

  @override
  String get densityCompact => 'Kompakt';

  @override
  String get densityCozy => 'Normal';

  @override
  String get densityComfortable => 'Luftig';

  @override
  String get voiceSlideToCancel =>
      'Nach links wischen zum Abbrechen, nach oben zum Fixieren';

  @override
  String get voiceReleaseToCancel => 'Loslassen zum Abbrechen';

  @override
  String get voiceRecordingLocked =>
      'Aufnahme läuft — zum Beenden auf Senden tippen';

  @override
  String get voicePermissionDenied => 'Mikrofonzugriff ist deaktiviert';

  @override
  String get voiceMessage => 'Sprachnachricht';

  @override
  String get attach => 'Anhängen';

  @override
  String get messageHint => 'Nachricht';

  @override
  String get unknownChat => 'Unbekannter Chat';

  @override
  String get unknownProfile => 'Unbekanntes Profil';

  @override
  String get goToChats => 'Zu den Chats';

  @override
  String get pageNotFound => 'Seite nicht gefunden';

  @override
  String pathDoesNotExist(String path) {
    return '$path existiert nicht';
  }

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get clear => 'Löschen';

  @override
  String get add => 'Hinzufügen';

  @override
  String get save => 'Speichern';

  @override
  String get readAll => 'Alle lesen';

  @override
  String get filter => 'Filtern';

  @override
  String get filterAll => 'Alle';

  @override
  String get filterUnread => 'Nur ungelesene';

  @override
  String get filterRead => 'Nur gelesene';

  @override
  String get showAll => 'Alle anzeigen';

  @override
  String get notificationsLoadFailed =>
      'Benachrichtigungen konnten nicht geladen werden.';

  @override
  String get profiles => 'Personen';

  @override
  String get searchByName => 'Nach Name suchen';

  @override
  String get searchByUsername => 'Nach Benutzername suchen';

  @override
  String get profilesLoadFailed => 'Profile konnten nicht geladen werden.';

  @override
  String get signInToViewProfile => 'Melde dich an, um dein Profil zu sehen';

  @override
  String get signInToEditProfile =>
      'Melde dich an, um dein Profil zu bearbeiten';

  @override
  String get profileAbout => 'Über';

  @override
  String get profileSkills => 'Fähigkeiten';

  @override
  String get profileContacts => 'Kontakte';

  @override
  String get sendMessageAction => 'Nachricht';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get displayName => 'Anzeigename';

  @override
  String get specialization => 'Spezialisierung';

  @override
  String get bio => 'Bio';

  @override
  String get dateOfBirth => 'Geburtsdatum';

  @override
  String get addContact => 'Kontakt hinzufügen';

  @override
  String get contactProvider => 'Anbieter (z. B. telegram)';

  @override
  String get contactHandle => 'Kontakt (z. B. @handle)';

  @override
  String get skillsHint => 'Fähigkeit eingeben und Enter drücken';

  @override
  String get photoLibraryFailed => 'Fotomediathek konnte nicht geöffnet werden';

  @override
  String get chats => 'Chats';

  @override
  String get searchChatsAndPeople => 'Chats und Personen suchen';

  @override
  String get chatsLoadFailed => 'Chats konnten nicht geladen werden.';

  @override
  String get noChatsYet => 'Noch keine Chats';

  @override
  String get noChatsYetHint => 'Starte ein Gespräch, es erscheint hier.';

  @override
  String get newChat => 'Neuer Chat';

  @override
  String get chatTypeDirect => 'Direkt';

  @override
  String get chatTypeGroup => 'Gruppe';

  @override
  String get chatTypeSuper => 'Super';

  @override
  String get chatTypeChannel => 'Kanal';

  @override
  String get chatPublicHintCreate =>
      'Jeder kann diesen Chat finden und beitreten';

  @override
  String get chatSlowModeSecondsField => 'Langsamer Modus (Sekunden)';

  @override
  String get createChat => 'Chat erstellen';

  @override
  String get membersTitle => 'Mitglieder';

  @override
  String get membersLoadFailed => 'Mitglieder konnten nicht geladen werden';

  @override
  String get addMember => 'Mitglied hinzufügen';

  @override
  String get changeRole => 'Rolle ändern';

  @override
  String get banMember => 'Sperren';

  @override
  String get banMemberTitle => 'Mitglied sperren';

  @override
  String get kickMember => 'Entfernen';

  @override
  String get banReason => 'Grund (optional)';

  @override
  String get banUntil => 'Datum wählen';

  @override
  String get searchPeople => 'Personen';

  @override
  String get noPeopleFound => 'Keine Personen gefunden';

  @override
  String get callConnecting => 'Verbinden…';

  @override
  String get callJoin => 'Anruf beitreten';

  @override
  String get callEnded => 'Anruf beendet';

  @override
  String get callRejoin => 'Erneut beitreten';

  @override
  String get callLeave => 'Verlassen';

  @override
  String get callTitle => 'Anruf';

  @override
  String selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String deleteMessagesTitle(int count) {
    return '$count Nachrichten löschen?';
  }

  @override
  String get cannotBeUndone => 'Das lässt sich nicht rückgängig machen.';

  @override
  String get chatLoadFailed => 'Chat konnte nicht geladen werden';

  @override
  String get attachMedia => 'Fotos & Videos';

  @override
  String get attachDocument => 'Dokument';

  @override
  String get messageForwarded => 'Nachricht weitergeleitet';

  @override
  String get forwardTo => 'Weiterleiten an';

  @override
  String get noOtherChats => 'Keine anderen Chats';

  @override
  String get chatsLoadFailedShort => 'Chats konnten nicht geladen werden';

  @override
  String get discard => 'Verwerfen';

  @override
  String get reactedTitle => 'Reagiert';

  @override
  String get noReactionsYet => 'Damit hat noch niemand reagiert';

  @override
  String get showMore => 'Mehr anzeigen';

  @override
  String get bulkForwarding => 'Weiterleiten';

  @override
  String get bulkDeleting => 'Löschen';

  @override
  String bulkProgress(String label, int done, int total) {
    return '$label $done von $total…';
  }

  @override
  String bulkComplete(String label, int total) {
    return '$label abgeschlossen ($total)';
  }

  @override
  String bulkPartial(int done, int total, int failed, String reason) {
    return '$done von $total erfolgreich — $failed fehlgeschlagen: $reason';
  }

  @override
  String get callTokenUnavailable => 'Anruf konnte nicht gestartet werden';

  @override
  String get loginTitle => 'Anmelden';

  @override
  String get emailOrUsername => 'E-Mail oder Benutzername';

  @override
  String get emailOrUsernameHint => 'du@beispiel.de oder dein Benutzername';

  @override
  String get passwordHint => 'Passwort eingeben';

  @override
  String get logIn => 'Anmelden';

  @override
  String get username => 'Benutzername';

  @override
  String get usernameHint => '4–100 Zeichen';

  @override
  String get emailHint => 'E-Mail eingeben';

  @override
  String get passwordRule =>
      '8+ Zeichen, Groß-/Kleinbuchstabe/Ziffer/Sonderzeichen';

  @override
  String get confirmPassword => 'Passwort bestätigen';

  @override
  String get confirmPasswordHint => 'Passwort bestätigen';

  @override
  String get signInTitle => 'Anmelden';

  @override
  String get backToSignIn => 'Zurück zur Anmeldung';

  @override
  String get setNewPassword => 'Neues Passwort festlegen';

  @override
  String get resetCode => 'Zurücksetzungscode';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get confirmNewPassword => 'Neues Passwort bestätigen';

  @override
  String get resetPassword => 'Passwort zurücksetzen';

  @override
  String get passwordUpdated => 'Passwort aktualisiert — bitte anmelden.';

  @override
  String get sendCode => 'Code senden';

  @override
  String get haveCodeAlready => 'Ich habe bereits einen Code';

  @override
  String get resetCodeSent => 'Prüfe deine E-Mails auf den Code.';

  @override
  String get verifyEmailTitle => 'E-Mail bestätigen';

  @override
  String get verifyEmailHint => 'Füge den Token aus unserer E-Mail ein.';

  @override
  String get verificationToken => 'Bestätigungstoken';

  @override
  String get verify => 'Bestätigen';

  @override
  String get resendLimitHint =>
      'Wir können ihn erneut senden — bis zu 3-mal pro Stunde.';

  @override
  String get resendVerification => 'Bestätigungs-E-Mail erneut senden';

  @override
  String get emailVerified => 'E-Mail bestätigt';

  @override
  String get verificationSent =>
      'Bestätigungs-E-Mail gesendet — prüfe dein Postfach.';

  @override
  String get browserOpenFailed => 'Browser konnte nicht geöffnet werden';

  @override
  String continueWith(String provider) {
    return 'Weiter mit $provider';
  }

  @override
  String get peopleSearchFailed => 'Personensuche fehlgeschlagen';

  @override
  String get startChatFailed =>
      'Chat mit dieser Person konnte nicht gestartet werden';

  @override
  String get profileLoadFailed => 'Profil konnte nicht geladen werden';

  @override
  String get myProfileLoadFailed => 'Dein Profil konnte nicht geladen werden';

  @override
  String get saveChangesFailed => 'Änderungen konnten nicht gespeichert werden';

  @override
  String get avatarUpdateFailed => 'Avatar konnte nicht aktualisiert werden';

  @override
  String get oauthCancelled => 'Anmeldung abgebrochen';

  @override
  String get oauthCancelledHint =>
      'Es wurde nichts geändert. Versuche es erneut oder nutze Benutzername und Passwort.';

  @override
  String get oauthFailed => 'Anmeldung konnte nicht abgeschlossen werden';

  @override
  String get oauthFailedHint =>
      'Melde dich stattdessen mit Benutzername und Passwort an.';

  @override
  String get realtimeRejected => 'Live-Updates sind für diesen Chat aus';

  @override
  String get forwardComment => 'Kommentar hinzufügen (optional)';

  @override
  String get forwardAction => 'Weiterleiten';

  @override
  String get banDuration => 'Dauer';

  @override
  String get banForever => 'Dauerhaft';

  @override
  String get banUntilDate => 'Bis zu einem Datum';

  @override
  String get banLift => 'Sperre aufheben';

  @override
  String get banLiftHint =>
      'Sendet ein vergangenes Datum, das der Server als Entsperrung liest';

  @override
  String get banPickDate => 'Datum wählen';

  @override
  String get myDevices => 'Meine Geräte';

  @override
  String get devicesLoadFailed => 'Geräte konnten nicht geladen werden.';

  @override
  String get noDevices => 'Keine aktiven Sitzungen';

  @override
  String get deviceActive => 'Aktiv';

  @override
  String get deviceInactive => 'Abgemeldet';

  @override
  String deviceLastActive(String date) {
    return 'Zuletzt aktiv: $date';
  }

  @override
  String get designSystem => 'Designsystem';

  @override
  String get accentColor => 'Akzentfarbe';

  @override
  String get chatWallpaper => 'Chat-Hintergrund';

  @override
  String get wallpaperAurora => 'Aurora';

  @override
  String get wallpaperMesh => 'Netz';

  @override
  String get wallpaperPlain => 'Schlicht';

  @override
  String get textSize => 'Textgröße';

  @override
  String get textSizeSmall => 'Klein';

  @override
  String get textSizeDefault => 'Standard';

  @override
  String get textSizeLarge => 'Groß';

  @override
  String get textSizeExtraLarge => 'Sehr groß';

  @override
  String get resetAppearance => 'Darstellung zurücksetzen';

  @override
  String get showcaseAccents => 'Akzente';

  @override
  String get showcaseNeutrals => 'Neutraltöne';

  @override
  String get showcaseNeutralsLight => 'Helle Skala';

  @override
  String get showcaseNeutralsDark => 'Dunkle Skala';

  @override
  String get showcaseRadii => 'Radien';

  @override
  String get showcaseSpacing => 'Abstände';

  @override
  String get showcaseElevation => 'Erhebung';

  @override
  String get showcaseMotion => 'Bewegung';

  @override
  String get showcaseMotionFast => 'Schnell';

  @override
  String get showcaseMotionBase => 'Basis';

  @override
  String get showcaseMotionSlow => 'Langsam';

  @override
  String get showcaseMotionReplay => 'Erneut abspielen';

  @override
  String get showcaseTypography => 'Typografie';

  @override
  String get showcaseTabularFigures => 'Tabellenziffern';

  @override
  String get showcaseBubbles => 'Nachrichtenblasen';

  @override
  String get showcaseReactions => 'Reaktionen';

  @override
  String get showcaseAuthors => 'Autorenakzente';

  @override
  String get showcaseComponents => 'Komponenten';

  @override
  String get showcaseIncomingSample =>
      'Eingehend: warme Fläche, eine Haarlinie.';

  @override
  String get showcaseStackedSample => 'Zweite Nachricht derselben Folge.';

  @override
  String get showcaseOutgoingSample => 'Ausgehend: Akzentverlauf.';

  @override
  String get messageSending => 'Wird gesendet';

  @override
  String get onlineNow => 'Online';

  @override
  String userTyping(String name) {
    return '$name schreibt…';
  }

  @override
  String severalTyping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen schreiben…',
      one: '1 Person schreibt…',
    );
    return '$_temp0';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Anhänge',
      one: '1 Anhang',
    );
    return '$_temp0';
  }

  @override
  String get contacts => 'Kontakte';

  @override
  String get profileSettingsHint => 'Dein Name, Avatar und Kontaktdaten';

  @override
  String get noChatSelected => 'Kein Chat ausgewählt';

  @override
  String get noChatSelectedHint =>
      'Wähle eine Unterhaltung aus der Liste, um sie zu lesen.';

  @override
  String get newDirectChat => 'Neuer Direktchat';

  @override
  String get newGroup => 'Neue Gruppe';

  @override
  String get newChannel => 'Neuer Kanal';

  @override
  String get quickActionsHint => 'Etwas Neues starten';

  @override
  String unreadMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ungelesene Nachrichten',
      one: '1 ungelesene Nachricht',
      zero: 'Keine ungelesenen Nachrichten',
    );
    return '$_temp0';
  }

  @override
  String unreadNotificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Benachrichtigungen',
      one: '1 neue Benachrichtigung',
      zero: 'Keine neuen Benachrichtigungen',
    );
    return '$_temp0';
  }

  @override
  String get noContactsFound => 'Niemand passt zu diesem Namen';

  @override
  String get noContactsFoundHint =>
      'Versuch es mit einem kürzeren oder anders geschriebenen Namen.';

  @override
  String get noContactsYet => 'Noch keine Personen vorhanden';

  @override
  String get previewYou => 'Du';

  @override
  String get previewPhoto => 'Foto';

  @override
  String get previewVideo => 'Video';

  @override
  String get previewVoice => 'Sprachnachricht';

  @override
  String get previewVideoNote => 'Videonachricht';

  @override
  String get previewFile => 'Datei';

  @override
  String get previewNoText => 'Nachricht';

  @override
  String get draftLabel => 'Entwurf:';

  @override
  String get markAsRead => 'Als gelesen markieren';

  @override
  String get archiveChat => 'Archivieren';

  @override
  String get unarchiveChat => 'Aus Archiv holen';

  @override
  String get pinChat => 'Anheften';

  @override
  String get unpinChat => 'Loslösen';

  @override
  String get muteChat => 'Stummschalten';

  @override
  String get unmuteChat => 'Stummschaltung aufheben';

  @override
  String get archivedChats => 'Archiviert';

  @override
  String get chatPinnedLabel => 'Angeheftet';

  @override
  String get chatMutedLabel => 'Benachrichtigungen aus';

  @override
  String get chatArchivedToast => 'Chat archiviert';

  @override
  String get chatDeletedToast => 'Chat gelöscht';

  @override
  String get undo => 'Rückgängig';

  @override
  String get allChatsArchived => 'Alles ist archiviert';

  @override
  String previewVoiceWithDuration(String duration) {
    return 'Sprachnachricht $duration';
  }

  @override
  String archivedChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Chats',
      one: '1 Chat',
    );
    return '$_temp0';
  }
}
