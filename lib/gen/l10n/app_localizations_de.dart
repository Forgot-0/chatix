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
}
