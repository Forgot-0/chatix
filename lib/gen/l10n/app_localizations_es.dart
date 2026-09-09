// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Flutter Riverpod Arquitectura Limpia';

  @override
  String get welcomeMessage =>
      'Bienvenido a Flutter Riverpod Arquitectura Limpia';

  @override
  String get home => 'Inicio';

  @override
  String get settings => 'Configuraciones';

  @override
  String get profile => 'Perfil';

  @override
  String get darkMode => 'Modo Oscuro';

  @override
  String get lightMode => 'Modo Claro';

  @override
  String get systemMode => 'Modo Sistema';

  @override
  String get language => 'Idioma';

  @override
  String get change_language => 'Cambiar idioma';

  @override
  String get theme => 'Tema';

  @override
  String get change_theme => 'Cambiar tema';

  @override
  String get notifications => 'Notificaciones';

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
  String get logout => 'Cerrar Sesión';

  @override
  String get login => 'Iniciar Sesión';

  @override
  String get email => 'Correo Electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get signIn => 'Iniciar Sesión';

  @override
  String get register => 'Registrarse';

  @override
  String get forgotPassword => '¿Olvidó su Contraseña?';

  @override
  String get errorOccurred => 'Ocurrió un error';

  @override
  String get tryAgain => 'Intentar de nuevo';

  @override
  String greeting(String name) {
    return '¡Hola, $name!';
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
      other: '$countString elementos',
      one: '1 elemento',
      zero: 'No hay elementos',
    );
    return '$_temp0';
  }

  @override
  String lastUpdated(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Última actualización: $dateString';
  }

  @override
  String get browsePeople => 'Personas';

  @override
  String get chatDirect => 'Chat directo';

  @override
  String get chatGroup => 'Grupo';

  @override
  String get chatSupergroup => 'Supergrupo';

  @override
  String get chatChannel => 'Canal';

  @override
  String get chatFallbackTitle => 'Chat';

  @override
  String membersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
      zero: 'Sin miembros',
    );
    return '$_temp0';
  }

  @override
  String get attachmentProcessing => 'Procesando…';

  @override
  String get attachmentFailed => 'Error al subir';

  @override
  String get attachmentOpenFailed => 'No se pudo abrir este archivo';

  @override
  String get imageLoadFailed => 'Imagen no disponible';

  @override
  String get close => 'Cerrar';

  @override
  String get addReaction => 'Añadir reacción';

  @override
  String get reactionsDisabled =>
      'Las reacciones están desactivadas en este chat';

  @override
  String reactionLimitReached(Object limit) {
    return 'Puedes añadir hasta $limit reacciones por mensaje';
  }

  @override
  String get messageNotFound => 'Ese mensaje ya no está disponible';

  @override
  String get chatInfo => 'Información del chat';

  @override
  String get chatName => 'Nombre';

  @override
  String get chatDescription => 'Descripción';

  @override
  String get chatPublic => 'Chat público';

  @override
  String get chatPublicHint => 'Cualquiera con el enlace puede unirse';

  @override
  String get chatAdminOnly => 'Solo administradores';

  @override
  String get chatAdminOnlyHint => 'Solo los administradores pueden publicar';

  @override
  String get chatSlowMode => 'Modo lento';

  @override
  String get chatSlowModeOff => 'Desactivado';

  @override
  String chatSlowModeSeconds(Object seconds) {
    return '${seconds}s entre mensajes';
  }

  @override
  String get chatReactionsMode => 'Reacciones';

  @override
  String get chatReactionsAll => 'Todos, cualquier emoji';

  @override
  String get chatReactionsSome => 'Solo emojis seleccionados';

  @override
  String get chatReactionsNone => 'Desactivadas';

  @override
  String get leaveChat => 'Salir del chat';

  @override
  String get leaveChatConfirm =>
      '¿Salir de este chat? Dejarás de recibir sus mensajes.';

  @override
  String get leaveChatOwnerBlocked =>
      'El creador del chat no puede salir: elimina el chat en su lugar.';

  @override
  String get deleteChat => 'Eliminar chat';

  @override
  String get deleteChatConfirm =>
      '¿Eliminar este chat para todos? No se puede deshacer.';

  @override
  String get saveChanges => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get chatSettingsSaved => 'Chat actualizado';

  @override
  String get viewMembers => 'Miembros';

  @override
  String get messageEdited => 'editado';

  @override
  String get messageReply => 'Responder';

  @override
  String get messageForward => 'Reenviar';

  @override
  String get messageEdit => 'Editar';

  @override
  String get messageDelete => 'Eliminar';

  @override
  String get messageSelect => 'Seleccionar';

  @override
  String get backToLatest => 'Volver a los mensajes recientes';

  @override
  String get messageRead => 'Leído';

  @override
  String get messageSent => 'Enviado';

  @override
  String get dateToday => 'Hoy';

  @override
  String get dateYesterday => 'Ayer';

  @override
  String get unreadMessages => 'Mensajes no leídos';

  @override
  String get noMessagesYet => 'Aún no hay mensajes';

  @override
  String get editingMessage => 'Editando mensaje';

  @override
  String get scrollToBottom => 'Ir a los mensajes más recientes';

  @override
  String get messageDensity => 'Densidad de mensajes';

  @override
  String get densityCompact => 'Compacta';

  @override
  String get densityCozy => 'Normal';

  @override
  String get densityComfortable => 'Amplia';

  @override
  String get voiceSlideToCancel =>
      'Desliza a la izquierda para cancelar, arriba para fijar';

  @override
  String get voiceReleaseToCancel => 'Suelta para cancelar';

  @override
  String get voiceRecordingLocked => 'Grabando: pulsa enviar cuando termines';

  @override
  String get voicePermissionDenied => 'El acceso al micrófono está desactivado';

  @override
  String get voiceMessage => 'Mensaje de voz';

  @override
  String get attach => 'Adjuntar';

  @override
  String get messageHint => 'Mensaje';

  @override
  String get unknownChat => 'Chat desconocido';

  @override
  String get unknownProfile => 'Perfil desconocido';

  @override
  String get goToChats => 'Ir a los chats';

  @override
  String get pageNotFound => 'Página no encontrada';

  @override
  String pathDoesNotExist(String path) {
    return '$path no existe';
  }

  @override
  String get retry => 'Reintentar';

  @override
  String get clear => 'Borrar';

  @override
  String get add => 'Añadir';

  @override
  String get save => 'Guardar';

  @override
  String get readAll => 'Marcar todo';

  @override
  String get filter => 'Filtrar';

  @override
  String get filterAll => 'Todas';

  @override
  String get filterUnread => 'Solo no leídas';

  @override
  String get filterRead => 'Solo leídas';

  @override
  String get showAll => 'Mostrar todas';

  @override
  String get notificationsLoadFailed =>
      'No se pudieron cargar tus notificaciones.';

  @override
  String get profiles => 'Personas';

  @override
  String get searchByName => 'Buscar por nombre';

  @override
  String get searchByUsername => 'Buscar por usuario';

  @override
  String get profilesLoadFailed => 'No se pudieron cargar los perfiles.';

  @override
  String get signInToViewProfile => 'Inicia sesión para ver tu perfil';

  @override
  String get signInToEditProfile => 'Inicia sesión para editar tu perfil';

  @override
  String get profileAbout => 'Acerca de';

  @override
  String get profileSkills => 'Habilidades';

  @override
  String get profileContacts => 'Contactos';

  @override
  String get sendMessageAction => 'Mensaje';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get displayName => 'Nombre visible';

  @override
  String get specialization => 'Especialización';

  @override
  String get bio => 'Biografía';

  @override
  String get dateOfBirth => 'Fecha de nacimiento';

  @override
  String get addContact => 'Añadir contacto';

  @override
  String get contactProvider => 'Proveedor (p. ej. telegram)';

  @override
  String get contactHandle => 'Contacto (p. ej. @usuario)';

  @override
  String get skillsHint => 'Escribe una habilidad y pulsa intro';

  @override
  String get photoLibraryFailed => 'No se pudo abrir la galería';

  @override
  String get chats => 'Chats';

  @override
  String get searchChatsAndPeople => 'Buscar chats y personas';

  @override
  String get chatsLoadFailed => 'No se pudieron cargar tus chats.';

  @override
  String get noChatsYet => 'Aún no hay chats';

  @override
  String get noChatsYetHint => 'Inicia una conversación y aparecerá aquí.';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get chatTypeDirect => 'Directo';

  @override
  String get chatTypeGroup => 'Grupo';

  @override
  String get chatTypeSuper => 'Súper';

  @override
  String get chatTypeChannel => 'Canal';

  @override
  String get chatPublicHintCreate =>
      'Cualquiera puede encontrar y unirse a este chat';

  @override
  String get chatSlowModeSecondsField => 'Modo lento (segundos)';

  @override
  String get createChat => 'Crear chat';

  @override
  String get membersTitle => 'Miembros';

  @override
  String get membersLoadFailed => 'No se pudieron cargar los miembros';

  @override
  String get addMember => 'Añadir miembro';

  @override
  String get changeRole => 'Cambiar rol';

  @override
  String get banMember => 'Bloquear';

  @override
  String get banMemberTitle => 'Bloquear miembro';

  @override
  String get kickMember => 'Expulsar';

  @override
  String get banReason => 'Motivo (opcional)';

  @override
  String get banUntil => 'Elegir fecha';

  @override
  String get searchPeople => 'Personas';

  @override
  String get noPeopleFound => 'No se encontraron personas';

  @override
  String get callConnecting => 'Conectando…';

  @override
  String get callJoin => 'Unirse a la llamada';

  @override
  String get callEnded => 'Llamada finalizada';

  @override
  String get callRejoin => 'Volver a unirse';

  @override
  String get callLeave => 'Salir';

  @override
  String get callTitle => 'Llamada';

  @override
  String selectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String deleteMessagesTitle(int count) {
    return '¿Eliminar $count mensajes?';
  }

  @override
  String get cannotBeUndone => 'Esta acción no se puede deshacer.';

  @override
  String get chatLoadFailed => 'No se pudo cargar el chat';

  @override
  String get attachMedia => 'Fotos y vídeos';

  @override
  String get attachDocument => 'Documento';

  @override
  String get messageForwarded => 'Mensaje reenviado';

  @override
  String get forwardTo => 'Reenviar a';

  @override
  String get noOtherChats => 'No hay otros chats';

  @override
  String get chatsLoadFailedShort => 'No se pudieron cargar los chats';

  @override
  String get discard => 'Descartar';

  @override
  String get reactedTitle => 'Reaccionaron';

  @override
  String get noReactionsYet => 'Nadie ha reaccionado con esto todavía';

  @override
  String get showMore => 'Mostrar más';

  @override
  String get bulkForwarding => 'Reenviando';

  @override
  String get bulkDeleting => 'Eliminando';

  @override
  String bulkProgress(String label, int done, int total) {
    return '$label $done de $total…';
  }

  @override
  String bulkComplete(String label, int total) {
    return '$label completado ($total)';
  }

  @override
  String bulkPartial(int done, int total, int failed, String reason) {
    return '$done de $total correctos — $failed fallaron: $reason';
  }

  @override
  String get callTokenUnavailable => 'No se pudo iniciar la llamada';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get emailOrUsername => 'Correo o usuario';

  @override
  String get emailOrUsernameHint => 'tu@ejemplo.com o tu usuario';

  @override
  String get passwordHint => 'Introduce tu contraseña';

  @override
  String get logIn => 'Entrar';

  @override
  String get username => 'Usuario';

  @override
  String get usernameHint => '4-100 caracteres';

  @override
  String get emailHint => 'Introduce tu correo';

  @override
  String get passwordRule => '8+ caracteres, mayús./minús./dígito/especial';

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get confirmPasswordHint => 'Confirma tu contraseña';

  @override
  String get signInTitle => 'Iniciar sesión';

  @override
  String get backToSignIn => 'Volver a iniciar sesión';

  @override
  String get setNewPassword => 'Establecer nueva contraseña';

  @override
  String get resetCode => 'Código de restablecimiento';

  @override
  String get newPassword => 'Nueva contraseña';

  @override
  String get confirmNewPassword => 'Confirmar nueva contraseña';

  @override
  String get resetPassword => 'Restablecer contraseña';

  @override
  String get passwordUpdated => 'Contraseña actualizada: inicia sesión.';

  @override
  String get sendCode => 'Enviar código';

  @override
  String get haveCodeAlready => 'Ya tengo un código';

  @override
  String get resetCodeSent => 'Revisa tu correo para el código.';

  @override
  String get verifyEmailTitle => 'Verificar correo';

  @override
  String get verifyEmailHint => 'Pega el token del correo que te enviamos.';

  @override
  String get verificationToken => 'Token de verificación';

  @override
  String get verify => 'Verificar';

  @override
  String get resendLimitHint => 'Podemos reenviarlo: hasta 3 veces por hora.';

  @override
  String get resendVerification => 'Reenviar correo de verificación';

  @override
  String get emailVerified => 'Correo verificado';

  @override
  String get verificationSent =>
      'Correo de verificación enviado: revisa tu bandeja.';

  @override
  String get browserOpenFailed => 'No se pudo abrir el navegador';

  @override
  String continueWith(String provider) {
    return 'Continuar con $provider';
  }

  @override
  String get peopleSearchFailed => 'No se pudo buscar personas';

  @override
  String get startChatFailed => 'No se pudo iniciar un chat con esta persona';

  @override
  String get profileLoadFailed => 'No se pudo cargar este perfil';

  @override
  String get myProfileLoadFailed => 'No se pudo cargar tu perfil';

  @override
  String get saveChangesFailed => 'No se pudieron guardar los cambios';

  @override
  String get avatarUpdateFailed => 'No se pudo actualizar el avatar';

  @override
  String get oauthCancelled => 'Se canceló el inicio de sesión';

  @override
  String get oauthCancelledHint =>
      'No se cambió nada. Inténtalo de nuevo o usa tu usuario y contraseña.';

  @override
  String get oauthFailed => 'No se pudo completar el inicio de sesión';

  @override
  String get oauthFailedHint => 'Inicia sesión con tu usuario y contraseña.';

  @override
  String get realtimeRejected =>
      'Las actualizaciones en vivo están desactivadas en este chat';

  @override
  String get forwardComment => 'Añadir un comentario (opcional)';

  @override
  String get forwardAction => 'Reenviar';

  @override
  String get banDuration => 'Duración';

  @override
  String get banForever => 'Permanentemente';

  @override
  String get banUntilDate => 'Hasta una fecha';

  @override
  String get banLift => 'Levantar el bloqueo';

  @override
  String get banLiftHint =>
      'Envía una fecha pasada, que el servidor interpreta como desbloqueo';

  @override
  String get banPickDate => 'Elegir fecha';

  @override
  String get myDevices => 'Mis dispositivos';

  @override
  String get devicesLoadFailed => 'No se pudieron cargar tus dispositivos.';

  @override
  String get noDevices => 'No hay sesiones activas';

  @override
  String get deviceActive => 'Activa';

  @override
  String get deviceInactive => 'Sesión cerrada';

  @override
  String deviceLastActive(String date) {
    return 'Última actividad: $date';
  }

  @override
  String get designSystem => 'Sistema de diseño';

  @override
  String get accentColor => 'Color de acento';

  @override
  String get chatWallpaper => 'Fondo del chat';

  @override
  String get wallpaperAurora => 'Aurora';

  @override
  String get wallpaperMesh => 'Malla';

  @override
  String get wallpaperPlain => 'Liso';

  @override
  String get textSize => 'Tamaño del texto';

  @override
  String get textSizeSmall => 'Pequeño';

  @override
  String get textSizeDefault => 'Normal';

  @override
  String get textSizeLarge => 'Grande';

  @override
  String get textSizeExtraLarge => 'Muy grande';

  @override
  String get resetAppearance => 'Restablecer apariencia';

  @override
  String get showcaseAccents => 'Acentos';

  @override
  String get showcaseNeutrals => 'Neutros';

  @override
  String get showcaseNeutralsLight => 'Escala clara';

  @override
  String get showcaseNeutralsDark => 'Escala oscura';

  @override
  String get showcaseRadii => 'Radios';

  @override
  String get showcaseSpacing => 'Espaciado';

  @override
  String get showcaseElevation => 'Elevación';

  @override
  String get showcaseMotion => 'Movimiento';

  @override
  String get showcaseMotionFast => 'Rápido';

  @override
  String get showcaseMotionBase => 'Base';

  @override
  String get showcaseMotionSlow => 'Lento';

  @override
  String get showcaseMotionReplay => 'Repetir';

  @override
  String get showcaseTypography => 'Tipografía';

  @override
  String get showcaseTabularFigures => 'Cifras tabulares';

  @override
  String get showcaseBubbles => 'Burbujas de mensaje';

  @override
  String get showcaseReactions => 'Reacciones';

  @override
  String get showcaseAuthors => 'Acentos de autor';

  @override
  String get showcaseComponents => 'Componentes';

  @override
  String get showcaseIncomingSample =>
      'Entrante: superficie cálida, un filete.';

  @override
  String get showcaseStackedSample => 'Segundo mensaje de la misma serie.';

  @override
  String get showcaseOutgoingSample => 'Saliente: degradado de acento.';

  @override
  String get messageSending => 'Enviando';

  @override
  String get onlineNow => 'En línea';

  @override
  String userTyping(String name) {
    return '$name está escribiendo…';
  }

  @override
  String severalTyping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas están escribiendo…',
      one: '1 persona está escribiendo…',
    );
    return '$_temp0';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos adjuntos',
      one: '1 archivo adjunto',
    );
    return '$_temp0';
  }

  @override
  String get contacts => 'Contactos';

  @override
  String get profileSettingsHint => 'Tu nombre, avatar y datos de contacto';

  @override
  String get noChatSelected => 'Ningún chat seleccionado';

  @override
  String get noChatSelectedHint =>
      'Elige una conversación de la lista para empezar a leer.';

  @override
  String get newDirectChat => 'Nuevo chat directo';

  @override
  String get newGroup => 'Nuevo grupo';

  @override
  String get newChannel => 'Nuevo canal';

  @override
  String get quickActionsHint => 'Crear algo nuevo';

  @override
  String unreadMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes sin leer',
      one: '1 mensaje sin leer',
      zero: 'Sin mensajes sin leer',
    );
    return '$_temp0';
  }

  @override
  String unreadNotificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notificaciones nuevas',
      one: '1 notificación nueva',
      zero: 'Sin notificaciones nuevas',
    );
    return '$_temp0';
  }

  @override
  String get noContactsFound => 'Nadie coincide con ese nombre';

  @override
  String get noContactsFoundHint =>
      'Prueba con un nombre más corto o escrito de otra forma.';

  @override
  String get noContactsYet => 'Todavía no hay personas que mostrar';
}
