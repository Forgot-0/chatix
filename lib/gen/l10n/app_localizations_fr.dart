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
  String get voiceLimitReached => 'Durée maximale atteinte';

  @override
  String get voicePermissionDenied => 'L’accès au micro est désactivé';

  @override
  String get voiceMessage => 'Message vocal';

  @override
  String get voicePlay => 'Lire le message vocal';

  @override
  String get voicePause => 'Mettre en pause le message vocal';

  @override
  String get voiceUnavailable => 'Indisponible';

  @override
  String get voiceNotListened => 'Pas encore écouté';

  @override
  String voiceSpeedLabel(String speed) {
    return 'Vitesse de lecture $speed';
  }

  @override
  String get voiceRecording => 'Enregistrement';

  @override
  String voiceTimeLeft(String time) {
    return '$time restant';
  }

  @override
  String get voiceCancelRecording => 'Annuler';

  @override
  String get voiceSendRecording => 'Envoyer le message vocal';

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
  String get searchPeopleHint => 'Rechercher par nom ou @identifiant';

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
  String get messageWaitingToSend => 'En attente d\'envoi';

  @override
  String get messageNotSent => 'Non envoyé';

  @override
  String get connectionBusy => 'Connexion…';

  @override
  String get connectionWaitingForNetwork => 'En attente du réseau';

  @override
  String get wsDiagnostics => 'Diagnostic de connexion';

  @override
  String wsDiagnosticsFrames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trames enregistrées',
      one: '1 trame enregistrée',
      zero: 'Aucune trame enregistrée',
    );
    return '$_temp0';
  }

  @override
  String get wsDiagnosticsCopied => 'Diagnostic copié';

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

  @override
  String get previewYou => 'Vous';

  @override
  String get previewPhoto => 'Photo';

  @override
  String get previewVideo => 'Vidéo';

  @override
  String get previewVoice => 'Message vocal';

  @override
  String get previewVideoNote => 'Message vidéo';

  @override
  String get previewFile => 'Fichier';

  @override
  String get previewNoText => 'Message';

  @override
  String get draftLabel => 'Brouillon :';

  @override
  String get markAsRead => 'Marquer comme lu';

  @override
  String get archiveChat => 'Archiver';

  @override
  String get unarchiveChat => 'Désarchiver';

  @override
  String get pinChat => 'Épingler';

  @override
  String get unpinChat => 'Détacher';

  @override
  String get muteChat => 'Mettre en sourdine';

  @override
  String get unmuteChat => 'Réactiver les notifications';

  @override
  String get archivedChats => 'Archivés';

  @override
  String get chatPinnedLabel => 'Épinglé';

  @override
  String get chatMutedLabel => 'Notifications désactivées';

  @override
  String get chatArchivedToast => 'Discussion archivée';

  @override
  String get chatDeletedToast => 'Discussion supprimée';

  @override
  String get undo => 'Annuler';

  @override
  String get allChatsArchived => 'Tout est archivé';

  @override
  String previewVoiceWithDuration(String duration) {
    return 'Message vocal $duration';
  }

  @override
  String archivedChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count discussions',
      one: '1 discussion',
    );
    return '$_temp0';
  }

  @override
  String get chatFolders => 'Dossiers';

  @override
  String get chatFoldersAll => 'Tous les chats';

  @override
  String get folderPresetUnread => 'Non lus';

  @override
  String get folderPresetPersonal => 'Personnels';

  @override
  String get folderPresetGroups => 'Groupes';

  @override
  String get folderPresetChannels => 'Canaux';

  @override
  String get folderPresetNoReply => 'En attente de ma réponse';

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get editFolder => 'Modifier le dossier';

  @override
  String get folderName => 'Nom du dossier';

  @override
  String get folderIcon => 'Icône';

  @override
  String get folderRules => 'Règles';

  @override
  String get folderMatchModeTitle => 'Un chat entre ici quand';

  @override
  String get folderMatchAll => 'il respecte toutes les règles';

  @override
  String get folderMatchAny => 'il respecte une des règles';

  @override
  String get addFolderRule => 'Ajouter une règle';

  @override
  String get removeFolderRule => 'Retirer la règle';

  @override
  String get folderRuleChatType => 'Type de chat';

  @override
  String folderRuleChatTypeIn(String types) {
    return 'Le type est $types';
  }

  @override
  String get folderRuleUnread => 'A des messages non lus';

  @override
  String get folderRuleRead => 'N\'a rien de non lu';

  @override
  String get folderRulePinned => 'Est épinglé';

  @override
  String get folderRuleNotPinned => 'N\'est pas épinglé';

  @override
  String get folderRuleNoReply => 'Attend ma réponse';

  @override
  String folderRuleNoReplyDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Attend ma réponse depuis plus de $days jours',
      one: 'Attend ma réponse depuis plus d\'un jour',
      zero: 'Attend ma réponse',
    );
    return '$_temp0';
  }

  @override
  String get folderRuleDaysLabel => 'Jours sans réponse de ma part';

  @override
  String get folderRuleDaysAny => 'Peu importe';

  @override
  String get folderRuleMember => 'Contient une personne';

  @override
  String folderRuleMemberNamed(String name) {
    return 'Contient $name';
  }

  @override
  String get folderRulePickPerson => 'Choisir une personne';

  @override
  String get folderRuleNoPeople =>
      'Les personnes apparaissent ici dès que vous avez des chats avec elles';

  @override
  String get folderRuleMemberLocalNote =>
      'S\'appuie sur ce que la liste connaît déjà : vous, les listes de membres chargées, le dernier expéditeur et la personne qui a créé le chat.';

  @override
  String get deleteFolder => 'Supprimer le dossier';

  @override
  String get deleteFolderConfirm =>
      'Supprimer ce dossier ? Les chats qu’il contient restent où ils sont.';

  @override
  String get folderNameRequired => 'Donnez un nom au dossier';

  @override
  String folderNameTooLong(int count) {
    return 'Les noms de dossier font au plus $count caractères';
  }

  @override
  String get folderRulesRequired => 'Ajoutez au moins une règle';

  @override
  String folderLimitReached(int count) {
    return 'Vous pouvez garder jusqu’à $count dossiers';
  }

  @override
  String pinLimitReached(int count) {
    return 'Seuls $count chats peuvent être épinglés. Détachez-en un d’abord.';
  }

  @override
  String get foldersEmpty => 'Pas encore de dossier';

  @override
  String get foldersEmptyHint =>
      'Un dossier est un jeu de règles, pas une liste. Les chats y entrent et en sortent seuls.';

  @override
  String get folderReadyMade => 'Prêts à l’emploi';

  @override
  String get folderYours => 'Vos dossiers';

  @override
  String folderRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles',
      one: '1 règle',
    );
    return '$_temp0';
  }

  @override
  String get folderEmptyChats => 'Rien dans ce dossier';

  @override
  String get folderEmptyChatsHint =>
      'Les chats apparaissent ici dès qu’ils respectent ses règles.';

  @override
  String get hideFolderTabs => 'Masquer la barre de dossiers';

  @override
  String get hideFolderTabsHint =>
      'Garde vos dossiers sans afficher les onglets au-dessus de la liste';

  @override
  String get unarchiveOnNewMessage => 'Ramener à la réception d’un message';

  @override
  String get unarchiveOnNewMessageHint =>
      'Un chat archivé revient dans la liste dès que quelqu’un y écrit';

  @override
  String get organizerDeviceOnly =>
      'Les dossiers restent sur cet appareil et ne suivent pas votre compte. Les épingles, l’archive et les chats en sourdine, si.';

  @override
  String get chatPinnedZone => 'Épinglés';

  @override
  String get chatUnarchivedToast => 'De retour dans la liste';

  @override
  String get searchTabMessages => 'Messages';

  @override
  String get searchEverything =>
      'Rechercher des chats, des personnes et des messages';

  @override
  String get searchRecentQueries => 'Recherches récentes';

  @override
  String get searchRecentChats => 'Ouverts récemment';

  @override
  String get searchClearHistory => 'Effacer';

  @override
  String get searchRemoveFromHistory => 'Retirer des recherches récentes';

  @override
  String get searchStartTitle => 'Trouvez un chat, une personne ou un message';

  @override
  String get searchStartHint =>
      'Les chats par leur nom, les personnes par leur identifiant, les messages par leur contenu.';

  @override
  String get searchLoadedHistoryOnly =>
      'Recherche dans ce qui est sur cet appareil';

  @override
  String get searchLoadedHistoryExplained =>
      'Le serveur est injoignable : seuls les messages déjà présents sur cet appareil ont été parcourus.';

  @override
  String get noChatsFound => 'Aucun chat trouvé';

  @override
  String get noChatsFoundHint =>
      'Les chats sont trouvés par nom et description, parmi ceux déjà chargés.';

  @override
  String get noPeopleFoundHint =>
      'Essayez une autre orthographe, ou cherchez par identifiant.';

  @override
  String get noMessagesFound => 'Aucun message trouvé';

  @override
  String get messageSearchFailed => 'Impossible de rechercher les messages';

  @override
  String get searchInChat => 'Rechercher dans ce chat';

  @override
  String searchMatchPosition(int current, int total) {
    return '$current sur $total';
  }

  @override
  String get searchNoMatches => 'Aucun résultat';

  @override
  String get searchOlderMatch => 'Résultat plus ancien';

  @override
  String get searchNewerMatch => 'Résultat plus récent';

  @override
  String get searchInChatHint => 'Rechercher dans ce chat';

  @override
  String get searchChatDescriptionMatch => 'Trouvé dans la description';

  @override
  String get searchOpenChat => 'Ouvrir le chat';

  @override
  String get reactionSectionRecent => 'Utilisés récemment';

  @override
  String get reactionSectionFaces => 'Frimousses';

  @override
  String get reactionSectionPeople => 'Personnes';

  @override
  String get reactionSectionHearts => 'Cœurs';

  @override
  String get reactionSectionCelebration => 'Fête';

  @override
  String get reactionSectionFood => 'Nourriture';

  @override
  String get reactionSectionNature => 'Nature';

  @override
  String get reactionSectionSymbols => 'Symboles';

  @override
  String get reactionsNoneAllowed =>
      'Aucune réaction n’est disponible dans cette discussion';

  @override
  String reactionsUsed(int used, int limit) {
    return '$used sur $limit';
  }

  @override
  String reactionMessageLimitReached(Object limit) {
    return 'Ce message a déjà $limit réactions différentes';
  }

  @override
  String get moreReactions => 'Plus de réactions';

  @override
  String get reactionFailed => 'Réaction non enregistrée';

  @override
  String get reactionTooFast => 'Trop de réactions à la fois';

  @override
  String get reactionNotAllowed => 'Cette réaction n’est pas autorisée ici';

  @override
  String get reactionsNobody => 'Personne pour l’instant';

  @override
  String reactionUserFallback(Object id) {
    return 'Utilisateur $id';
  }

  @override
  String composerCharactersLeft(int count) {
    return 'il reste $count';
  }

  @override
  String get composerSendLabel => 'Envoyer';

  @override
  String get composerSaveEditLabel => 'Enregistrer les modifications';

  @override
  String get composerRecordLabel =>
      'Maintenez pour enregistrer un message vocal';

  @override
  String composerReplyingTo(Object name) {
    return 'Répondre à $name';
  }

  @override
  String composerSlowModeWait(int seconds) {
    return 'Mode lent : $seconds s à attendre';
  }

  @override
  String composerSlowModeHint(int seconds) {
    return 'Cette discussion autorise un message toutes les $seconds s';
  }

  @override
  String get attachSheetTitle => 'Joindre';

  @override
  String get attachRecent => 'Récents';

  @override
  String get attachCamera => 'Appareil photo';

  @override
  String get attachVoice => 'Message vocal';

  @override
  String get attachVideoNote => 'Message vidéo';

  @override
  String attachVoiceHint(int seconds) {
    return 'Envoyé seul, jusqu’à $seconds s';
  }

  @override
  String attachVideoNoteHint(int seconds, int pixels) {
    return 'Envoyé seul, jusqu’à $seconds s et $pixels px';
  }

  @override
  String get attachGalleryDenied =>
      'Autorisez l’accès aux photos pour choisir ici';

  @override
  String get attachGalleryAllow => 'Autoriser';

  @override
  String attachMediaFull(int count) {
    return 'Jusqu’à $count photos ou vidéos par message';
  }

  @override
  String attachSendCount(int count) {
    return 'Joindre $count';
  }

  @override
  String get attachUnavailable => 'Ce fichier n’a pas pu être lu';

  @override
  String videoNoteTooLarge(int pixels) {
    return 'Cet appareil filme au-delà de $pixels px, ce que le serveur refuse pour un message vidéo';
  }

  @override
  String composerTooLongBy(int count) {
    return '$count au-dessus de la limite';
  }

  @override
  String get videoNoteTapToRecord => 'Appuyez pour enregistrer';

  @override
  String get videoNoteNoCamera =>
      'Cet appareil n’a pas de caméra pour enregistrer';

  @override
  String get videoNoteCameraDenied =>
      'Autorisez la caméra et le micro pour enregistrer un message vidéo';

  @override
  String get videoNoteCameraFailed => 'La caméra n’a pas pu démarrer';

  @override
  String get videoNoteDiscarded => 'Rien n’a été enregistré';

  @override
  String get attachmentOpen => 'Ouvrir';

  @override
  String attachmentSavedTo(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String get attachmentSaveFailed => 'Impossible d’enregistrer ce fichier';

  @override
  String get attachmentUploading => 'Envoi en cours';

  @override
  String mediaViewerCounter(int index, int count) {
    return '$index sur $count';
  }

  @override
  String get mediaViewerUnavailable => 'Ce média n’est plus disponible';

  @override
  String get mediaPreviewHint => 'Retirez ce que vous ne voulez pas envoyer';

  @override
  String get mediaPreviewCaptionHint => 'Ajouter une légende';

  @override
  String get mediaPreviewRemove => 'Retirer';

  @override
  String get composerRecordVideoNoteLabel =>
      'Maintenez pour enregistrer un message vidéo';

  @override
  String get composerSwitchToVideoNote => 'Passer au message vidéo';

  @override
  String get composerSwitchToVoice => 'Passer au message vocal';

  @override
  String get videoNoteSwitchCamera => 'Changer de caméra';

  @override
  String get videoNoteDoubleTapToSwitch =>
      'Touchez deux fois pour changer de caméra';

  @override
  String get videoNoteOpeningCamera => 'Ouverture de la caméra…';

  @override
  String get videoNoteHoldToRecord => 'Maintenez pour enregistrer';

  @override
  String get videoNoteSend => 'Envoyer le message vidéo';

  @override
  String get videoNoteRecordingLabel => 'Enregistrement d’un message vidéo';

  @override
  String get videoNoteTapForSound => 'Touchez pour activer le son';

  @override
  String get videoNoteTapToMute => 'Touchez pour couper le son';

  @override
  String get videoNoteHoldForFullScreen => 'Maintenez pour le plein écran';

  @override
  String videoNotePlayerLabel(String duration) {
    return 'Message vidéo, $duration';
  }

  @override
  String get videoNoteAutoplayOff => 'Touchez pour lire';

  @override
  String get mediaAutoplay => 'Lecture automatique des messages vidéo';

  @override
  String get mediaAutoplayHint =>
      'Les messages vidéo démarrent sans son dès qu’ils apparaissent. Le son s’active d’une touche.';

  @override
  String get mediaAutoplayAlways => 'Toujours';

  @override
  String get mediaAutoplayWifi => 'Wi-Fi uniquement';

  @override
  String get mediaAutoplayNever => 'Jamais';

  @override
  String get videoNotePreview => 'Aperçu de la caméra';

  @override
  String searchTypeMore(int count) {
    return 'Saisissez au moins $count caractères';
  }

  @override
  String get noMessagesFoundHint =>
      'La recherche porte sur ce qui a été dit, pas sur les noms de fichiers ni les titres des chats.';

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
  String get notificationNewMessage => 'Nouveau message';

  @override
  String get notificationReplyHint => 'Message';

  @override
  String get notificationReplyFailed => 'Votre réponse n\'a pas été envoyée';

  @override
  String get notificationActionFailed => 'Cette action n\'a pas abouti';

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get notificationSoundTitle => 'Son';

  @override
  String get notificationSoundSubtitle =>
      'Émettre un son à l\'arrivée d\'une notification';

  @override
  String get notificationVibrationTitle => 'Vibration';

  @override
  String get notificationVibrationSubtitle =>
      'Vibrer à l\'arrivée d\'une notification';

  @override
  String get notificationPreviewTitle => 'Aperçu du message';

  @override
  String get notificationPreviewSubtitle =>
      'Afficher l\'expéditeur et son message';

  @override
  String get quietHoursTitle => 'Heures silencieuses';

  @override
  String get quietHoursSubtitle =>
      'Les notifications arrivent toujours, mais sans son';

  @override
  String get quietHoursFrom => 'De';

  @override
  String get quietHoursTo => 'Jusqu\'à';

  @override
  String get chatNotificationsTitle => 'Exceptions par discussion';

  @override
  String get chatNotificationsEmpty => 'Aucune exception pour le moment';

  @override
  String get chatNotificationsEmptyHint =>
      'Toutes les discussions suivent les réglages ci-dessus. Modifiez-en une depuis la discussion.';

  @override
  String get chatNotificationsReset => 'Tout réinitialiser';

  @override
  String get chatNotificationProfileTitle =>
      'Notifications de cette discussion';

  @override
  String get chatNotificationProfileAll => 'Tous les messages';

  @override
  String get chatNotificationProfileMentions => 'Mentions uniquement';

  @override
  String get chatNotificationProfileOff => 'Rien';

  @override
  String get notificationPermissionOffTitle =>
      'Les notifications sont désactivées';

  @override
  String get notificationPermissionOffHint =>
      'Rien de ce qui suit ne vous parviendra tant que les notifications ne sont pas autorisées dans les réglages du système.';

  @override
  String get notificationsEmptyTitle => 'Aucune notification pour le moment';

  @override
  String get notificationsEmptyMessage =>
      'Les invitations, mentions et messages apparaîtront ici.';

  @override
  String get notificationsEmptyUnread => 'Rien de non lu';

  @override
  String get notificationsEmptyRead => 'Rien de lu pour le moment';

  @override
  String get notificationsEmptyFilterHint =>
      'Choisissez le filtre « Tout » pour tout afficher.';

  @override
  String get timeJustNow => 'À l\'instant';

  @override
  String notificationsMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications marquées comme lues',
      one: '1 notification marquée comme lue',
      zero: 'Rien n’était non lu',
    );
    return '$_temp0';
  }

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count min',
      one: 'il y a 1 min',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count h',
      one: 'il y a 1 h',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'Hier',
    );
    return '$_temp0';
  }
}
