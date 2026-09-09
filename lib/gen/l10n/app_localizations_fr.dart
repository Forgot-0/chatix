// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'ChatiX';

  @override
  String get welcomeMessage => 'Bienvenue sur ChatiX';

  @override
  String get home => 'Accueil';

  @override
  String get settings => 'Paramètres';

  @override
  String get profile => 'Profil';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get lightMode => 'Mode clair';

  @override
  String get systemMode => 'Mode système';

  @override
  String get language => 'Langue';

  @override
  String get change_language => 'Changer de langue';

  @override
  String get theme => 'Thème';

  @override
  String get change_theme => 'Changer de thème';

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
  String get logout => 'Se déconnecter';

  @override
  String get login => 'Connexion';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get signIn => 'Se connecter';

  @override
  String get register => 'S’inscrire';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get errorOccurred => 'Une erreur est survenue';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String greeting(String name) {
    return 'Bonjour, $name !';
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
      other: '$countString éléments',
      one: '1 élément',
      zero: 'Aucun élément',
    );
    return '$_temp0';
  }

  @override
  String lastUpdated(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Dernière mise à jour : $dateString';
  }

  @override
  String get browsePeople => 'Personnes';

  @override
  String get chatDirect => 'Discussion privée';

  @override
  String get chatGroup => 'Groupe';

  @override
  String get chatSupergroup => 'Supergroupe';

  @override
  String get chatChannel => 'Canal';

  @override
  String get chatFallbackTitle => 'Discussion';

  @override
  String membersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
      zero: 'Aucun membre',
    );
    return '$_temp0';
  }

  @override
  String get attachmentProcessing => 'Traitement…';

  @override
  String get attachmentFailed => 'Échec de l’envoi';

  @override
  String get attachmentOpenFailed => 'Impossible d’ouvrir ce fichier';

  @override
  String get imageLoadFailed => 'Image indisponible';

  @override
  String get close => 'Fermer';

  @override
  String get addReaction => 'Ajouter une réaction';

  @override
  String get reactionsDisabled =>
      'Les réactions sont désactivées dans cette discussion';

  @override
  String reactionLimitReached(Object limit) {
    return 'Vous pouvez ajouter jusqu’à $limit réactions par message';
  }

  @override
  String get messageNotFound => 'Ce message n’est plus disponible';

  @override
  String get chatInfo => 'Infos sur la discussion';

  @override
  String get chatName => 'Nom';

  @override
  String get chatDescription => 'Description';

  @override
  String get chatPublic => 'Discussion publique';

  @override
  String get chatPublicHint =>
      'Toute personne disposant du lien peut rejoindre';

  @override
  String get chatAdminOnly => 'Administrateurs uniquement';

  @override
  String get chatAdminOnlyHint => 'Seuls les administrateurs peuvent publier';

  @override
  String get chatSlowMode => 'Mode lent';

  @override
  String get chatSlowModeOff => 'Désactivé';

  @override
  String chatSlowModeSeconds(Object seconds) {
    return '${seconds}s entre les messages';
  }

  @override
  String get chatReactionsMode => 'Réactions';

  @override
  String get chatReactionsAll => 'Tout le monde, tout emoji';

  @override
  String get chatReactionsSome => 'Emojis sélectionnés uniquement';

  @override
  String get chatReactionsNone => 'Désactivées';

  @override
  String get leaveChat => 'Quitter la discussion';

  @override
  String get leaveChatConfirm =>
      'Quitter cette discussion ? Vous ne recevrez plus ses messages.';

  @override
  String get leaveChatOwnerBlocked =>
      'Le créateur ne peut pas quitter la discussion — supprimez-la à la place.';

  @override
  String get deleteChat => 'Supprimer la discussion';

  @override
  String get deleteChatConfirm =>
      'Supprimer cette discussion pour tout le monde ? Action irréversible.';

  @override
  String get saveChanges => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get chatSettingsSaved => 'Discussion mise à jour';

  @override
  String get viewMembers => 'Membres';

  @override
  String get messageEdited => 'modifié';

  @override
  String get messageReply => 'Répondre';

  @override
  String get messageForward => 'Transférer';

  @override
  String get messageEdit => 'Modifier';

  @override
  String get messageDelete => 'Supprimer';

  @override
  String get messageSelect => 'Sélectionner';

  @override
  String get backToLatest => 'Revenir aux derniers messages';

  @override
  String get messageRead => 'Lu';

  @override
  String get messageSent => 'Envoyé';

  @override
  String get dateToday => 'Aujourd\'hui';

  @override
  String get dateYesterday => 'Hier';

  @override
  String get unreadMessages => 'Messages non lus';

  @override
  String get noMessagesYet => 'Aucun message pour le moment';

  @override
  String get editingMessage => 'Modification du message';

  @override
  String get scrollToBottom => 'Aller aux messages les plus récents';

  @override
  String get messageDensity => 'Densité des messages';

  @override
  String get densityCompact => 'Compacte';

  @override
  String get densityCozy => 'Normale';

  @override
  String get densityComfortable => 'Aérée';

  @override
  String get voiceSlideToCancel =>
      'Glissez à gauche pour annuler, vers le haut pour verrouiller';

  @override
  String get voiceReleaseToCancel => 'Relâchez pour annuler';

  @override
  String get voiceRecordingLocked =>
      'Enregistrement — appuyez sur envoyer quand vous avez fini';

  @override
  String get voicePermissionDenied => 'L’accès au micro est désactivé';

  @override
  String get voiceMessage => 'Message vocal';

  @override
  String get attach => 'Joindre';

  @override
  String get messageHint => 'Message';

  @override
  String get unknownChat => 'Discussion inconnue';

  @override
  String get unknownProfile => 'Profil inconnu';

  @override
  String get goToChats => 'Aller aux discussions';

  @override
  String get pageNotFound => 'Page introuvable';

  @override
  String pathDoesNotExist(String path) {
    return '$path n’existe pas';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String get clear => 'Effacer';

  @override
  String get add => 'Ajouter';

  @override
  String get save => 'Enregistrer';

  @override
  String get readAll => 'Tout lire';

  @override
  String get filter => 'Filtrer';

  @override
  String get filterAll => 'Toutes';

  @override
  String get filterUnread => 'Non lues seulement';

  @override
  String get filterRead => 'Lues seulement';

  @override
  String get showAll => 'Tout afficher';

  @override
  String get notificationsLoadFailed =>
      'Impossible de charger vos notifications.';

  @override
  String get profiles => 'Personnes';

  @override
  String get searchByName => 'Rechercher par nom';

  @override
  String get searchByUsername => 'Rechercher par identifiant';

  @override
  String get profilesLoadFailed => 'Impossible de charger les profils.';

  @override
  String get signInToViewProfile => 'Connectez-vous pour voir votre profil';

  @override
  String get signInToEditProfile => 'Connectez-vous pour modifier votre profil';

  @override
  String get profileAbout => 'À propos';

  @override
  String get profileSkills => 'Compétences';

  @override
  String get profileContacts => 'Contacts';

  @override
  String get sendMessageAction => 'Message';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get displayName => 'Nom affiché';

  @override
  String get specialization => 'Spécialisation';

  @override
  String get bio => 'Bio';

  @override
  String get dateOfBirth => 'Date de naissance';

  @override
  String get addContact => 'Ajouter un contact';

  @override
  String get contactProvider => 'Fournisseur (ex. telegram)';

  @override
  String get contactHandle => 'Contact (ex. @pseudo)';

  @override
  String get skillsHint => 'Saisissez une compétence et appuyez sur Entrée';

  @override
  String get photoLibraryFailed => 'Impossible d’ouvrir la galerie';

  @override
  String get chats => 'Discussions';

  @override
  String get searchChatsAndPeople => 'Rechercher discussions et personnes';

  @override
  String get chatsLoadFailed => 'Impossible de charger vos discussions.';

  @override
  String get noChatsYet => 'Aucune discussion';

  @override
  String get noChatsYetHint =>
      'Démarrez une conversation, elle apparaîtra ici.';

  @override
  String get newChat => 'Nouvelle discussion';

  @override
  String get chatTypeDirect => 'Direct';

  @override
  String get chatTypeGroup => 'Groupe';

  @override
  String get chatTypeSuper => 'Super';

  @override
  String get chatTypeChannel => 'Canal';

  @override
  String get chatPublicHintCreate =>
      'N’importe qui peut trouver et rejoindre cette discussion';

  @override
  String get chatSlowModeSecondsField => 'Mode lent (secondes)';

  @override
  String get createChat => 'Créer la discussion';

  @override
  String get membersTitle => 'Membres';

  @override
  String get membersLoadFailed => 'Impossible de charger les membres';

  @override
  String get addMember => 'Ajouter un membre';

  @override
  String get changeRole => 'Changer le rôle';

  @override
  String get banMember => 'Bannir';

  @override
  String get banMemberTitle => 'Bannir le membre';

  @override
  String get kickMember => 'Exclure';

  @override
  String get banReason => 'Motif (facultatif)';

  @override
  String get banUntil => 'Choisir une date';

  @override
  String get searchPeople => 'Personnes';

  @override
  String get noPeopleFound => 'Aucune personne trouvée';

  @override
  String get callConnecting => 'Connexion…';

  @override
  String get callJoin => 'Rejoindre l’appel';

  @override
  String get callEnded => 'Appel terminé';

  @override
  String get callRejoin => 'Rejoindre à nouveau';

  @override
  String get callLeave => 'Quitter';

  @override
  String get callTitle => 'Appel';

  @override
  String selectedCount(int count) {
    return '$count sélectionnés';
  }

  @override
  String deleteMessagesTitle(int count) {
    return 'Supprimer $count messages ?';
  }

  @override
  String get cannotBeUndone => 'Cette action est irréversible.';

  @override
  String get chatLoadFailed => 'Impossible de charger la discussion';

  @override
  String get attachMedia => 'Photos et vidéos';

  @override
  String get attachDocument => 'Document';

  @override
  String get messageForwarded => 'Message transféré';

  @override
  String get forwardTo => 'Transférer à';

  @override
  String get noOtherChats => 'Aucune autre discussion';

  @override
  String get chatsLoadFailedShort => 'Impossible de charger les discussions';

  @override
  String get discard => 'Abandonner';

  @override
  String get reactedTitle => 'Ont réagi';

  @override
  String get noReactionsYet => 'Personne n’a encore réagi avec ceci';

  @override
  String get showMore => 'Afficher plus';

  @override
  String get bulkForwarding => 'Transfert';

  @override
  String get bulkDeleting => 'Suppression';

  @override
  String bulkProgress(String label, int done, int total) {
    return '$label $done sur $total…';
  }

  @override
  String bulkComplete(String label, int total) {
    return '$label terminé ($total)';
  }

  @override
  String bulkPartial(int done, int total, int failed, String reason) {
    return '$done sur $total réussis — $failed échecs : $reason';
  }

  @override
  String get callTokenUnavailable => 'Impossible de démarrer l’appel';

  @override
  String get loginTitle => 'Connexion';

  @override
  String get emailOrUsername => 'E-mail ou identifiant';

  @override
  String get emailOrUsernameHint => 'vous@exemple.com ou votre identifiant';

  @override
  String get passwordHint => 'Saisissez votre mot de passe';

  @override
  String get logIn => 'Se connecter';

  @override
  String get username => 'Identifiant';

  @override
  String get usernameHint => '4 à 100 caractères';

  @override
  String get emailHint => 'Saisissez votre e-mail';

  @override
  String get passwordRule =>
      '8+ caractères, majuscule/minuscule/chiffre/spécial';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get confirmPasswordHint => 'Confirmez votre mot de passe';

  @override
  String get signInTitle => 'Connexion';

  @override
  String get backToSignIn => 'Retour à la connexion';

  @override
  String get setNewPassword => 'Définir un nouveau mot de passe';

  @override
  String get resetCode => 'Code de réinitialisation';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get confirmNewPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get resetPassword => 'Réinitialiser le mot de passe';

  @override
  String get passwordUpdated => 'Mot de passe mis à jour — connectez-vous.';

  @override
  String get sendCode => 'Envoyer le code';

  @override
  String get haveCodeAlready => 'J’ai déjà un code';

  @override
  String get resetCodeSent => 'Consultez votre e-mail pour le code.';

  @override
  String get verifyEmailTitle => 'Vérifier l’e-mail';

  @override
  String get verifyEmailHint => 'Collez le jeton reçu par e-mail.';

  @override
  String get verificationToken => 'Jeton de vérification';

  @override
  String get verify => 'Vérifier';

  @override
  String get resendLimitHint =>
      'Nous pouvons le renvoyer — 3 fois par heure maximum.';

  @override
  String get resendVerification => 'Renvoyer l’e-mail de vérification';

  @override
  String get emailVerified => 'E-mail vérifié';

  @override
  String get verificationSent =>
      'E-mail de vérification envoyé — vérifiez votre boîte.';

  @override
  String get browserOpenFailed => 'Impossible d’ouvrir le navigateur';

  @override
  String continueWith(String provider) {
    return 'Continuer avec $provider';
  }

  @override
  String get peopleSearchFailed => 'Impossible de rechercher des personnes';

  @override
  String get startChatFailed =>
      'Impossible de démarrer une discussion avec cette personne';

  @override
  String get profileLoadFailed => 'Impossible de charger ce profil';

  @override
  String get myProfileLoadFailed => 'Impossible de charger votre profil';

  @override
  String get saveChangesFailed => 'Impossible d’enregistrer les modifications';

  @override
  String get avatarUpdateFailed => 'Impossible de mettre à jour l’avatar';

  @override
  String get oauthCancelled => 'Connexion annulée';

  @override
  String get oauthCancelledHint =>
      'Rien n’a changé. Réessayez ou utilisez votre identifiant et mot de passe.';

  @override
  String get oauthFailed => 'Impossible de terminer la connexion';

  @override
  String get oauthFailedHint =>
      'Connectez-vous avec votre identifiant et mot de passe.';

  @override
  String get realtimeRejected =>
      'Les mises à jour en direct sont désactivées pour cette discussion';

  @override
  String get forwardComment => 'Ajouter un commentaire (facultatif)';

  @override
  String get forwardAction => 'Transférer';

  @override
  String get banDuration => 'Durée';

  @override
  String get banForever => 'Définitivement';

  @override
  String get banUntilDate => 'Jusqu\'à une date';

  @override
  String get banLift => 'Lever le bannissement';

  @override
  String get banLiftHint =>
      'Envoie une date passée, que le serveur interprète comme un débannissement';

  @override
  String get banPickDate => 'Choisir une date';

  @override
  String get myDevices => 'Mes appareils';

  @override
  String get devicesLoadFailed => 'Impossible de charger vos appareils.';

  @override
  String get noDevices => 'Aucune session active';

  @override
  String get deviceActive => 'Active';

  @override
  String get deviceInactive => 'Déconnectée';

  @override
  String deviceLastActive(String date) {
    return 'Dernière activité : $date';
  }

  @override
  String get designSystem => 'Système de design';

  @override
  String get accentColor => 'Couleur d’accent';

  @override
  String get chatWallpaper => 'Fond de discussion';

  @override
  String get wallpaperAurora => 'Aurore';

  @override
  String get wallpaperMesh => 'Maillage';

  @override
  String get wallpaperPlain => 'Uni';

  @override
  String get textSize => 'Taille du texte';

  @override
  String get textSizeSmall => 'Petite';

  @override
  String get textSizeDefault => 'Normale';

  @override
  String get textSizeLarge => 'Grande';

  @override
  String get textSizeExtraLarge => 'Très grande';

  @override
  String get resetAppearance => 'Réinitialiser l’apparence';

  @override
  String get showcaseAccents => 'Accents';

  @override
  String get showcaseNeutrals => 'Neutres';

  @override
  String get showcaseNeutralsLight => 'Gamme claire';

  @override
  String get showcaseNeutralsDark => 'Gamme sombre';

  @override
  String get showcaseRadii => 'Rayons';

  @override
  String get showcaseSpacing => 'Espacements';

  @override
  String get showcaseElevation => 'Élévation';

  @override
  String get showcaseMotion => 'Animation';

  @override
  String get showcaseMotionFast => 'Rapide';

  @override
  String get showcaseMotionBase => 'Base';

  @override
  String get showcaseMotionSlow => 'Lente';

  @override
  String get showcaseMotionReplay => 'Rejouer';

  @override
  String get showcaseTypography => 'Typographie';

  @override
  String get showcaseTabularFigures => 'Chiffres tabulaires';

  @override
  String get showcaseBubbles => 'Bulles de message';

  @override
  String get showcaseReactions => 'Réactions';

  @override
  String get showcaseAuthors => 'Accents d’auteur';

  @override
  String get showcaseComponents => 'Composants';

  @override
  String get showcaseIncomingSample => 'Reçu : surface chaude, un filet.';

  @override
  String get showcaseStackedSample => 'Deuxième message de la même série.';

  @override
  String get showcaseOutgoingSample => 'Envoyé : dégradé d’accent.';

  @override
  String get messageSending => 'Envoi…';

  @override
  String get onlineNow => 'En ligne';

  @override
  String userTyping(String name) {
    return '$name écrit…';
  }

  @override
  String severalTyping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes écrivent…',
      one: '1 personne écrit…',
    );
    return '$_temp0';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces jointes',
      one: '1 pièce jointe',
    );
    return '$_temp0';
  }

  @override
  String get contacts => 'Contacts';

  @override
  String get profileSettingsHint =>
      'Votre nom, votre avatar et vos coordonnées';

  @override
  String get noChatSelected => 'Aucune discussion sélectionnée';

  @override
  String get noChatSelectedHint =>
      'Choisissez une conversation dans la liste pour commencer à lire.';

  @override
  String get newDirectChat => 'Nouvelle discussion privée';

  @override
  String get newGroup => 'Nouveau groupe';

  @override
  String get newChannel => 'Nouvelle chaîne';

  @override
  String get quickActionsHint => 'Créer du nouveau';

  @override
  String unreadMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages non lus',
      one: '1 message non lu',
      zero: 'Aucun message non lu',
    );
    return '$_temp0';
  }

  @override
  String unreadNotificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles notifications',
      one: '1 nouvelle notification',
      zero: 'Aucune nouvelle notification',
    );
    return '$_temp0';
  }

  @override
  String get noContactsFound => 'Personne ne correspond à ce nom';

  @override
  String get noContactsFoundHint =>
      'Essayez un nom plus court ou orthographié autrement.';

  @override
  String get noContactsYet => 'Aucune personne à afficher pour l’instant';
}
