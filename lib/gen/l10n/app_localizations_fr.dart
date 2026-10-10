// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

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
  String get notification_settings => 'Configurer les notifications';

  @override
  String get localization_demo => 'Démo de localisation';

  @override
  String get localization_demo_description => 'Voir la localisation à l\'œuvre';

  @override
  String get language_settings => 'Paramètres de langue';

  @override
  String get select_your_language => 'Choisissez votre langue';

  @override
  String get language_explanation =>
      'La langue choisie s\'applique à toute l\'application';

  @override
  String get time => 'Heure';

  @override
  String get currency => 'Devise';

  @override
  String get percent => 'Pourcentage';

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
  String get messageReact => 'Réagir';

  @override
  String get messageCopy => 'Copier le texte';

  @override
  String get messageCopied => 'Copié';

  @override
  String get linkOpenFailed => 'Rien ici ne peut ouvrir ce lien';

  @override
  String get messageDetails => 'Détails';

  @override
  String replyingTo(String author) {
    return 'Réponse à $author';
  }

  @override
  String forwardedFrom(String author) {
    return 'Transféré de $author';
  }

  @override
  String get forwardedMessage => 'Message transféré';

  @override
  String get detailsSentAt => 'Envoyé';

  @override
  String get detailsAuthor => 'De';

  @override
  String get detailsSequence => 'Numéro dans la discussion';

  @override
  String get detailsEdited => 'Modifié';

  @override
  String get detailsEditedYes => 'Oui';

  @override
  String get detailsDelivery => 'Distribution';

  @override
  String get detailsAttachments => 'Pièces jointes';

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
      other: '$count nouveaux messages plus bas',
      one: '1 nouveau message plus bas',
      zero: 'Aucun nouveau message',
    );
    return '$_temp0';
  }

  @override
  String get connectionReconnecting => 'Reconnexion…';

  @override
  String get connectionOffline => 'Hors ligne — tirez pour actualiser';

  @override
  String get attachmentFallbackLabel => 'Pièce jointe';

  @override
  String get composerJoinToSend => 'Rejoignez cette discussion pour écrire';

  @override
  String get composerBanned => 'Vous êtes banni de cette discussion';

  @override
  String get composerMuted => 'Vous ne pouvez pas écrire dans cette discussion';

  @override
  String get composerAdminsOnly =>
      'Seuls les administrateurs peuvent écrire ici';

  @override
  String get composerNoPermission => 'Vous n\'avez pas le droit d\'écrire ici';

  @override
  String attachmentSelection(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return '$_temp0, $size';
  }

  @override
  String get attachmentReady => 'Prêt à envoyer';

  @override
  String attachMediaLimits(int count, String size) {
    return 'Jusqu\'à $count, $size chacun';
  }

  @override
  String attachDocumentLimits(String size) {
    return 'Un fichier, jusqu\'à $size';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count messages ?',
      one: 'Supprimer $count message ?',
    );
    return '$_temp0';
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
  String get chatSettings => 'Paramètres de la discussion';

  @override
  String get chatSettingsNoPermission =>
      'Seul le propriétaire ou un administrateur peut modifier cette discussion';

  @override
  String get chatNameCannotBeCleared =>
      'Un nom ne peut plus être retiré une fois que la discussion en a un';

  @override
  String chatSlowModeRange(int max) {
    return 'de 0 à $max secondes';
  }

  @override
  String get chatReactionsPickHint =>
      'Choisissez les emoji autorisés en réaction';

  @override
  String get chatNotMutedLabel => 'Notifications activées';

  @override
  String get chatMutedToast =>
      'Notifications désactivées pour cette discussion';

  @override
  String get chatUnmutedToast =>
      'Notifications réactivées pour cette discussion';

  @override
  String get muteForHour => 'Couper 1 heure';

  @override
  String get muteForEightHours => 'Couper 8 heures';

  @override
  String get muteForever => 'Couper jusqu\'à ce que je réactive';

  @override
  String get leaveChatOwnerStuck =>
      'Le créateur ne peut pas quitter la discussion, et vous n\'avez plus le droit de la supprimer.';

  @override
  String get chatInviteLink => 'Lien d\'invitation';

  @override
  String get chatInviteLinkHint =>
      'Toute personne connectée à ChatiX peut ouvrir ce lien et rejoindre. Il ne s\'ouvre que dans l\'application.';

  @override
  String get chatInviteLinkCopied => 'Lien d\'invitation copié';

  @override
  String get sharedMedia => 'Médias';

  @override
  String get sharedFiles => 'Fichiers';

  @override
  String get sharedLinks => 'Liens';

  @override
  String get sharedVoice => 'Voix';

  @override
  String get sharedMediaEmpty => 'Pas encore de photos ni de vidéos ici';

  @override
  String get sharedFilesEmpty => 'Pas encore de fichiers ici';

  @override
  String get sharedLinksEmpty => 'Pas encore de liens ici';

  @override
  String get sharedVoiceEmpty => 'Pas encore de messages vocaux ici';

  @override
  String get sharedContentLocalOnly =>
      'Montre ce que cet appareil a téléchargé de la discussion — le serveur ne tient pas d\'index des médias partagés.';

  @override
  String get chatSettingsUnchanged => 'Rien n\'a encore changé';

  @override
  String get membersSearchHint => 'Rechercher des membres';

  @override
  String get membersSearchLoadedOnly =>
      'La recherche ne porte que sur les membres déjà chargés.';

  @override
  String membersSearchEmpty(String query) {
    return 'Personne ici ne correspond à « $query »';
  }

  @override
  String get membersLoadMore => 'Charger plus de personnes';

  @override
  String get membersSectionAdmins => 'Administration';

  @override
  String get membersSectionMembers => 'Membres';

  @override
  String get membersSectionBanned => 'Membres bannis';

  @override
  String get membersBannedHint =>
      'Les personnes bannies ne peuvent ni lire ni écrire ici tant que le bannissement dure.';

  @override
  String get membersEmptyTitle => 'Aucun membre à afficher';

  @override
  String get membersEmptyInvite =>
      'Ajoutez quelqu\'un pour lancer cette discussion.';

  @override
  String get membersEmptyNoInvite =>
      'Seuls les membres ayant le droit d\'inviter peuvent ajouter des personnes ici.';

  @override
  String get chatRoleOwner => 'Propriétaire';

  @override
  String get chatRoleAdmin => 'Administrateur';

  @override
  String get chatRoleEditor => 'Éditeur';

  @override
  String get chatRoleDirect => 'Direct';

  @override
  String get chatRoleMember => 'Membre';

  @override
  String get chatRoleViewer => 'Lecteur';

  @override
  String get chatRoleUnknown => 'Rôle inconnu';

  @override
  String get memberMutedBadge => 'Muet';

  @override
  String get memberBannedBadge => 'Banni';

  @override
  String get memberOpenProfile => 'Ouvrir le profil';

  @override
  String get memberMessagePrivately => 'Écrire en privé';

  @override
  String memberKickConfirmTitle(String name) {
    return 'Exclure $name ?';
  }

  @override
  String get memberKickConfirmBody =>
      'Cette personne perd l\'accès à la discussion, mais pourra être rajoutée plus tard.';

  @override
  String memberRoleChanged(String name, String role) {
    return '$name est maintenant $role';
  }

  @override
  String memberKicked(String name) {
    return '$name a été exclu';
  }

  @override
  String memberBannedToast(String name) {
    return '$name a été banni';
  }

  @override
  String memberUnbanned(String name) {
    return 'Le bannissement de $name a été levé';
  }

  @override
  String get memberActionFailed => 'Cela n\'a pas abouti. Veuillez réessayer.';

  @override
  String get roleAssignHint =>
      'Vous ne pouvez attribuer que des rôles inférieurs au vôtre.';

  @override
  String get roleOwnerTransferHint =>
      'Propriétaire ne figure pas dans la liste : l\'API ne permet pas de céder une discussion.';

  @override
  String get banForHour => 'Pour une heure';

  @override
  String get banForDay => 'Pour une journée';

  @override
  String get banForWeek => 'Pour une semaine';

  @override
  String get inviteMembersTitle => 'Ajouter des personnes';

  @override
  String get inviteRoleLabel => 'Rejoignent en tant que';

  @override
  String inviteRoomLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Place pour $count personnes de plus',
      one: 'Place pour 1 personne de plus',
      zero: 'Cette discussion est pleine',
    );
    return '$_temp0';
  }

  @override
  String inviteChatFull(int limit) {
    return 'Cette discussion contient $limit membres et elle est pleine.';
  }

  @override
  String inviteAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count personnes',
      one: 'Ajouter 1 personne',
    );
    return '$_temp0';
  }

  @override
  String inviteAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes ajoutées',
      one: '1 personne ajoutée',
    );
    return '$_temp0';
  }

  @override
  String inviteFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes n\'ont pas pu être ajoutées',
      one: '1 personne n\'a pas pu être ajoutée',
    );
    return '$_temp0';
  }

  @override
  String get inviteSearchStart =>
      'Trouvez des personnes par nom ou @username, puis ajoutez-les toutes d\'un coup.';

  @override
  String get inviteSelectionFull =>
      'C\'est tout ce que cette discussion peut accueillir.';

  @override
  String peopleSearchNoneFound(String query) {
    return 'Personne trouvé pour « $query »';
  }

  @override
  String get peopleSearchHint =>
      'La recherche porte sur n\'importe quelle partie d\'un nom ou d\'un @username.';

  @override
  String get profileShareAction => 'Partager';

  @override
  String get profileShareCopied => 'Lien du profil copié';

  @override
  String get profileBirthday => 'Anniversaire';

  @override
  String get profileEmptyTitle => 'Rien ici pour l\'instant';

  @override
  String get profileEmptyHintSelf =>
      'Écrivez quelques mots sur vous, pour que l\'on sache à qui l\'on parle.';

  @override
  String get profileEmptyHintOther =>
      'Cette personne n\'a pas rempli son profil.';

  @override
  String get profileAccount => 'Compte';

  @override
  String get profileAccountNoEmail => 'Connecté';

  @override
  String get profilePhoto => 'Photo';

  @override
  String get profileNoPhoto => 'Pas encore de photo';

  @override
  String get profileOpenLinkFailed => 'Impossible d\'ouvrir ce lien';

  @override
  String get profileContactCopied => 'Copié dans le presse-papiers';

  @override
  String get profileCopyAction => 'Copier';

  @override
  String devicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appareils',
      one: '1 appareil',
      zero: 'Aucun appareil',
    );
    return '$_temp0';
  }

  @override
  String get changePhoto => 'Changer la photo';

  @override
  String get setPhoto => 'Choisir une photo';

  @override
  String get choosePhoto => 'Choisir une photo';

  @override
  String get avatarCropTitle => 'Déplacer et agrandir';

  @override
  String get avatarCropHint =>
      'Faites glisser pour déplacer, pincez pour zoomer.';

  @override
  String get avatarCropConfirm => 'Utiliser la photo';

  @override
  String get avatarStagePreparing => 'Préparation…';

  @override
  String get avatarStageUploading => 'Envoi…';

  @override
  String get avatarStageConfirming => 'Presque fini…';

  @override
  String get avatarStageProcessing => 'Traitement de la photo…';

  @override
  String get avatarStageDone => 'Photo mise à jour';

  @override
  String get avatarProcessingFailed => 'Impossible de mettre la photo à jour';

  @override
  String get avatarProcessingFailedHint =>
      'Le serveur n\'a pas accepté cette image. Essayez-en une autre.';

  @override
  String get avatarNotAnImage => 'Ce fichier n\'est pas une image';

  @override
  String get avatarTooLarge =>
      'Cette image est trop grande. Choisissez-en une plus petite.';

  @override
  String get avatarUnreadable => 'Impossible d\'ouvrir cette image';

  @override
  String get profileEditDetails => 'Informations';

  @override
  String get profileEditLinks => 'Liens';

  @override
  String get profileEditLinksHint =>
      'Les liens sont enregistrés dès que vous en ajoutez ou en retirez un, indépendamment du formulaire ci-dessous.';

  @override
  String get profileNoLinks => 'Pas encore de liens';

  @override
  String get removeLink => 'Retirer le lien';

  @override
  String get clearDateOfBirth => 'Effacer la date de naissance';

  @override
  String get specializationHint => 'Ce que vous faites, en quelques mots';

  @override
  String bioCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String get profileSkillsHint => 'Jusqu\'à 30 caractères chacun';

  @override
  String get profileSaved => 'Profil enregistré';

  @override
  String get discardChangesTitle => 'Abandonner les modifications ?';

  @override
  String get discardChangesMessage =>
      'Vos modifications de ce profil seront perdues.';

  @override
  String get discardAction => 'Abandonner';

  @override
  String get keepEditingAction => 'Continuer à modifier';

  @override
  String get camera => 'Appareil photo';

  @override
  String get loading => 'Chargement…';

  @override
  String fieldTooLong(int max) {
    return '$max caractères au maximum';
  }

  @override
  String skillTooLong(String skill, int max) {
    return '« $skill » dépasse $max caractères';
  }

  @override
  String callRoomName(String slug) {
    return 'Salon $slug';
  }

  @override
  String get callJoinExplanation =>
      'Ici un appel est un salon : rejoignez-le, et n\'importe qui d\'autre dans cette discussion pourra vous y retrouver.';

  @override
  String get callNoIncomingNotice =>
      'La sonnerie des appels entrants n\'existe pas encore — le serveur ne les annonce pas.';

  @override
  String get callWaitingForOthers => 'En attente de quelqu\'un d\'autre…';

  @override
  String get callReconnecting => 'Reconnexion…';

  @override
  String get callYou => 'Vous';

  @override
  String callParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
      zero: 'Personne pour l\'instant',
    );
    return '$_temp0';
  }

  @override
  String get callMicrophoneMute => 'Couper le micro';

  @override
  String get callMicrophoneUnmute => 'Réactiver le micro';

  @override
  String get callCameraStart => 'Activer la vidéo';

  @override
  String get callCameraStop => 'Arrêter la vidéo';

  @override
  String get callSpeakerOn => 'Haut-parleur';

  @override
  String get callSpeakerOff => 'Écouteur';

  @override
  String get callLayoutGrid => 'Grille';

  @override
  String get callLayoutSpeaker => 'Vue de l\'intervenant';

  @override
  String callPinParticipant(String name) {
    return 'Épingler $name';
  }

  @override
  String callUnpinParticipant(String name) {
    return 'Détacher $name';
  }

  @override
  String get callMuteForEveryone => 'Couper pour tout le monde';

  @override
  String get callUnmuteForEveryone => 'Laisser parler';

  @override
  String get callQualityExcellent => 'Excellente connexion';

  @override
  String get callQualityGood => 'Bonne connexion';

  @override
  String get callQualityPoor => 'Connexion faible';

  @override
  String get callQualityLost => 'Connexion perdue';

  @override
  String get callMicrophonePermissionTitle =>
      'Autorisez ChatiX à utiliser le micro';

  @override
  String get callMicrophonePermissionBody =>
      'Les autres ne vous entendront que si ChatiX peut utiliser le micro. Vous pouvez vous couper à tout moment.';

  @override
  String get callCameraPermissionTitle =>
      'Autorisez ChatiX à utiliser la caméra';

  @override
  String get callCameraPermissionBody =>
      'Votre vidéo n\'est envoyée que tant que la caméra est allumée, et vous pouvez l\'éteindre à tout moment.';

  @override
  String get callPermissionContinue => 'Continuer';

  @override
  String get callPermissionNotNow => 'Pas maintenant';

  @override
  String get callPermissionOpenSettings => 'Ouvrir les réglages';

  @override
  String get callMicrophoneBlocked =>
      'Micro éteint : ChatiX n\'a pas l\'autorisation.';

  @override
  String get callCameraBlocked =>
      'Caméra éteinte : ChatiX n\'a pas l\'autorisation.';

  @override
  String get callSelfPreview => 'Votre caméra';

  @override
  String get callSelfPreviewHint => 'Faites glisser pour déplacer';

  @override
  String get callShowControls => 'Afficher les commandes d\'appel';

  @override
  String get callOngoingInChat => 'Vous êtes dans un appel de cette discussion';

  @override
  String get callReturn => 'Revenir';

  @override
  String callMiniPlayerLabel(String name) {
    return 'Appel avec $name';
  }

  @override
  String get callMinimize => 'Réduire l\'appel';

  @override
  String get callDismiss => 'Fermer';

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

  @override
  String get appearanceTitle => 'Apparence';

  @override
  String get appearanceHint => 'Thème, accent, fond, bulles et médias';

  @override
  String get appearancePreview => 'Aperçu';

  @override
  String get previewIncomingMessage =>
      'Tout ici est dessiné à partir de votre couleur d\'accent.';

  @override
  String get previewOutgoingMessage => 'Aucune image de fond. Juste du code.';

  @override
  String get previewIncomingReply => 'Déplacez les curseurs et regardez.';

  @override
  String get amoledTitle => 'Noir (AMOLED)';

  @override
  String get amoledHint =>
      'Fonds vraiment noirs. Sur un écran OLED, les pixels noirs ne consomment rien.';

  @override
  String get accentFromAvatar => 'Prendre la couleur de ma photo';

  @override
  String get accentFromAvatarApplied => 'Accent repris de votre photo.';

  @override
  String get accentFromAvatarEmpty =>
      'Votre photo n\'a aucune couleur à reprendre : elle paraît grise.';

  @override
  String get accentFromAvatarMissing => 'Ajoutez d\'abord une photo de profil.';

  @override
  String get accentFromAvatarFailed =>
      'Impossible de lire votre photo. Réessayez.';

  @override
  String get accentCustom => 'Votre couleur';

  @override
  String get wallpaperNebula => 'Nébuleuse';

  @override
  String get wallpaperRibbons => 'Rubans';

  @override
  String get wallpaperPrism => 'Prisme';

  @override
  String get wallpaperHalo => 'Halo';

  @override
  String get wallpaperDunes => 'Dunes';

  @override
  String get wallpaperIntensity => 'Intensité';

  @override
  String get wallpaperPattern => 'Motif';

  @override
  String get appearanceDensity => 'Densité';

  @override
  String get appearanceDensityHint =>
      'L\'espace que prennent les lignes et les bulles.';

  @override
  String get textSizeHint => 'S\'ajoute à la taille de texte du système.';

  @override
  String get bubbleShape => 'Forme des bulles';

  @override
  String get bubbleCorners => 'Coins';

  @override
  String get bubbleAnchor => 'Coin d\'ancrage';

  @override
  String get bubbleAnchorHint =>
      'Resserre le coin du côté de l\'expéditeur, pour que la bulle le désigne.';

  @override
  String get mediaSectionTitle => 'Médias';

  @override
  String get autoDownload => 'Téléchargement automatique';

  @override
  String get autoDownloadHint =>
      'Quelles pièces jointes sont récupérées avant que vous ne les ouvriez.';

  @override
  String get autoDownloadPhotos => 'Photos';

  @override
  String get autoDownloadVideos => 'Vidéos';

  @override
  String get autoDownloadFiles => 'Fichiers';

  @override
  String get autoDownloadVoice => 'Messages vocaux';

  @override
  String get autoDownloadWifi => 'Wi-Fi';

  @override
  String get autoDownloadMobile => 'Données mobiles';

  @override
  String get autoDownloadNever => 'Jamais';

  @override
  String get cacheLimit => 'Limite du cache';

  @override
  String get cacheLimitHint =>
      'Les pièces jointes téléchargées sont conservées jusqu\'à cette limite, puis les plus anciennes partent en premier.';

  @override
  String get cacheEmpty => 'Rien en cache pour l\'instant';

  @override
  String get cacheClear => 'Vider le cache';

  @override
  String get cacheMeasuring => 'Calcul en cours…';

  @override
  String get appearanceReduceMotionNotice =>
      'Votre système demande moins d\'animations : rien ne bouge ici.';

  @override
  String get appearanceHighContrastNotice =>
      'Le contraste élevé est activé : les fonds sont peints discrètement pour garder le texte lisible.';

  @override
  String cacheInUse(String size) {
    return '$size utilisés';
  }

  @override
  String cacheCleared(String size) {
    return '$size libérés';
  }

  @override
  String sizeMegabytes(String value) {
    return '$value Mo';
  }

  @override
  String sizeGigabytes(String value) {
    return '$value Go';
  }

  @override
  String get attachmentTapToDownload => 'Appuyez pour télécharger';

  @override
  String get welcomeHeadline => 'Bienvenue sur ChatiX';

  @override
  String get welcomeTagline => 'Des messages qui suivent votre rythme.';

  @override
  String get welcomeGetStarted => 'Commencer';

  @override
  String get welcomeSignIn => 'J’ai déjà un compte';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingDone => 'Créer un compte';

  @override
  String get onboardingRealtimeTitle => 'Tout en temps réel';

  @override
  String get onboardingRealtimeBody =>
      'Les messages, les modifications et les réactions arrivent à l’instant où ils se produisent — et l’app s’ouvre sur la conversation que vous aviez laissée, avant même que le réseau réponde.';

  @override
  String get onboardingTogetherTitle => 'Discussions, groupes, canaux, appels';

  @override
  String get onboardingTogetherBody =>
      'En tête-à-tête, dans un groupe de cinq cents personnes ou dans un canal ouvert à tous — avec un appel audio ou vidéo toujours à portée de doigt.';

  @override
  String get onboardingPrivacyTitle => 'Rien qu’à vous';

  @override
  String get onboardingPrivacyBody =>
      'Voyez chaque appareil connecté et déconnectez-le, verrouillez l’app derrière votre empreinte, et gardez vos fichiers sur le téléphone tant que vous ne les envoyez pas.';

  @override
  String onboardingPageOf(int current, int total) {
    return 'Page $current sur $total';
  }

  @override
  String get loginHeadline => 'Content de vous revoir';

  @override
  String get loginSubtitle => 'Connectez-vous pour reprendre la conversation.';

  @override
  String get registerHeadline => 'Créez votre compte';

  @override
  String get registerSubtitle => 'Cela prend environ une minute.';

  @override
  String get authOrContinueWith => 'ou continuer avec';

  @override
  String get authNoAccount => 'Pas encore de compte ?';

  @override
  String get authHaveAccount => 'Vous avez déjà un compte ?';

  @override
  String get authErrorWrongLoginData =>
      'Nom d’utilisateur ou mot de passe incorrect.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirmez votre adresse e-mail avant de vous connecter.';

  @override
  String authErrorEmailNotConfirmedFor(String email) {
    return 'Confirmez $email avant de vous connecter.';
  }

  @override
  String get authResendEmail => 'Renvoyer l’e-mail';

  @override
  String get authErrorTooManyAttempts =>
      'Trop de tentatives. Attendez une minute et réessayez.';

  @override
  String get authErrorDuplicateUsername =>
      'Ce nom d’utilisateur est déjà pris.';

  @override
  String get authErrorDuplicateEmail =>
      'Un compte existe déjà avec cette adresse e-mail.';

  @override
  String authErrorDuplicateField(String field) {
    return '$field est déjà utilisé.';
  }

  @override
  String get authErrorPasswordMismatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get authErrorInvalidCode =>
      'Ce code n’est plus valable. Demandez-en un nouveau.';

  @override
  String get authErrorUserNotFound =>
      'Nous n’avons trouvé aucun compte avec ces informations.';

  @override
  String get authErrorOffline =>
      'Pas de connexion. Vérifiez votre réseau et réessayez.';

  @override
  String get authErrorGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get passwordStrengthLabel => 'Robustesse du mot de passe';

  @override
  String get passwordStrengthWeak => 'Faible';

  @override
  String get passwordStrengthFair => 'Moyenne';

  @override
  String get passwordStrengthGood => 'Bonne';

  @override
  String get passwordStrengthStrong => 'Forte';

  @override
  String get passwordShow => 'Afficher le mot de passe';

  @override
  String get passwordHide => 'Masquer le mot de passe';

  @override
  String get verifyEmailHeadline => 'Regardez vos e-mails';

  @override
  String verifyEmailSentTo(String email) {
    return 'Nous avons envoyé un code de confirmation à $email.';
  }

  @override
  String get verifyEmailSentToYou =>
      'Nous vous avons envoyé un code de confirmation.';

  @override
  String get verifyEmailClipboardHint =>
      'Copiez le code depuis l’e-mail — ChatiX le reprend dès votre retour.';

  @override
  String get verifyEmailCodeFromClipboard => 'Code repris du presse-papiers';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'Nouvel e-mail possible dans $seconds s';
  }

  @override
  String get verifyEmailWrongAddress => 'Mauvaise adresse ?';

  @override
  String get verifyEmailChangeAddress => 'En utiliser une autre';

  @override
  String get biometricUnlockTitle => 'Déverrouiller par biométrie';

  @override
  String get biometricUnlockSubtitle =>
      'Demander l’empreinte ou le visage à chaque réouverture de ChatiX.';

  @override
  String get biometricUnlockUnavailable =>
      'Aucune biométrie n’est configurée sur cet appareil.';

  @override
  String get biometricUnlockReason => 'Déverrouiller ChatiX';

  @override
  String get biometricUnlockLockedTitle => 'ChatiX est verrouillé';

  @override
  String get biometricUnlockLockedBody =>
      'Déverrouillez pour retrouver vos discussions.';

  @override
  String get biometricUnlockAction => 'Déverrouiller';

  @override
  String get biometricUnlockFailed => 'La vérification a échoué. Réessayez.';

  @override
  String get biometricUnlockLockedOut =>
      'Le système a bloqué la biométrie après trop de tentatives.';

  @override
  String get biometricUnlockNotEnrolled =>
      'Aucune empreinte ni aucun visage n’est enregistré sur cet appareil.';

  @override
  String get biometricUnlockEnableFailed =>
      'Impossible d’activer la biométrie.';

  @override
  String get settingsSecuritySection => 'Sécurité';

  @override
  String get settingsAccountSection => 'Compte';

  @override
  String get logoutConfirmTitle => 'Se déconnecter ?';

  @override
  String get logoutConfirmBody =>
      'Cet appareil oubliera vos messages, vos brouillons et vos fichiers téléchargés. Votre compte reste inchangé.';

  @override
  String get logoutAction => 'Se déconnecter';

  @override
  String get logoutFailed => 'La déconnexion a échoué. Réessayez.';

  @override
  String get logoutInProgress => 'Déconnexion…';

  @override
  String get appearanceFeel => 'Sensations';

  @override
  String get appearanceHaptics => 'Retour haptique';

  @override
  String get appearanceHapticsHint =>
      'De brèves vibrations quand un message part, qu\'une réaction arrive ou qu\'un geste aboutit. Le réglage de vibration de votre appareil reste prioritaire.';

  @override
  String get failureGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get failureRateLimited =>
      'Trop de tentatives. Patientez une minute et réessayez.';

  @override
  String get failureNoConnection =>
      'Pas de connexion internet. Vérifiez votre réseau et réessayez.';

  @override
  String get failureTimeout =>
      'Le serveur a mis trop de temps à répondre. Veuillez réessayer.';

  @override
  String get failureInsecureSessionCookie =>
      'Le serveur a envoyé un cookie de connexion non sécurisé, la session n’a donc pas été enregistrée. C’est un réglage du serveur : contactez le support.';

  @override
  String get apiErrorSessionEnded =>
      'Votre session est terminée. Reconnectez-vous.';

  @override
  String get apiErrorSessionExpired =>
      'Votre session a expiré. Reconnectez-vous.';

  @override
  String get apiErrorSessionInvalid =>
      'Votre session n\'est plus valide. Reconnectez-vous.';

  @override
  String get apiErrorSessionSignedOut =>
      'Cette session a été fermée. Reconnectez-vous.';

  @override
  String get apiErrorAccessDenied =>
      'Vous n\'avez pas l\'autorisation de faire cela.';

  @override
  String get apiErrorValidation =>
      'Certaines informations sont invalides. Vérifiez-les et réessayez.';

  @override
  String get apiErrorNotFoundGeneric =>
      'Introuvable — cela a peut-être été supprimé.';

  @override
  String get apiErrorTooLongGeneric =>
      'Cette valeur est trop longue. Raccourcissez-la.';

  @override
  String get apiErrorLimitExceededGeneric =>
      'Une limite est atteinte, cette action n\'est donc pas disponible.';

  @override
  String get apiErrorWrongLoginData =>
      'Nom d\'utilisateur ou mot de passe incorrect.';

  @override
  String get apiErrorPasswordMismatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get apiErrorDuplicateUser =>
      'Ce nom d\'utilisateur ou cet e-mail est déjà pris.';

  @override
  String get apiErrorEmailNotConfirmed =>
      'Confirmez votre adresse e-mail avant de vous connecter.';

  @override
  String get apiErrorOauthProviderUnsupported =>
      'Ce fournisseur de connexion n\'est pas pris en charge.';

  @override
  String get apiErrorOauthStateNotFound =>
      'La tentative de connexion a expiré. Réessayez.';

  @override
  String get apiErrorOauthLinkedAnotherUser =>
      'Ce compte est déjà lié à un autre utilisateur.';

  @override
  String get apiErrorProfileExists => 'Vous avez déjà un profil.';

  @override
  String get apiErrorNotChatMember =>
      'Vous n\'êtes pas membre de cette discussion.';

  @override
  String get apiErrorAlreadyChatMember =>
      'Cette personne est déjà dans cette discussion.';

  @override
  String get apiErrorInvalidChatRole =>
      'Ce rôle de discussion n\'est pas valide.';

  @override
  String get apiErrorDirectChatExists =>
      'Vous avez déjà une discussion directe avec cette personne.';

  @override
  String get apiErrorMessageTooLong =>
      'Ce message est trop long. Raccourcissez-le.';

  @override
  String get apiErrorInvalidMessage =>
      'Ce message ne peut pas être envoyé tel quel.';

  @override
  String get apiErrorSlowModeLimit =>
      'Le mode lent est actif — patientez avant d\'envoyer un autre message.';

  @override
  String get apiErrorSlowModeOutOfRange =>
      'Le mode lent doit être compris entre 0 seconde et 24 heures.';

  @override
  String get apiErrorAttachmentLimitExceeded =>
      'Trop de pièces jointes pour un seul message.';

  @override
  String get apiErrorAttachmentNotFound =>
      'Cette pièce jointe n\'est plus disponible.';

  @override
  String get apiErrorAttachmentValidation =>
      'Ce fichier ne peut pas être joint — vérifiez son type et sa taille.';

  @override
  String get apiErrorEmptyAttachmentUpload =>
      'Choisissez un fichier à joindre.';

  @override
  String get apiErrorInvalidUploadToken =>
      'Le téléversement a expiré. Joignez à nouveau le fichier.';

  @override
  String get apiErrorAvatarNotImage => 'Un avatar doit être un fichier image.';

  @override
  String get apiErrorActiveCallExists =>
      'Un appel est déjà en cours dans cette discussion.';

  @override
  String get apiErrorNoActiveCall =>
      'Aucun appel n\'est en cours dans cette discussion.';

  @override
  String get apiErrorLivekitUnauthorized =>
      'Vous ne pouvez pas rejoindre cet appel.';

  @override
  String get apiErrorLivekitError =>
      'Le service d\'appel est indisponible pour le moment.';

  @override
  String get apiErrorInvalidReaction =>
      'Cet emoji ne peut pas servir de réaction.';

  @override
  String get apiErrorReactionNotAllowed =>
      'Cette réaction n\'est pas autorisée dans cette discussion.';

  @override
  String get apiErrorReactionsDisabled =>
      'Les réactions sont désactivées dans cette discussion.';

  @override
  String get apiErrorTooManyReactions =>
      'Impossible d\'ajouter plus de réactions ici.';

  @override
  String get apiErrorMaxLimitCursor =>
      'Trop de discussions ont été reprises à la fois.';

  @override
  String a11yMessageFrom(String author, String time) {
    return 'Message de $author, $time';
  }

  @override
  String a11yMessageMine(String time) {
    return 'Votre message, $time';
  }

  @override
  String get a11ySystemMessage => 'Message système';

  @override
  String a11yReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réactions',
      one: '1 réaction',
    );
    return '$_temp0';
  }

  @override
  String get a11yReactionYours => 'dont la vôtre';

  @override
  String get a11yMessageActionsHint => 'afficher les actions du message';

  @override
  String a11yMessageAttachmentsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces jointes',
      one: '1 pièce jointe',
    );
    return '$_temp0';
  }

  @override
  String get reviewPromptTitle => 'L\'application vous plaît ?';

  @override
  String get reviewPromptBody =>
      'Souhaitez-vous nous faire part de votre avis ?';

  @override
  String get reviewPromptDecline => 'Non merci';

  @override
  String get reviewPromptAccept => 'Bien sûr';

  @override
  String get feedbackTitle => 'Votre avis compte';

  @override
  String get feedbackBody =>
      'Dites-nous ce que vous pensez de l\'application. Si elle vous plaît, un avis sur la boutique nous aiderait beaucoup.';

  @override
  String get feedbackHint => 'Saisissez votre avis ici';

  @override
  String get feedbackSubmit => 'Envoyer';

  @override
  String get updateRequiredTitle => 'Mise à jour requise';

  @override
  String get updateAvailableTitle => 'Mise à jour disponible';

  @override
  String updateRequiredBody(String version) {
    return 'La version $version est requise pour continuer à utiliser ChatiX.';
  }

  @override
  String updateAvailableBody(String version) {
    return 'La version $version est disponible.';
  }

  @override
  String get updateWhatsNew => 'Nouveautés';

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateNow => 'Mettre à jour maintenant';

  @override
  String get updateAction => 'Mettre à jour';

  @override
  String sizeBytes(String value) {
    return '$value o';
  }

  @override
  String sizeKilobytes(String value) {
    return '$value Ko';
  }

  @override
  String attachmentDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get attachmentDownload => 'Télécharger';

  @override
  String get attachmentDownloadFailed => 'Impossible de télécharger le fichier';

  @override
  String get attachmentShareFailed => 'Impossible de partager le fichier';

  @override
  String get attachmentRevealFailed => 'Impossible d’ouvrir le dossier';

  @override
  String get messageSaveFile => 'Enregistrer';

  @override
  String get messageShareFile => 'Partager';

  @override
  String get messageShowInFolder => 'Afficher dans le dossier';

  @override
  String get bubbleFill => 'Vos bulles';

  @override
  String get bubbleFillGradient => 'Dégradé';

  @override
  String get bubbleFillSolid => 'Couleur unie';

  @override
  String get deleteMessageTitle => 'Supprimer le message ?';

  @override
  String get deleteMessageForEveryone =>
      'Il disparaîtra pour tous les participants.';

  @override
  String get deleteMessagesForEveryone =>
      'Ils disparaîtront pour tous les participants.';

  @override
  String get messageDeleteFailed => 'Impossible de supprimer le message.';

  @override
  String get validationLoginIdentifierRequired =>
      'Saisissez votre e-mail ou nom d\'utilisateur';

  @override
  String get validationUsernameRequired => 'Saisissez un nom d\'utilisateur';

  @override
  String validationMinLength(int min) {
    String _temp0 = intl.Intl.pluralLogic(
      min,
      locale: localeName,
      other: 'Au moins $min caractères',
      one: 'Au moins $min caractère',
    );
    return '$_temp0';
  }

  @override
  String get validationUsernameCharacters =>
      'Seuls les lettres latines, les chiffres, les espaces et , . \' - sont autorisés';

  @override
  String get validationEmailRequired => 'Saisissez votre e-mail';

  @override
  String get validationEmailInvalid => 'Saisissez une adresse e-mail valide';

  @override
  String get validationPasswordRequired => 'Saisissez un mot de passe';

  @override
  String get validationPasswordUppercase => 'Ajoutez au moins une majuscule';

  @override
  String get validationPasswordLowercase => 'Ajoutez au moins une minuscule';

  @override
  String get validationPasswordDigit => 'Ajoutez au moins un chiffre';

  @override
  String validationPasswordSpecial(String characters) {
    return 'Ajoutez au moins un caractère spécial : $characters';
  }

  @override
  String get validationPasswordRepeatRequired => 'Répétez votre mot de passe';

  @override
  String get validationPasswordsDoNotMatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get validationFieldRequired => 'Ce champ est obligatoire';

  @override
  String get resetPasswordRequestIntro =>
      'Saisissez l’e-mail de votre compte et nous vous enverrons un code pour réinitialiser votre mot de passe.';

  @override
  String get resetPasswordConfirmIntro =>
      'Saisissez le code reçu par e-mail et un nouveau mot de passe.';

  @override
  String get createChatDirectSearchLabel => 'À qui voulez-vous écrire ?';

  @override
  String get addPeopleSearchLabel => 'Ajoutez des personnes par nom ou @pseudo';

  @override
  String get createChatDirectHelper =>
      'Choisissez une personne : une discussion privée compte exactement deux membres';

  @override
  String createChatMembersHelper(int max) {
    return 'Jusqu’à $max personnes maintenant ; vous pourrez en ajouter plus tard';
  }

  @override
  String get createChatDirectNeedsPeer =>
      'Une discussion privée nécessite exactement une autre personne : cherchez-la par nom ou @pseudo';

  @override
  String createChatDirectTooMany(int count) {
    return 'Une discussion privée n’a qu’une autre personne, mais $count sont sélectionnées : choisissez Groupe';
  }

  @override
  String get createChatNameRequired => 'Donnez un nom à la discussion';

  @override
  String createChatTooManyMembers(int max) {
    return 'Vous pouvez ajouter jusqu’à $max personnes maintenant ; ajoutez les autres une fois la discussion créée';
  }

  @override
  String get createChatFailed => 'Impossible de créer la discussion';

  @override
  String get settingsRowHint => 'Notifications, apparence, confidentialité';

  @override
  String profileBirthdayWithAge(String date, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age ans',
      one: '$age an',
    );
    return '$date ($_temp0)';
  }
}
