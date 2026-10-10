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
  String get notification_settings => 'Benachrichtigungen einstellen';

  @override
  String get localization_demo => 'Lokalisierungs-Demo';

  @override
  String get localization_demo_description => 'Lokalisierung in Aktion sehen';

  @override
  String get language_settings => 'Spracheinstellungen';

  @override
  String get select_your_language => 'Wähle deine Sprache';

  @override
  String get language_explanation =>
      'Die gewählte Sprache gilt für die gesamte App';

  @override
  String get localization_assets_demo => 'Lokalisierung & Assets';

  @override
  String get current_language => 'Aktuelle Sprache';

  @override
  String get language_code => 'Sprachcode';

  @override
  String get language_name => 'Sprachname';

  @override
  String get formatting_examples => 'Formatierungsbeispiele';

  @override
  String get date_full => 'Datum (vollständig)';

  @override
  String get date_short => 'Datum (kurz)';

  @override
  String get time => 'Uhrzeit';

  @override
  String get currency => 'Währung';

  @override
  String get percent => 'Prozent';

  @override
  String get localized_assets => 'Lokalisierte Assets';

  @override
  String get localized_assets_explanation =>
      'Dieser Abschnitt zeigt, wie sich je nach Sprache andere Assets laden lassen. Bilder, Audio und andere Ressourcen können sprachabhängig sein.';

  @override
  String get image_example => 'Beispiel für ein lokalisiertes Bild';

  @override
  String get welcome_image_caption =>
      'Dieses Bild richtet sich nach deiner Sprache';

  @override
  String get common_image_example => 'Beispiel für ein gemeinsames Bild';

  @override
  String get common_image_caption => 'Dieses Bild ist in allen Sprachen gleich';

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
  String get messageReact => 'Reagieren';

  @override
  String get messageCopy => 'Text kopieren';

  @override
  String get messageCopied => 'Kopiert';

  @override
  String get linkOpenFailed => 'Diesen Link kann hier nichts öffnen';

  @override
  String get messageDetails => 'Details';

  @override
  String replyingTo(String author) {
    return 'Antwort an $author';
  }

  @override
  String forwardedFrom(String author) {
    return 'Weitergeleitet von $author';
  }

  @override
  String get forwardedMessage => 'Weitergeleitete Nachricht';

  @override
  String get detailsSentAt => 'Gesendet';

  @override
  String get detailsAuthor => 'Von';

  @override
  String get detailsSequence => 'Nummer im Chat';

  @override
  String get detailsEdited => 'Bearbeitet';

  @override
  String get detailsEditedYes => 'Ja';

  @override
  String get detailsDelivery => 'Zustellung';

  @override
  String get detailsAttachments => 'Anhänge';

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
      other: '$count neue Nachrichten weiter unten',
      one: '1 neue Nachricht weiter unten',
      zero: 'Keine neuen Nachrichten',
    );
    return '$_temp0';
  }

  @override
  String get connectionReconnecting => 'Neu verbinden…';

  @override
  String get connectionOffline => 'Offline — zum Aktualisieren ziehen';

  @override
  String get attachmentFallbackLabel => 'Anhang';

  @override
  String get composerJoinToSend => 'Tritt diesem Chat bei, um zu schreiben';

  @override
  String get composerBanned => 'Du bist in diesem Chat gesperrt';

  @override
  String get composerMuted => 'Du darfst in diesem Chat nicht schreiben';

  @override
  String get composerAdminsOnly => 'In diesem Chat dürfen nur Admins schreiben';

  @override
  String get composerNoPermission => 'Du darfst hier keine Nachrichten senden';

  @override
  String attachmentSelection(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return '$_temp0, $size';
  }

  @override
  String get attachmentReady => 'Bereit zum Senden';

  @override
  String attachMediaLimits(int count, String size) {
    return 'Bis zu $count, je $size';
  }

  @override
  String attachDocumentLimits(String size) {
    return 'Eine Datei, bis $size';
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
  String get chatSettings => 'Chat-Einstellungen';

  @override
  String get chatSettingsNoPermission =>
      'Nur Eigentümer oder Admin können diesen Chat ändern';

  @override
  String get chatNameCannotBeCleared =>
      'Ein Name lässt sich nicht mehr entfernen, wenn der Chat einen hat';

  @override
  String chatSlowModeRange(int max) {
    return '0 bis $max Sekunden';
  }

  @override
  String get chatReactionsPickHint =>
      'Wähle die Emoji, mit denen reagiert werden darf';

  @override
  String get chatNotMutedLabel => 'Benachrichtigungen an';

  @override
  String get chatMutedToast => 'Benachrichtigungen für diesen Chat aus';

  @override
  String get chatUnmutedToast => 'Benachrichtigungen für diesen Chat wieder an';

  @override
  String get muteForHour => '1 Stunde stummschalten';

  @override
  String get muteForEightHours => '8 Stunden stummschalten';

  @override
  String get muteForever => 'Stumm, bis ich es wieder einschalte';

  @override
  String get leaveChatOwnerStuck =>
      'Der Ersteller kann den Chat nicht verlassen, und du darfst ihn nicht mehr löschen.';

  @override
  String get chatInviteLink => 'Einladungslink';

  @override
  String get chatInviteLinkHint =>
      'Jeder, der bei ChatiX angemeldet ist, kann diesen Link öffnen und beitreten. Er öffnet sich nur in der App.';

  @override
  String get chatInviteLinkCopied => 'Einladungslink kopiert';

  @override
  String get sharedMedia => 'Medien';

  @override
  String get sharedFiles => 'Dateien';

  @override
  String get sharedLinks => 'Links';

  @override
  String get sharedVoice => 'Sprache';

  @override
  String get sharedMediaEmpty => 'Noch keine Fotos oder Videos hier';

  @override
  String get sharedFilesEmpty => 'Noch keine Dateien hier';

  @override
  String get sharedLinksEmpty => 'Noch keine Links hier';

  @override
  String get sharedVoiceEmpty => 'Noch keine Sprachnachrichten hier';

  @override
  String get sharedContentLocalOnly =>
      'Zeigt, was dieses Gerät aus dem Chat geladen hat — der Server führt kein Verzeichnis geteilter Medien.';

  @override
  String get chatSettingsUnchanged => 'Noch nichts geändert';

  @override
  String get membersSearchHint => 'Mitglieder suchen';

  @override
  String get membersSearchLoadedOnly =>
      'Es wird nur unter den bereits geladenen Mitgliedern gesucht.';

  @override
  String membersSearchEmpty(String query) {
    return 'Hier passt niemand zu „$query“';
  }

  @override
  String get membersLoadMore => 'Mehr Leute laden';

  @override
  String get membersSectionAdmins => 'Verwaltung';

  @override
  String get membersSectionMembers => 'Mitglieder';

  @override
  String get membersSectionBanned => 'Gesperrte Mitglieder';

  @override
  String get membersBannedHint =>
      'Gesperrte können hier weder lesen noch schreiben, bis die Sperre aufgehoben wird.';

  @override
  String get membersEmptyTitle => 'Keine Mitglieder zu zeigen';

  @override
  String get membersEmptyInvite =>
      'Füge jemanden hinzu, damit der Chat losgeht.';

  @override
  String get membersEmptyNoInvite =>
      'Nur Mitglieder mit Einladungsrecht können hier Leute hinzufügen.';

  @override
  String get chatRoleOwner => 'Eigentümer';

  @override
  String get chatRoleAdmin => 'Admin';

  @override
  String get chatRoleEditor => 'Redakteur';

  @override
  String get chatRoleDirect => 'Direkt';

  @override
  String get chatRoleMember => 'Mitglied';

  @override
  String get chatRoleViewer => 'Leser';

  @override
  String get chatRoleUnknown => 'Unbekannte Rolle';

  @override
  String get memberMutedBadge => 'Stumm';

  @override
  String get memberBannedBadge => 'Gesperrt';

  @override
  String get memberOpenProfile => 'Profil öffnen';

  @override
  String get memberMessagePrivately => 'Privat schreiben';

  @override
  String memberKickConfirmTitle(String name) {
    return '$name entfernen?';
  }

  @override
  String get memberKickConfirmBody =>
      'Der Zugang zu diesem Chat geht verloren, ein späteres Hinzufügen bleibt möglich.';

  @override
  String memberRoleChanged(String name, String role) {
    return '$name ist jetzt $role';
  }

  @override
  String memberKicked(String name) {
    return '$name wurde entfernt';
  }

  @override
  String memberBannedToast(String name) {
    return '$name wurde gesperrt';
  }

  @override
  String memberUnbanned(String name) {
    return 'Die Sperre für $name wurde aufgehoben';
  }

  @override
  String get memberActionFailed =>
      'Das hat nicht geklappt. Bitte versuche es erneut.';

  @override
  String get roleAssignHint =>
      'Du kannst nur Rollen unterhalb deiner eigenen vergeben.';

  @override
  String get roleOwnerTransferHint =>
      'Eigentümer steht nicht zur Wahl: Die API kann einen Chat nicht übergeben.';

  @override
  String get banForHour => 'Für eine Stunde';

  @override
  String get banForDay => 'Für einen Tag';

  @override
  String get banForWeek => 'Für eine Woche';

  @override
  String get inviteMembersTitle => 'Leute hinzufügen';

  @override
  String get inviteRoleLabel => 'Treten bei als';

  @override
  String inviteRoomLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Platz für $count weitere Personen',
      one: 'Platz für 1 weitere Person',
      zero: 'Dieser Chat ist voll',
    );
    return '$_temp0';
  }

  @override
  String inviteChatFull(int limit) {
    return 'Dieser Chat fasst $limit Mitglieder und ist voll.';
  }

  @override
  String inviteAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen hinzufügen',
      one: '1 Person hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String inviteAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen hinzugefügt',
      one: '1 Person hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String inviteFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen konnten nicht hinzugefügt werden',
      one: '1 Person konnte nicht hinzugefügt werden',
    );
    return '$_temp0';
  }

  @override
  String get inviteSearchStart =>
      'Finde Leute über Name oder @username und füge sie alle auf einmal hinzu.';

  @override
  String get inviteSelectionFull => 'Mehr passt in diesen Chat nicht hinein.';

  @override
  String peopleSearchNoneFound(String query) {
    return 'Niemand gefunden für „$query“';
  }

  @override
  String get peopleSearchHint =>
      'Die Suche greift auf jeden Teil eines Namens oder @username.';

  @override
  String get profileShareAction => 'Teilen';

  @override
  String get profileShareCopied => 'Profillink kopiert';

  @override
  String get profileBirthday => 'Geburtstag';

  @override
  String get profileEmptyTitle => 'Hier ist noch nichts';

  @override
  String get profileEmptyHintSelf =>
      'Schreib ein paar Worte über dich, damit andere wissen, mit wem sie reden.';

  @override
  String get profileEmptyHintOther =>
      'Diese Person hat ihr Profil nicht ausgefüllt.';

  @override
  String get profileAccount => 'Konto';

  @override
  String get profileAccountNoEmail => 'Angemeldet';

  @override
  String get profilePhoto => 'Foto';

  @override
  String get profileNoPhoto => 'Noch kein Foto';

  @override
  String get profileOpenLinkFailed => 'Dieser Link ließ sich nicht öffnen';

  @override
  String get profileContactCopied => 'In die Zwischenablage kopiert';

  @override
  String get profileCopyAction => 'Kopieren';

  @override
  String devicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Geräte',
      one: '1 Gerät',
      zero: 'Keine Geräte',
    );
    return '$_temp0';
  }

  @override
  String get changePhoto => 'Foto ändern';

  @override
  String get setPhoto => 'Foto festlegen';

  @override
  String get choosePhoto => 'Foto auswählen';

  @override
  String get avatarCropTitle => 'Verschieben und zoomen';

  @override
  String get avatarCropHint =>
      'Ziehen zum Verschieben, zwei Finger zum Zoomen.';

  @override
  String get avatarCropConfirm => 'Foto verwenden';

  @override
  String get avatarStagePreparing => 'Wird vorbereitet…';

  @override
  String get avatarStageUploading => 'Wird hochgeladen…';

  @override
  String get avatarStageConfirming => 'Fast fertig…';

  @override
  String get avatarStageProcessing => 'Foto wird verarbeitet…';

  @override
  String get avatarStageDone => 'Foto aktualisiert';

  @override
  String get avatarProcessingFailed => 'Foto konnte nicht aktualisiert werden';

  @override
  String get avatarProcessingFailedHint =>
      'Der Server hat dieses Bild nicht angenommen. Versuch ein anderes.';

  @override
  String get avatarNotAnImage => 'Diese Datei ist kein Bild';

  @override
  String get avatarTooLarge => 'Dieses Bild ist zu groß. Nimm ein kleineres.';

  @override
  String get avatarUnreadable => 'Dieses Bild ließ sich nicht öffnen';

  @override
  String get profileEditDetails => 'Angaben';

  @override
  String get profileEditLinks => 'Links';

  @override
  String get profileEditLinksHint =>
      'Links werden sofort beim Hinzufügen oder Entfernen gespeichert, getrennt vom Formular darunter.';

  @override
  String get profileNoLinks => 'Noch keine Links';

  @override
  String get removeLink => 'Link entfernen';

  @override
  String get clearDateOfBirth => 'Geburtsdatum löschen';

  @override
  String get specializationHint => 'Was du machst, in wenigen Worten';

  @override
  String bioCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String get profileSkillsHint => 'Je bis zu 30 Zeichen';

  @override
  String get profileSaved => 'Profil gespeichert';

  @override
  String get discardChangesTitle => 'Änderungen verwerfen?';

  @override
  String get discardChangesMessage =>
      'Deine Änderungen an diesem Profil gehen verloren.';

  @override
  String get discardAction => 'Verwerfen';

  @override
  String get keepEditingAction => 'Weiter bearbeiten';

  @override
  String get camera => 'Kamera';

  @override
  String get loading => 'Wird geladen…';

  @override
  String fieldTooLong(int max) {
    return 'Höchstens $max Zeichen';
  }

  @override
  String skillTooLong(String skill, int max) {
    return '„$skill“ ist länger als $max Zeichen';
  }

  @override
  String callRoomName(String slug) {
    return 'Raum $slug';
  }

  @override
  String get callJoinExplanation =>
      'Ein Anruf ist hier ein Raum: Tritt bei, und alle anderen in diesem Chat können dazukommen.';

  @override
  String get callNoIncomingNotice =>
      'Ein Klingeln bei eingehenden Anrufen gibt es noch nicht — der Server kündigt sie nicht an.';

  @override
  String get callWaitingForOthers => 'Warten, bis jemand dazukommt…';

  @override
  String get callReconnecting => 'Neu verbinden…';

  @override
  String get callYou => 'Du';

  @override
  String callParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Teilnehmer',
      one: '1 Teilnehmer',
      zero: 'Noch niemand hier',
    );
    return '$_temp0';
  }

  @override
  String get callMicrophoneMute => 'Stumm';

  @override
  String get callMicrophoneUnmute => 'Stummschaltung aus';

  @override
  String get callCameraStart => 'Video starten';

  @override
  String get callCameraStop => 'Video stoppen';

  @override
  String get callSpeakerOn => 'Lautsprecher';

  @override
  String get callSpeakerOff => 'Hörmuschel';

  @override
  String get callLayoutGrid => 'Raster';

  @override
  String get callLayoutSpeaker => 'Sprecheransicht';

  @override
  String callPinParticipant(String name) {
    return '$name anheften';
  }

  @override
  String callUnpinParticipant(String name) {
    return '$name lösen';
  }

  @override
  String get callMuteForEveryone => 'Für alle stummschalten';

  @override
  String get callUnmuteForEveryone => 'Sprechen erlauben';

  @override
  String get callQualityExcellent => 'Ausgezeichnete Verbindung';

  @override
  String get callQualityGood => 'Gute Verbindung';

  @override
  String get callQualityPoor => 'Schwache Verbindung';

  @override
  String get callQualityLost => 'Verbindung verloren';

  @override
  String get callMicrophonePermissionTitle => 'Lass ChatiX das Mikrofon nutzen';

  @override
  String get callMicrophonePermissionBody =>
      'Die anderen hören dich nur, wenn ChatiX das Mikrofon nutzen darf. Du kannst dich jederzeit wieder stummschalten.';

  @override
  String get callCameraPermissionTitle => 'Lass ChatiX die Kamera nutzen';

  @override
  String get callCameraPermissionBody =>
      'Dein Video wird nur gesendet, solange die Kamera an ist, und du kannst sie jederzeit ausschalten.';

  @override
  String get callPermissionContinue => 'Weiter';

  @override
  String get callPermissionNotNow => 'Jetzt nicht';

  @override
  String get callPermissionOpenSettings => 'Einstellungen öffnen';

  @override
  String get callMicrophoneBlocked =>
      'Mikrofon aus: ChatiX hat keine Berechtigung dafür.';

  @override
  String get callCameraBlocked =>
      'Kamera aus: ChatiX hat keine Berechtigung dafür.';

  @override
  String get callSelfPreview => 'Deine Kamera';

  @override
  String get callSelfPreviewHint => 'Zum Verschieben ziehen';

  @override
  String get callShowControls => 'Anrufsteuerung zeigen';

  @override
  String get callOngoingInChat => 'Du bist in einem Anruf in diesem Chat';

  @override
  String get callReturn => 'Zurück';

  @override
  String callMiniPlayerLabel(String name) {
    return 'Anruf mit $name';
  }

  @override
  String get callMinimize => 'Anruf verkleinern';

  @override
  String get callDismiss => 'Schließen';

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

  @override
  String get appearanceFeel => 'Haptik';

  @override
  String get appearanceHaptics => 'Vibration';

  @override
  String get appearanceHapticsHint =>
      'Kurze Vibrationen, wenn eine Nachricht rausgeht, eine Reaktion ankommt oder eine Geste greift. Die Vibrationseinstellung deines Geräts gilt weiterhin.';

  @override
  String get failureGeneric =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get failureRateLimited =>
      'Zu viele Versuche. Warte eine Minute und versuche es erneut.';

  @override
  String get failureNoConnection =>
      'Keine Internetverbindung. Prüfe dein Netzwerk und versuche es erneut.';

  @override
  String get failureTimeout =>
      'Der Server hat zu lange gebraucht. Bitte versuche es erneut.';

  @override
  String get failureInsecureSessionCookie =>
      'Der Server hat ein unsicheres Anmelde-Cookie gesendet, daher wurde die Sitzung nicht gespeichert. Das ist eine Servereinstellung – bitte wende dich an den Support.';

  @override
  String get apiErrorSessionEnded =>
      'Deine Sitzung ist beendet. Bitte melde dich erneut an.';

  @override
  String get apiErrorSessionExpired =>
      'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';

  @override
  String get apiErrorSessionInvalid =>
      'Deine Sitzung ist nicht mehr gültig. Bitte melde dich erneut an.';

  @override
  String get apiErrorSessionSignedOut =>
      'Diese Sitzung wurde abgemeldet. Bitte melde dich erneut an.';

  @override
  String get apiErrorAccessDenied => 'Dafür fehlt dir die Berechtigung.';

  @override
  String get apiErrorValidation =>
      'Einige Angaben sind ungültig. Bitte prüfe sie und versuche es erneut.';

  @override
  String get apiErrorNotFoundGeneric =>
      'Das konnten wir nicht finden — vielleicht wurde es gelöscht.';

  @override
  String get apiErrorTooLongGeneric =>
      'Dieser Wert ist zu lang. Bitte kürze ihn.';

  @override
  String get apiErrorLimitExceededGeneric =>
      'Ein Limit ist erreicht, diese Aktion ist daher nicht verfügbar.';

  @override
  String get apiErrorWrongLoginData => 'Benutzername oder Passwort ist falsch.';

  @override
  String get apiErrorPasswordMismatch =>
      'Die Passwörter stimmen nicht überein.';

  @override
  String get apiErrorDuplicateUser =>
      'Dieser Benutzername oder diese E-Mail ist bereits vergeben.';

  @override
  String get apiErrorEmailNotConfirmed =>
      'Bitte bestätige deine E-Mail-Adresse vor der Anmeldung.';

  @override
  String get apiErrorOauthProviderUnsupported =>
      'Dieser Anmeldedienst wird nicht unterstützt.';

  @override
  String get apiErrorOauthStateNotFound =>
      'Der Anmeldeversuch ist abgelaufen. Bitte versuche es erneut.';

  @override
  String get apiErrorOauthLinkedAnotherUser =>
      'Dieses Konto ist bereits mit einem anderen Nutzer verknüpft.';

  @override
  String get apiErrorProfileExists => 'Du hast bereits ein Profil.';

  @override
  String get apiErrorNotChatMember => 'Du bist kein Mitglied dieses Chats.';

  @override
  String get apiErrorAlreadyChatMember =>
      'Diese Person ist bereits in diesem Chat.';

  @override
  String get apiErrorInvalidChatRole => 'Das ist keine gültige Chat-Rolle.';

  @override
  String get apiErrorDirectChatExists =>
      'Du hast bereits einen Direktchat mit dieser Person.';

  @override
  String get apiErrorMessageTooLong =>
      'Diese Nachricht ist zu lang. Bitte kürze sie.';

  @override
  String get apiErrorInvalidMessage =>
      'Diese Nachricht kann so nicht gesendet werden.';

  @override
  String get apiErrorSlowModeLimit =>
      'Der Langsam-Modus ist aktiv — warte kurz vor der nächsten Nachricht.';

  @override
  String get apiErrorSlowModeOutOfRange =>
      'Der Langsam-Modus muss zwischen 0 Sekunden und 24 Stunden liegen.';

  @override
  String get apiErrorAttachmentLimitExceeded =>
      'Zu viele Anhänge für eine Nachricht.';

  @override
  String get apiErrorAttachmentNotFound =>
      'Dieser Anhang ist nicht mehr verfügbar.';

  @override
  String get apiErrorAttachmentValidation =>
      'Diese Datei kann nicht angehängt werden — prüfe Typ und Größe.';

  @override
  String get apiErrorEmptyAttachmentUpload =>
      'Bitte wähle eine Datei zum Anhängen.';

  @override
  String get apiErrorInvalidUploadToken =>
      'Der Upload ist abgelaufen. Hänge die Datei erneut an.';

  @override
  String get apiErrorAvatarNotImage => 'Ein Avatar muss eine Bilddatei sein.';

  @override
  String get apiErrorActiveCallExists =>
      'In diesem Chat läuft bereits ein Anruf.';

  @override
  String get apiErrorNoActiveCall => 'In diesem Chat läuft kein Anruf.';

  @override
  String get apiErrorLivekitUnauthorized =>
      'Du kannst diesem Anruf nicht beitreten.';

  @override
  String get apiErrorLivekitError =>
      'Der Anrufdienst ist derzeit nicht verfügbar.';

  @override
  String get apiErrorInvalidReaction =>
      'Dieses Emoji kann nicht als Reaktion verwendet werden.';

  @override
  String get apiErrorReactionNotAllowed =>
      'Diese Reaktion ist in diesem Chat nicht erlaubt.';

  @override
  String get apiErrorReactionsDisabled =>
      'Reaktionen sind in diesem Chat ausgeschaltet.';

  @override
  String get apiErrorTooManyReactions =>
      'Hier können keine weiteren Reaktionen hinzugefügt werden.';

  @override
  String get apiErrorMaxLimitCursor =>
      'Zu viele Chats wurden auf einmal fortgesetzt.';

  @override
  String a11yMessageFrom(String author, String time) {
    return 'Nachricht von $author, $time';
  }

  @override
  String a11yMessageMine(String time) {
    return 'Deine Nachricht, $time';
  }

  @override
  String get a11ySystemMessage => 'Systemnachricht';

  @override
  String a11yReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reaktionen',
      one: '1 Reaktion',
    );
    return '$_temp0';
  }

  @override
  String get a11yReactionYours => 'einschließlich deiner';

  @override
  String get a11yMessageActionsHint => 'Nachrichtenaktionen anzeigen';

  @override
  String a11yMessageAttachmentsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Anhänge',
      one: '1 Anhang',
    );
    return '$_temp0';
  }

  @override
  String get reviewPromptTitle => 'Gefällt dir die App?';

  @override
  String get reviewPromptBody => 'Möchtest du uns deine Meinung sagen?';

  @override
  String get reviewPromptDecline => 'Nein danke';

  @override
  String get reviewPromptAccept => 'Klar';

  @override
  String get feedbackTitle => 'Deine Meinung zählt';

  @override
  String get feedbackBody =>
      'Sag uns, was du von der App hältst. Wenn sie dir gefällt, hilft uns eine Bewertung im Store sehr.';

  @override
  String get feedbackHint => 'Schreib dein Feedback hier';

  @override
  String get feedbackSubmit => 'Senden';

  @override
  String get updateRequiredTitle => 'Update erforderlich';

  @override
  String get updateAvailableTitle => 'Update verfügbar';

  @override
  String updateRequiredBody(String version) {
    return 'Für ChatiX wird Version $version benötigt.';
  }

  @override
  String updateAvailableBody(String version) {
    return 'Version $version ist verfügbar.';
  }

  @override
  String get updateWhatsNew => 'Neu in dieser Version';

  @override
  String get updateLater => 'Später';

  @override
  String get updateNow => 'Jetzt aktualisieren';

  @override
  String get updateAction => 'Aktualisieren';

  @override
  String sizeBytes(String value) {
    return '$value B';
  }

  @override
  String sizeKilobytes(String value) {
    return '$value KB';
  }

  @override
  String attachmentDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get attachmentDownload => 'Herunterladen';

  @override
  String get attachmentDownloadFailed =>
      'Die Datei konnte nicht heruntergeladen werden';

  @override
  String get attachmentShareFailed => 'Die Datei konnte nicht geteilt werden';

  @override
  String get attachmentRevealFailed =>
      'Der Ordner konnte nicht geöffnet werden';

  @override
  String get messageSaveFile => 'Speichern';

  @override
  String get messageShareFile => 'Teilen';

  @override
  String get messageShowInFolder => 'Im Ordner anzeigen';

  @override
  String get bubbleFill => 'Deine Blasen';

  @override
  String get bubbleFillGradient => 'Verlauf';

  @override
  String get bubbleFillSolid => 'Einfarbig';
}
