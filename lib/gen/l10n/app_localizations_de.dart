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
  String get voiceLimitReached => 'Maximale Länge erreicht';

  @override
  String get voicePermissionDenied => 'Mikrofonzugriff ist deaktiviert';

  @override
  String get voiceMessage => 'Sprachnachricht';

  @override
  String get voicePlay => 'Sprachnachricht abspielen';

  @override
  String get voicePause => 'Sprachnachricht pausieren';

  @override
  String get voiceUnavailable => 'Nicht verfügbar';

  @override
  String get voiceNotListened => 'Noch nicht angehört';

  @override
  String voiceSpeedLabel(String speed) {
    return 'Wiedergabegeschwindigkeit $speed';
  }

  @override
  String get voiceRecording => 'Aufnahme läuft';

  @override
  String voiceTimeLeft(String time) {
    return 'Noch $time';
  }

  @override
  String get voiceCancelRecording => 'Abbrechen';

  @override
  String get voiceSendRecording => 'Sprachnachricht senden';

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
  String get searchPeopleHint => 'Nach Name oder @Benutzername suchen';

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
  String get messageWaitingToSend => 'Wartet auf Versand';

  @override
  String get messageNotSent => 'Nicht gesendet';

  @override
  String get connectionBusy => 'Verbinden…';

  @override
  String get connectionWaitingForNetwork => 'Warten auf Netzwerk';

  @override
  String get wsDiagnostics => 'Verbindungsdiagnose';

  @override
  String wsDiagnosticsFrames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Frames aufgezeichnet',
      one: '1 Frame aufgezeichnet',
      zero: 'Keine Frames aufgezeichnet',
    );
    return '$_temp0';
  }

  @override
  String get wsDiagnosticsCopied => 'Diagnose kopiert';

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

  @override
  String get chatFolders => 'Ordner';

  @override
  String get chatFoldersAll => 'Alle Chats';

  @override
  String get folderPresetUnread => 'Ungelesen';

  @override
  String get folderPresetPersonal => 'Persönlich';

  @override
  String get folderPresetGroups => 'Gruppen';

  @override
  String get folderPresetChannels => 'Kanäle';

  @override
  String get folderPresetNoReply => 'Wartet auf meine Antwort';

  @override
  String get newFolder => 'Neuer Ordner';

  @override
  String get editFolder => 'Ordner bearbeiten';

  @override
  String get folderName => 'Ordnername';

  @override
  String get folderIcon => 'Symbol';

  @override
  String get folderRules => 'Regeln';

  @override
  String get folderMatchModeTitle => 'Ein Chat gehört hierher, wenn';

  @override
  String get folderMatchAll => 'er jede Regel erfüllt';

  @override
  String get folderMatchAny => 'er eine der Regeln erfüllt';

  @override
  String get addFolderRule => 'Regel hinzufügen';

  @override
  String get removeFolderRule => 'Regel entfernen';

  @override
  String get folderRuleChatType => 'Chat-Typ';

  @override
  String folderRuleChatTypeIn(String types) {
    return 'Typ ist $types';
  }

  @override
  String get folderRuleUnread => 'Hat ungelesene Nachrichten';

  @override
  String get folderRuleRead => 'Hat nichts Ungelesenes';

  @override
  String get folderRulePinned => 'Ist angeheftet';

  @override
  String get folderRuleNotPinned => 'Ist nicht angeheftet';

  @override
  String get folderRuleNoReply => 'Wartet auf meine Antwort';

  @override
  String folderRuleNoReplyDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Wartet seit über $days Tagen auf meine Antwort',
      one: 'Wartet seit über 1 Tag auf meine Antwort',
      zero: 'Wartet auf meine Antwort',
    );
    return '$_temp0';
  }

  @override
  String get folderRuleDaysLabel => 'Tage ohne meine Antwort';

  @override
  String get folderRuleDaysAny => 'Beliebig';

  @override
  String get folderRuleMember => 'Enthält eine Person';

  @override
  String folderRuleMemberNamed(String name) {
    return 'Enthält $name';
  }

  @override
  String get folderRulePickPerson => 'Person auswählen';

  @override
  String get folderRuleNoPeople =>
      'Personen erscheinen hier, sobald du Chats mit ihnen hast';

  @override
  String get folderRuleMemberLocalNote =>
      'Greift auf das zurück, was die Chatliste schon weiß: dich, geladene Mitgliederlisten, den letzten Absender und die Person, die den Chat erstellt hat.';

  @override
  String get deleteFolder => 'Ordner löschen';

  @override
  String get deleteFolderConfirm =>
      'Diesen Ordner löschen? Die Chats darin bleiben, wo sie sind.';

  @override
  String get folderNameRequired => 'Gib dem Ordner einen Namen';

  @override
  String folderNameTooLong(int count) {
    return 'Ordnernamen dürfen höchstens $count Zeichen haben';
  }

  @override
  String get folderRulesRequired => 'Füge mindestens eine Regel hinzu';

  @override
  String folderLimitReached(int count) {
    return 'Du kannst bis zu $count Ordner behalten';
  }

  @override
  String pinLimitReached(int count) {
    return 'Es lassen sich nur $count Chats anheften. Löse zuerst einen.';
  }

  @override
  String get foldersEmpty => 'Noch keine Ordner';

  @override
  String get foldersEmptyHint =>
      'Ein Ordner ist ein Satz Regeln, keine Liste. Chats kommen und gehen von selbst.';

  @override
  String get folderReadyMade => 'Vorgefertigt';

  @override
  String get folderYours => 'Deine Ordner';

  @override
  String folderRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Regeln',
      one: '1 Regel',
    );
    return '$_temp0';
  }

  @override
  String get folderEmptyChats => 'Nichts in diesem Ordner';

  @override
  String get folderEmptyChatsHint =>
      'Chats erscheinen hier, sobald sie die Regeln erfüllen.';

  @override
  String get hideFolderTabs => 'Ordnerleiste ausblenden';

  @override
  String get hideFolderTabsHint =>
      'Behält die Ordner, zeigt aber keine Tabs über der Liste';

  @override
  String get unarchiveOnNewMessage => 'Bei neuer Nachricht zurückholen';

  @override
  String get unarchiveOnNewMessageHint =>
      'Ein archivierter Chat kehrt zurück, sobald jemand darin schreibt';

  @override
  String get organizerDeviceOnly =>
      'Ordner liegen auf diesem Gerät und folgen deinem Konto nicht. Anheftungen, Archiv und stummgeschaltete Chats schon.';

  @override
  String get chatPinnedZone => 'Angeheftet';

  @override
  String get chatUnarchivedToast => 'Zurück in der Liste';

  @override
  String get searchTabMessages => 'Nachrichten';

  @override
  String get searchEverything => 'Chats, Personen und Nachrichten suchen';

  @override
  String get searchRecentQueries => 'Letzte Suchen';

  @override
  String get searchRecentChats => 'Zuletzt geöffnet';

  @override
  String get searchClearHistory => 'Leeren';

  @override
  String get searchRemoveFromHistory => 'Aus den letzten Suchen entfernen';

  @override
  String get searchStartTitle =>
      'Finde einen Chat, eine Person oder eine Nachricht';

  @override
  String get searchStartHint =>
      'Chats über den Namen, Personen über den Benutzernamen, Nachrichten über ihren Inhalt.';

  @override
  String get searchLoadedHistoryOnly => 'Auf diesem Gerät gesucht';

  @override
  String get searchLoadedHistoryExplained =>
      'Der Server war nicht erreichbar, deshalb wurden nur die Nachrichten auf diesem Gerät durchsucht.';

  @override
  String get noChatsFound => 'Keine Chats gefunden';

  @override
  String get noChatsFoundHint =>
      'Chats werden über Name und Beschreibung gefunden, unter den bereits geladenen.';

  @override
  String get noPeopleFoundHint =>
      'Versuch eine andere Schreibweise oder such nach dem Benutzernamen.';

  @override
  String get noMessagesFound => 'Keine Nachrichten gefunden';

  @override
  String get messageSearchFailed =>
      'Nachrichten konnten nicht durchsucht werden';

  @override
  String get searchInChat => 'In diesem Chat suchen';

  @override
  String searchMatchPosition(int current, int total) {
    return '$current von $total';
  }

  @override
  String get searchNoMatches => 'Keine Treffer';

  @override
  String get searchOlderMatch => 'Älterer Treffer';

  @override
  String get searchNewerMatch => 'Neuerer Treffer';

  @override
  String get searchInChatHint => 'In diesem Chat suchen';

  @override
  String get searchChatDescriptionMatch => 'Treffer in der Beschreibung';

  @override
  String get searchOpenChat => 'Chat öffnen';

  @override
  String get reactionSectionRecent => 'Zuletzt benutzt';

  @override
  String get reactionSectionFaces => 'Smileys';

  @override
  String get reactionSectionPeople => 'Menschen';

  @override
  String get reactionSectionHearts => 'Herzen';

  @override
  String get reactionSectionCelebration => 'Feiern';

  @override
  String get reactionSectionFood => 'Essen';

  @override
  String get reactionSectionNature => 'Natur';

  @override
  String get reactionSectionSymbols => 'Symbole';

  @override
  String get reactionsNoneAllowed =>
      'In diesem Chat sind keine Reaktionen verfügbar';

  @override
  String reactionsUsed(int used, int limit) {
    return '$used von $limit';
  }

  @override
  String reactionMessageLimitReached(Object limit) {
    return 'Diese Nachricht hat bereits $limit verschiedene Reaktionen';
  }

  @override
  String get moreReactions => 'Weitere Reaktionen';

  @override
  String get reactionFailed => 'Reaktion nicht gespeichert';

  @override
  String get reactionTooFast => 'Zu viele Reaktionen auf einmal';

  @override
  String get reactionNotAllowed => 'Diese Reaktion ist hier nicht erlaubt';

  @override
  String get reactionsNobody => 'Noch niemand';

  @override
  String reactionUserFallback(Object id) {
    return 'Benutzer $id';
  }

  @override
  String composerCharactersLeft(int count) {
    return 'noch $count';
  }

  @override
  String get composerSendLabel => 'Senden';

  @override
  String get composerSaveEditLabel => 'Änderungen speichern';

  @override
  String get composerRecordLabel =>
      'Gedrückt halten, um eine Sprachnachricht aufzunehmen';

  @override
  String composerReplyingTo(Object name) {
    return 'Antwort an $name';
  }

  @override
  String composerSlowModeWait(int seconds) {
    return 'Langsamer Modus: noch $seconds s';
  }

  @override
  String composerSlowModeHint(int seconds) {
    return 'In diesem Chat ist alle $seconds s eine Nachricht erlaubt';
  }

  @override
  String get attachSheetTitle => 'Anhängen';

  @override
  String get attachRecent => 'Zuletzt';

  @override
  String get attachCamera => 'Kamera';

  @override
  String get attachVoice => 'Sprachnachricht';

  @override
  String get attachVideoNote => 'Videonachricht';

  @override
  String attachVoiceHint(int seconds) {
    return 'Wird allein gesendet, bis zu $seconds s';
  }

  @override
  String attachVideoNoteHint(int seconds, int pixels) {
    return 'Wird allein gesendet, bis zu $seconds s und $pixels px';
  }

  @override
  String get attachGalleryDenied =>
      'Erlaube den Fotozugriff, um hier auszuwählen';

  @override
  String get attachGalleryAllow => 'Erlauben';

  @override
  String attachMediaFull(int count) {
    return 'Bis zu $count Fotos oder Videos pro Nachricht';
  }

  @override
  String attachSendCount(int count) {
    return '$count anhängen';
  }

  @override
  String get attachUnavailable => 'Diese Datei konnte nicht gelesen werden';

  @override
  String videoNoteTooLarge(int pixels) {
    return 'Diese Kamera nimmt über $pixels px auf — das lehnt der Server für Videonachrichten ab';
  }

  @override
  String composerTooLongBy(int count) {
    return '$count über dem Limit';
  }

  @override
  String get videoNoteTapToRecord => 'Zum Aufnehmen tippen';

  @override
  String get videoNoteNoCamera => 'Dieses Gerät hat keine Kamera zum Aufnehmen';

  @override
  String get videoNoteCameraDenied =>
      'Erlaube Kamera- und Mikrofonzugriff, um eine Videonachricht aufzunehmen';

  @override
  String get videoNoteCameraFailed =>
      'Die Kamera konnte nicht gestartet werden';

  @override
  String get videoNoteDiscarded => 'Es wurde nichts aufgenommen';

  @override
  String get attachmentOpen => 'Öffnen';

  @override
  String attachmentSavedTo(String path) {
    return 'Gespeichert unter $path';
  }

  @override
  String get attachmentSaveFailed =>
      'Diese Datei konnte nicht gespeichert werden';

  @override
  String get attachmentUploading => 'Wird hochgeladen';

  @override
  String mediaViewerCounter(int index, int count) {
    return '$index von $count';
  }

  @override
  String get mediaViewerUnavailable => 'Dieses Medium ist nicht mehr verfügbar';

  @override
  String get mediaPreviewHint => 'Entfernen Sie, was nicht mitgehen soll';

  @override
  String get mediaPreviewCaptionHint => 'Bildunterschrift hinzufügen';

  @override
  String get mediaPreviewRemove => 'Entfernen';

  @override
  String get composerRecordVideoNoteLabel =>
      'Halten, um eine Videonachricht aufzunehmen';

  @override
  String get composerSwitchToVideoNote => 'Zu Videonachricht wechseln';

  @override
  String get composerSwitchToVoice => 'Zu Sprachnachricht wechseln';

  @override
  String get videoNoteSwitchCamera => 'Kamera wechseln';

  @override
  String get videoNoteDoubleTapToSwitch => 'Zum Kamerawechsel doppeltippen';

  @override
  String get videoNoteOpeningCamera => 'Kamera wird geöffnet …';

  @override
  String get videoNoteHoldToRecord => 'Zum Aufnehmen halten';

  @override
  String get videoNoteSend => 'Videonachricht senden';

  @override
  String get videoNoteRecordingLabel => 'Videonachricht wird aufgenommen';

  @override
  String get videoNoteTapForSound => 'Für Ton tippen';

  @override
  String get videoNoteTapToMute => 'Zum Stummschalten tippen';

  @override
  String get videoNoteHoldForFullScreen => 'Für Vollbild halten';

  @override
  String videoNotePlayerLabel(String duration) {
    return 'Videonachricht, $duration';
  }

  @override
  String get videoNoteAutoplayOff => 'Zum Abspielen tippen';

  @override
  String get mediaAutoplay => 'Videonachrichten automatisch abspielen';

  @override
  String get mediaAutoplayHint =>
      'Videonachrichten starten stumm, sobald sie sichtbar werden. Ton gibt es per Tippen.';

  @override
  String get mediaAutoplayAlways => 'Immer';

  @override
  String get mediaAutoplayWifi => 'Nur über WLAN';

  @override
  String get mediaAutoplayNever => 'Nie';

  @override
  String get videoNotePreview => 'Kameravorschau';

  @override
  String searchTypeMore(int count) {
    return 'Gib mindestens $count Zeichen ein';
  }

  @override
  String get noMessagesFoundHint =>
      'Gesucht wird im Gesagten, nicht in Dateinamen oder Chat-Titeln.';

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
  String get notificationNewMessage => 'Neue Nachricht';

  @override
  String get notificationReplyHint => 'Nachricht';

  @override
  String get notificationReplyFailed => 'Deine Antwort wurde nicht gesendet';

  @override
  String get notificationActionFailed => 'Das hat nicht geklappt';

  @override
  String get notificationSettingsTitle => 'Benachrichtigungen';

  @override
  String get notificationSoundTitle => 'Ton';

  @override
  String get notificationSoundSubtitle =>
      'Einen Ton abspielen, wenn etwas ankommt';

  @override
  String get notificationVibrationTitle => 'Vibration';

  @override
  String get notificationVibrationSubtitle => 'Vibrieren, wenn etwas ankommt';

  @override
  String get notificationPreviewTitle => 'Nachrichtenvorschau';

  @override
  String get notificationPreviewSubtitle => 'Absender und Text anzeigen';

  @override
  String get quietHoursTitle => 'Ruhezeiten';

  @override
  String get quietHoursSubtitle =>
      'Benachrichtigungen kommen weiterhin an, nur lautlos';

  @override
  String get quietHoursFrom => 'Von';

  @override
  String get quietHoursTo => 'Bis';

  @override
  String get chatNotificationsTitle => 'Ausnahmen je Chat';

  @override
  String get chatNotificationsEmpty => 'Noch keine Ausnahmen';

  @override
  String get chatNotificationsEmptyHint =>
      'Alle Chats folgen den Einstellungen oben. Ändere einen Chat direkt in ihm.';

  @override
  String get chatNotificationsReset => 'Alle zurücksetzen';

  @override
  String get chatNotificationProfileTitle =>
      'Benachrichtigungen aus diesem Chat';

  @override
  String get chatNotificationProfileAll => 'Alle Nachrichten';

  @override
  String get chatNotificationProfileMentions => 'Nur Erwähnungen';

  @override
  String get chatNotificationProfileOff => 'Nichts';

  @override
  String get notificationPermissionOffTitle =>
      'Benachrichtigungen sind ausgeschaltet';

  @override
  String get notificationPermissionOffHint =>
      'Nichts davon erreicht dich, solange Benachrichtigungen in den Systemeinstellungen nicht erlaubt sind.';

  @override
  String get notificationsEmptyTitle => 'Noch keine Benachrichtigungen';

  @override
  String get notificationsEmptyMessage =>
      'Einladungen, Erwähnungen und Nachrichten erscheinen hier.';

  @override
  String get notificationsEmptyUnread => 'Nichts Ungelesenes';

  @override
  String get notificationsEmptyRead => 'Noch nichts gelesen';

  @override
  String get notificationsEmptyFilterHint =>
      'Stelle den Filter auf „Alle“, um alles zu sehen.';

  @override
  String get timeJustNow => 'Gerade eben';

  @override
  String notificationsMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Benachrichtigungen als gelesen markiert',
      one: '1 Benachrichtigung als gelesen markiert',
      zero: 'Es war nichts ungelesen',
    );
    return '$_temp0';
  }

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Min.',
      one: 'vor 1 Min.',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Std.',
      one: 'vor 1 Std.',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'Gestern',
    );
    return '$_temp0';
  }

  @override
  String get appearanceTitle => 'Darstellung';

  @override
  String get appearanceHint =>
      'Design, Akzent, Hintergrund, Sprechblasen und Medien';

  @override
  String get appearancePreview => 'Vorschau';

  @override
  String get previewIncomingMessage =>
      'Alles hier entsteht aus deiner Akzentfarbe.';

  @override
  String get previewOutgoingMessage => 'Keine Hintergrundbilder. Nur Code.';

  @override
  String get previewIncomingReply => 'Schieb die Regler und sieh zu.';

  @override
  String get amoledTitle => 'Schwarz (AMOLED)';

  @override
  String get amoledHint =>
      'Echtes Schwarz als Hintergrund. Auf einem OLED-Display kosten schwarze Pixel gar keinen Strom.';

  @override
  String get accentFromAvatar => 'Farbe aus meinem Foto übernehmen';

  @override
  String get accentFromAvatarApplied => 'Akzent aus deinem Foto übernommen.';

  @override
  String get accentFromAvatarEmpty =>
      'Dein Foto hat keine Farbe herzugeben – es wirkt grau.';

  @override
  String get accentFromAvatarMissing => 'Füge zuerst ein Profilfoto hinzu.';

  @override
  String get accentFromAvatarFailed =>
      'Dein Foto konnte nicht gelesen werden. Versuch es noch einmal.';

  @override
  String get accentCustom => 'Deine Farbe';

  @override
  String get wallpaperNebula => 'Nebel';

  @override
  String get wallpaperRibbons => 'Bänder';

  @override
  String get wallpaperPrism => 'Prisma';

  @override
  String get wallpaperHalo => 'Halo';

  @override
  String get wallpaperDunes => 'Dünen';

  @override
  String get wallpaperIntensity => 'Intensität';

  @override
  String get wallpaperPattern => 'Muster';

  @override
  String get appearanceDensity => 'Dichte';

  @override
  String get appearanceDensityHint =>
      'Wie viel Platz Zeilen und Sprechblasen einnehmen.';

  @override
  String get textSizeHint =>
      'Wird zusätzlich zur Textgröße des Systems angewendet.';

  @override
  String get bubbleShape => 'Form der Sprechblasen';

  @override
  String get bubbleCorners => 'Ecken';

  @override
  String get bubbleAnchor => 'Ankerecke';

  @override
  String get bubbleAnchorHint =>
      'Zieht die Ecke auf der Seite des Absenders schmal, sodass die Blase auf ihn zeigt.';

  @override
  String get mediaSectionTitle => 'Medien';

  @override
  String get autoDownload => 'Automatischer Download';

  @override
  String get autoDownloadHint =>
      'Welche Anhänge geladen werden, bevor du sie öffnest.';

  @override
  String get autoDownloadPhotos => 'Fotos';

  @override
  String get autoDownloadVideos => 'Videos';

  @override
  String get autoDownloadFiles => 'Dateien';

  @override
  String get autoDownloadVoice => 'Sprachnachrichten';

  @override
  String get autoDownloadWifi => 'WLAN';

  @override
  String get autoDownloadMobile => 'Mobile Daten';

  @override
  String get autoDownloadNever => 'Nie';

  @override
  String get cacheLimit => 'Cache-Limit';

  @override
  String get cacheLimitHint =>
      'Heruntergeladene Anhänge bleiben bis zu diesem Limit erhalten, danach gehen die ältesten zuerst.';

  @override
  String get cacheEmpty => 'Noch nichts im Cache';

  @override
  String get cacheClear => 'Cache leeren';

  @override
  String get cacheMeasuring => 'Wird berechnet…';

  @override
  String get appearanceReduceMotionNotice =>
      'Dein System bittet um weniger Bewegung – hier animiert sich nichts.';

  @override
  String get appearanceHighContrastNotice =>
      'Hoher Kontrast ist an: Hintergründe werden zurückhaltend gezeichnet, damit Text lesbar bleibt.';

  @override
  String cacheInUse(String size) {
    return '$size belegt';
  }

  @override
  String cacheCleared(String size) {
    return '$size freigegeben';
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
  String get attachmentTapToDownload => 'Zum Laden tippen';

  @override
  String get welcomeHeadline => 'Willkommen bei ChatiX';

  @override
  String get welcomeTagline => 'Nachrichten, die mit dir Schritt halten.';

  @override
  String get welcomeGetStarted => 'Los geht’s';

  @override
  String get welcomeSignIn => 'Ich habe schon ein Konto';

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingDone => 'Konto erstellen';

  @override
  String get onboardingRealtimeTitle => 'Alles in Echtzeit';

  @override
  String get onboardingRealtimeBody =>
      'Nachrichten, Änderungen und Reaktionen kommen in dem Moment an, in dem sie passieren – und die App öffnet sich dort, wo du aufgehört hast, noch bevor das Netz antwortet.';

  @override
  String get onboardingTogetherTitle => 'Chats, Gruppen, Kanäle, Anrufe';

  @override
  String get onboardingTogetherBody =>
      'Zu zweit, in einer Gruppe mit fünfhundert Leuten oder in einem Kanal für alle – ein Sprach- oder Videoanruf ist immer einen Tipp entfernt.';

  @override
  String get onboardingPrivacyTitle => 'Nur deins';

  @override
  String get onboardingPrivacyBody =>
      'Sieh jedes angemeldete Gerät und beende es, sperre die App hinter deinem Fingerabdruck und behalte Dateien auf dem Gerät, bis du sie sendest.';

  @override
  String onboardingPageOf(int current, int total) {
    return 'Seite $current von $total';
  }

  @override
  String get loginHeadline => 'Willkommen zurück';

  @override
  String get loginSubtitle => 'Melde dich an und mach da weiter, wo du warst.';

  @override
  String get registerHeadline => 'Konto erstellen';

  @override
  String get registerSubtitle => 'Dauert etwa eine Minute.';

  @override
  String get authOrContinueWith => 'oder weiter mit';

  @override
  String get authNoAccount => 'Noch kein Konto?';

  @override
  String get authHaveAccount => 'Schon ein Konto?';

  @override
  String get authErrorWrongLoginData =>
      'Benutzername oder Passwort stimmt nicht.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Bestätige deine E-Mail-Adresse, bevor du dich anmeldest.';

  @override
  String authErrorEmailNotConfirmedFor(String email) {
    return 'Bestätige $email, bevor du dich anmeldest.';
  }

  @override
  String get authResendEmail => 'E-Mail erneut senden';

  @override
  String get authErrorTooManyAttempts =>
      'Zu viele Versuche. Warte eine Minute und versuch es noch einmal.';

  @override
  String get authErrorDuplicateUsername =>
      'Dieser Benutzername ist schon vergeben.';

  @override
  String get authErrorDuplicateEmail =>
      'Mit dieser E-Mail-Adresse gibt es bereits ein Konto.';

  @override
  String authErrorDuplicateField(String field) {
    return '$field wird bereits verwendet.';
  }

  @override
  String get authErrorPasswordMismatch =>
      'Die Passwörter stimmen nicht überein.';

  @override
  String get authErrorInvalidCode =>
      'Dieser Code gilt nicht mehr. Fordere einen neuen an.';

  @override
  String get authErrorUserNotFound =>
      'Wir haben kein Konto mit diesen Angaben gefunden.';

  @override
  String get authErrorOffline =>
      'Keine Verbindung. Prüfe dein Netz und versuch es erneut.';

  @override
  String get authErrorGeneric =>
      'Etwas ist schiefgelaufen. Bitte versuch es noch einmal.';

  @override
  String get passwordStrengthLabel => 'Passwortstärke';

  @override
  String get passwordStrengthWeak => 'Schwach';

  @override
  String get passwordStrengthFair => 'Mittel';

  @override
  String get passwordStrengthGood => 'Gut';

  @override
  String get passwordStrengthStrong => 'Stark';

  @override
  String get passwordShow => 'Passwort anzeigen';

  @override
  String get passwordHide => 'Passwort verbergen';

  @override
  String get verifyEmailHeadline => 'Sieh in deine Mails';

  @override
  String verifyEmailSentTo(String email) {
    return 'Wir haben einen Bestätigungscode an $email geschickt.';
  }

  @override
  String get verifyEmailSentToYou =>
      'Wir haben dir einen Bestätigungscode geschickt.';

  @override
  String get verifyEmailClipboardHint =>
      'Kopiere den Code aus der E-Mail – ChatiX übernimmt ihn, sobald du zurückkommst.';

  @override
  String get verifyEmailCodeFromClipboard =>
      'Code aus der Zwischenablage übernommen';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'Neue E-Mail in ${seconds}s möglich';
  }

  @override
  String get verifyEmailWrongAddress => 'Falsche Adresse?';

  @override
  String get verifyEmailChangeAddress => 'Eine andere verwenden';

  @override
  String get biometricUnlockTitle => 'Mit Biometrie entsperren';

  @override
  String get biometricUnlockSubtitle =>
      'Beim erneuten Öffnen von ChatiX nach Fingerabdruck oder Gesicht fragen.';

  @override
  String get biometricUnlockUnavailable =>
      'Auf diesem Gerät ist keine Biometrie eingerichtet.';

  @override
  String get biometricUnlockReason => 'ChatiX entsperren';

  @override
  String get biometricUnlockLockedTitle => 'ChatiX ist gesperrt';

  @override
  String get biometricUnlockLockedBody =>
      'Entsperre die App, um zurück zu deinen Chats zu kommen.';

  @override
  String get biometricUnlockAction => 'Entsperren';

  @override
  String get biometricUnlockFailed =>
      'Die Prüfung ist fehlgeschlagen. Versuch es noch einmal.';

  @override
  String get biometricUnlockLockedOut =>
      'Das System hat die Biometrie nach zu vielen Versuchen gesperrt.';

  @override
  String get biometricUnlockNotEnrolled =>
      'Auf diesem Gerät ist kein Fingerabdruck und kein Gesicht hinterlegt.';

  @override
  String get biometricUnlockEnableFailed =>
      'Biometrie konnte nicht aktiviert werden.';

  @override
  String get settingsSecuritySection => 'Sicherheit';

  @override
  String get settingsAccountSection => 'Konto';

  @override
  String get logoutConfirmTitle => 'Abmelden?';

  @override
  String get logoutConfirmBody =>
      'Dieses Gerät vergisst deine Nachrichten, Entwürfe und geladenen Dateien. Dein Konto bleibt unverändert.';

  @override
  String get logoutAction => 'Abmelden';

  @override
  String get logoutFailed =>
      'Abmelden hat nicht geklappt. Versuch es noch einmal.';

  @override
  String get logoutInProgress => 'Wird abgemeldet …';
}
