// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

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
  String get notification_settings => 'Configurar las notificaciones';

  @override
  String get localization_demo => 'Demo de localización';

  @override
  String get localization_demo_description => 'Ver la localización en acción';

  @override
  String get language_settings => 'Ajustes de idioma';

  @override
  String get select_your_language => 'Elige tu idioma';

  @override
  String get language_explanation =>
      'El idioma elegido se aplica a toda la aplicación';

  @override
  String get time => 'Hora';

  @override
  String get currency => 'Moneda';

  @override
  String get percent => 'Porcentaje';

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
  String get messageReact => 'Reaccionar';

  @override
  String get messageCopy => 'Copiar texto';

  @override
  String get messageCopied => 'Copiado';

  @override
  String get linkOpenFailed => 'Aquí no hay nada que pueda abrir ese enlace';

  @override
  String get messageDetails => 'Detalles';

  @override
  String replyingTo(String author) {
    return 'Respondiendo a $author';
  }

  @override
  String forwardedFrom(String author) {
    return 'Reenviado de $author';
  }

  @override
  String get forwardedMessage => 'Mensaje reenviado';

  @override
  String get detailsSentAt => 'Enviado';

  @override
  String get detailsAuthor => 'De';

  @override
  String get detailsSequence => 'Número en el chat';

  @override
  String get detailsEdited => 'Editado';

  @override
  String get detailsEditedYes => 'Sí';

  @override
  String get detailsDelivery => 'Entrega';

  @override
  String get detailsAttachments => 'Adjuntos';

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
  String newMessagesBelow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes nuevos abajo',
      one: '1 mensaje nuevo abajo',
      zero: 'No hay mensajes nuevos',
    );
    return '$_temp0';
  }

  @override
  String get connectionReconnecting => 'Reconectando…';

  @override
  String get connectionOffline => 'Sin conexión — desliza para actualizar';

  @override
  String get attachmentFallbackLabel => 'Adjunto';

  @override
  String get composerJoinToSend => 'Únete a este chat para escribir';

  @override
  String get composerBanned => 'Estás bloqueado en este chat';

  @override
  String get composerMuted => 'No puedes escribir en este chat';

  @override
  String get composerAdminsOnly =>
      'En este chat solo pueden escribir los administradores';

  @override
  String get composerNoPermission => 'No tienes permiso para escribir aquí';

  @override
  String attachmentSelection(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '1 archivo',
    );
    return '$_temp0, $size';
  }

  @override
  String get attachmentReady => 'Listo para enviar';

  @override
  String attachMediaLimits(int count, String size) {
    return 'Hasta $count, $size cada uno';
  }

  @override
  String attachDocumentLimits(String size) {
    return 'Un archivo, hasta $size';
  }

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
  String get voiceLimitReached => 'Duración máxima alcanzada';

  @override
  String get voicePermissionDenied => 'El acceso al micrófono está desactivado';

  @override
  String get voiceMessage => 'Mensaje de voz';

  @override
  String get voicePlay => 'Reproducir mensaje de voz';

  @override
  String get voicePause => 'Pausar mensaje de voz';

  @override
  String get voiceUnavailable => 'No disponible';

  @override
  String get voiceNotListened => 'Aún no escuchado';

  @override
  String voiceSpeedLabel(String speed) {
    return 'Velocidad de reproducción $speed';
  }

  @override
  String get voiceRecording => 'Grabando';

  @override
  String voiceTimeLeft(String time) {
    return 'Quedan $time';
  }

  @override
  String get voiceCancelRecording => 'Cancelar';

  @override
  String get voiceSendRecording => 'Enviar mensaje de voz';

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
  String get searchPeopleHint => 'Buscar por nombre o @usuario';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar $count mensajes?',
      one: '¿Eliminar $count mensaje?',
    );
    return '$_temp0';
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
  String get messageWaitingToSend => 'Esperando para enviar';

  @override
  String get messageNotSent => 'No enviado';

  @override
  String get connectionBusy => 'Conectando…';

  @override
  String get connectionWaitingForNetwork => 'Esperando red';

  @override
  String get wsDiagnostics => 'Diagnóstico de conexión';

  @override
  String wsDiagnosticsFrames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tramas registradas',
      one: '1 trama registrada',
      zero: 'Sin tramas registradas',
    );
    return '$_temp0';
  }

  @override
  String get wsDiagnosticsCopied => 'Diagnóstico copiado';

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

  @override
  String get previewYou => 'Tú';

  @override
  String get previewPhoto => 'Foto';

  @override
  String get previewVideo => 'Vídeo';

  @override
  String get previewVoice => 'Mensaje de voz';

  @override
  String get previewVideoNote => 'Videomensaje';

  @override
  String get previewFile => 'Archivo';

  @override
  String get previewNoText => 'Mensaje';

  @override
  String get draftLabel => 'Borrador:';

  @override
  String get markAsRead => 'Marcar como leído';

  @override
  String get archiveChat => 'Archivar';

  @override
  String get unarchiveChat => 'Desarchivar';

  @override
  String get pinChat => 'Fijar';

  @override
  String get unpinChat => 'No fijar';

  @override
  String get muteChat => 'Silenciar';

  @override
  String get unmuteChat => 'Activar sonido';

  @override
  String get archivedChats => 'Archivados';

  @override
  String get chatPinnedLabel => 'Fijado';

  @override
  String get chatMutedLabel => 'Notificaciones desactivadas';

  @override
  String get chatArchivedToast => 'Chat archivado';

  @override
  String get chatDeletedToast => 'Chat eliminado';

  @override
  String get undo => 'Deshacer';

  @override
  String get allChatsArchived => 'Todo está archivado';

  @override
  String previewVoiceWithDuration(String duration) {
    return 'Mensaje de voz $duration';
  }

  @override
  String archivedChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '1 chat',
    );
    return '$_temp0';
  }

  @override
  String get chatFolders => 'Carpetas';

  @override
  String get chatFoldersAll => 'Todos los chats';

  @override
  String get folderPresetUnread => 'Sin leer';

  @override
  String get folderPresetPersonal => 'Personales';

  @override
  String get folderPresetGroups => 'Grupos';

  @override
  String get folderPresetChannels => 'Canales';

  @override
  String get folderPresetNoReply => 'Esperan mi respuesta';

  @override
  String get newFolder => 'Nueva carpeta';

  @override
  String get editFolder => 'Editar carpeta';

  @override
  String get folderName => 'Nombre de la carpeta';

  @override
  String get folderIcon => 'Icono';

  @override
  String get folderRules => 'Reglas';

  @override
  String get folderMatchModeTitle => 'Un chat entra aquí cuando';

  @override
  String get folderMatchAll => 'cumple todas las reglas';

  @override
  String get folderMatchAny => 'cumple alguna regla';

  @override
  String get addFolderRule => 'Añadir regla';

  @override
  String get removeFolderRule => 'Quitar regla';

  @override
  String get folderRuleChatType => 'Tipo de chat';

  @override
  String folderRuleChatTypeIn(String types) {
    return 'El tipo es $types';
  }

  @override
  String get folderRuleUnread => 'Tiene mensajes sin leer';

  @override
  String get folderRuleRead => 'No tiene nada sin leer';

  @override
  String get folderRulePinned => 'Está fijado';

  @override
  String get folderRuleNotPinned => 'No está fijado';

  @override
  String get folderRuleNoReply => 'Espera mi respuesta';

  @override
  String folderRuleNoReplyDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Espera mi respuesta desde hace más de $days días',
      one: 'Espera mi respuesta desde hace más de 1 día',
      zero: 'Espera mi respuesta',
    );
    return '$_temp0';
  }

  @override
  String get folderRuleDaysLabel => 'Días sin respuesta mía';

  @override
  String get folderRuleDaysAny => 'Cualquiera';

  @override
  String get folderRuleMember => 'Incluye a una persona';

  @override
  String folderRuleMemberNamed(String name) {
    return 'Incluye a $name';
  }

  @override
  String get folderRulePickPerson => 'Elige una persona';

  @override
  String get folderRuleNoPeople =>
      'Las personas aparecen aquí en cuanto tienes chats con ellas';

  @override
  String get folderRuleMemberLocalNote =>
      'Usa lo que la lista de chats ya sabe: tú, las listas de miembros cargadas, quien escribió el último mensaje y quien creó el chat.';

  @override
  String get deleteFolder => 'Eliminar carpeta';

  @override
  String get deleteFolderConfirm =>
      '¿Eliminar esta carpeta? Los chats que contiene se quedan donde están.';

  @override
  String get folderNameRequired => 'Ponle un nombre a la carpeta';

  @override
  String folderNameTooLong(int count) {
    return 'Los nombres admiten como máximo $count caracteres';
  }

  @override
  String get folderRulesRequired => 'Añade al menos una regla';

  @override
  String folderLimitReached(int count) {
    return 'Puedes tener hasta $count carpetas';
  }

  @override
  String pinLimitReached(int count) {
    return 'Solo se pueden fijar $count chats. Suelta uno primero.';
  }

  @override
  String get foldersEmpty => 'Todavía no hay carpetas';

  @override
  String get foldersEmptyHint =>
      'Una carpeta es un conjunto de reglas, no una lista. Los chats entran y salen solos.';

  @override
  String get folderReadyMade => 'Listas para usar';

  @override
  String get folderYours => 'Tus carpetas';

  @override
  String folderRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas',
      one: '1 regla',
    );
    return '$_temp0';
  }

  @override
  String get folderEmptyChats => 'No hay nada en esta carpeta';

  @override
  String get folderEmptyChatsHint =>
      'Los chats aparecen aquí en cuanto cumplen sus reglas.';

  @override
  String get hideFolderTabs => 'Ocultar la tira de carpetas';

  @override
  String get hideFolderTabsHint =>
      'Conserva tus carpetas sin mostrar las pestañas sobre la lista';

  @override
  String get unarchiveOnNewMessage => 'Recuperar con un mensaje nuevo';

  @override
  String get unarchiveOnNewMessageHint =>
      'Un chat archivado vuelve a la lista cuando alguien escribe en él';

  @override
  String get organizerDeviceOnly =>
      'Las carpetas se guardan en este dispositivo y no siguen a tu cuenta. Los chats fijados, el archivo y los silenciados sí.';

  @override
  String get chatPinnedZone => 'Fijados';

  @override
  String get chatUnarchivedToast => 'De vuelta en la lista';

  @override
  String get searchTabMessages => 'Mensajes';

  @override
  String get searchEverything => 'Buscar chats, personas y mensajes';

  @override
  String get searchRecentQueries => 'Búsquedas recientes';

  @override
  String get searchRecentChats => 'Abiertos recientemente';

  @override
  String get searchClearHistory => 'Borrar';

  @override
  String get searchRemoveFromHistory => 'Quitar de las búsquedas recientes';

  @override
  String get searchStartTitle => 'Encuentra un chat, una persona o un mensaje';

  @override
  String get searchStartHint =>
      'Los chats por su nombre, las personas por su usuario, los mensajes por lo que dicen.';

  @override
  String get searchLoadedHistoryOnly =>
      'Se buscó en lo que hay en este dispositivo';

  @override
  String get searchLoadedHistoryExplained =>
      'No se pudo contactar con el servidor, así que se buscó en los mensajes que ya están en este dispositivo.';

  @override
  String get noChatsFound => 'No se encontraron chats';

  @override
  String get noChatsFoundHint =>
      'Los chats se buscan por nombre y descripción, entre los ya cargados.';

  @override
  String get noPeopleFoundHint =>
      'Prueba con otra forma de escribirlo o busca por nombre de usuario.';

  @override
  String get noMessagesFound => 'No se encontraron mensajes';

  @override
  String get messageSearchFailed => 'No se pudieron buscar los mensajes';

  @override
  String get searchInChat => 'Buscar en este chat';

  @override
  String searchMatchPosition(int current, int total) {
    return '$current de $total';
  }

  @override
  String get searchNoMatches => 'Sin coincidencias';

  @override
  String get searchOlderMatch => 'Coincidencia anterior';

  @override
  String get searchNewerMatch => 'Coincidencia siguiente';

  @override
  String get searchInChatHint => 'Buscar en este chat';

  @override
  String get searchChatDescriptionMatch => 'Coincide en la descripción';

  @override
  String get searchOpenChat => 'Abrir chat';

  @override
  String get reactionSectionRecent => 'Usados recientemente';

  @override
  String get reactionSectionFaces => 'Caritas';

  @override
  String get reactionSectionPeople => 'Personas';

  @override
  String get reactionSectionHearts => 'Corazones';

  @override
  String get reactionSectionCelebration => 'Celebración';

  @override
  String get reactionSectionFood => 'Comida';

  @override
  String get reactionSectionNature => 'Naturaleza';

  @override
  String get reactionSectionSymbols => 'Símbolos';

  @override
  String get reactionsNoneAllowed =>
      'No hay reacciones disponibles en este chat';

  @override
  String reactionsUsed(int used, int limit) {
    return '$used de $limit';
  }

  @override
  String reactionMessageLimitReached(Object limit) {
    return 'Este mensaje ya tiene $limit reacciones distintas';
  }

  @override
  String get moreReactions => 'Más reacciones';

  @override
  String get reactionFailed => 'La reacción no se guardó';

  @override
  String get reactionTooFast => 'Demasiadas reacciones a la vez';

  @override
  String get reactionNotAllowed => 'Esa reacción no se permite aquí';

  @override
  String get reactionsNobody => 'Todavía nadie';

  @override
  String reactionUserFallback(Object id) {
    return 'Usuario $id';
  }

  @override
  String composerCharactersLeft(int count) {
    return 'quedan $count';
  }

  @override
  String get composerSendLabel => 'Enviar';

  @override
  String get composerSaveEditLabel => 'Guardar cambios';

  @override
  String get composerRecordLabel =>
      'Mantén pulsado para grabar un mensaje de voz';

  @override
  String composerReplyingTo(Object name) {
    return 'Responder a $name';
  }

  @override
  String composerSlowModeWait(int seconds) {
    return 'Modo lento: faltan $seconds s';
  }

  @override
  String composerSlowModeHint(int seconds) {
    return 'Este chat permite un mensaje cada $seconds s';
  }

  @override
  String get attachSheetTitle => 'Adjuntar';

  @override
  String get attachRecent => 'Recientes';

  @override
  String get attachCamera => 'Cámara';

  @override
  String get attachVoice => 'Mensaje de voz';

  @override
  String get attachVideoNote => 'Videomensaje';

  @override
  String attachVoiceHint(int seconds) {
    return 'Se envía solo, hasta $seconds s';
  }

  @override
  String attachVideoNoteHint(int seconds, int pixels) {
    return 'Se envía solo, hasta $seconds s y $pixels px';
  }

  @override
  String get attachGalleryDenied =>
      'Permite el acceso a fotos para elegir desde aquí';

  @override
  String get attachGalleryAllow => 'Permitir';

  @override
  String attachMediaFull(int count) {
    return 'Hasta $count fotos o vídeos por mensaje';
  }

  @override
  String attachSendCount(int count) {
    return 'Adjuntar $count';
  }

  @override
  String get attachUnavailable => 'No se pudo leer ese archivo';

  @override
  String videoNoteTooLarge(int pixels) {
    return 'Esta cámara graba por encima de $pixels px y el servidor lo rechaza para videomensajes';
  }

  @override
  String composerTooLongBy(int count) {
    return '$count por encima del límite';
  }

  @override
  String get videoNoteTapToRecord => 'Toca para grabar';

  @override
  String get videoNoteNoCamera =>
      'Este dispositivo no tiene cámara para grabar';

  @override
  String get videoNoteCameraDenied =>
      'Permite el acceso a la cámara y al micrófono para grabar un videomensaje';

  @override
  String get videoNoteCameraFailed => 'No se pudo iniciar la cámara';

  @override
  String get videoNoteDiscarded => 'No se grabó nada';

  @override
  String get attachmentOpen => 'Abrir';

  @override
  String attachmentSavedTo(String path) {
    return 'Guardado en $path';
  }

  @override
  String get attachmentSaveFailed => 'No se pudo guardar este archivo';

  @override
  String get attachmentUploading => 'Subiendo';

  @override
  String mediaViewerCounter(int index, int count) {
    return '$index de $count';
  }

  @override
  String get mediaViewerUnavailable => 'Este archivo ya no está disponible';

  @override
  String get mediaPreviewHint => 'Quita lo que no quieras enviar';

  @override
  String get mediaPreviewCaptionHint => 'Añade un pie de foto';

  @override
  String get mediaPreviewRemove => 'Quitar';

  @override
  String get composerRecordVideoNoteLabel =>
      'Mantén pulsado para grabar un videomensaje';

  @override
  String get composerSwitchToVideoNote => 'Cambiar a videomensaje';

  @override
  String get composerSwitchToVoice => 'Cambiar a mensaje de voz';

  @override
  String get videoNoteSwitchCamera => 'Cambiar de cámara';

  @override
  String get videoNoteDoubleTapToSwitch =>
      'Toca dos veces para cambiar de cámara';

  @override
  String get videoNoteOpeningCamera => 'Abriendo la cámara…';

  @override
  String get videoNoteHoldToRecord => 'Mantén pulsado para grabar';

  @override
  String get videoNoteSend => 'Enviar videomensaje';

  @override
  String get videoNoteRecordingLabel => 'Grabando un videomensaje';

  @override
  String get videoNoteTapForSound => 'Toca para activar el sonido';

  @override
  String get videoNoteTapToMute => 'Toca para silenciar';

  @override
  String get videoNoteHoldForFullScreen =>
      'Mantén pulsado para ver en pantalla completa';

  @override
  String videoNotePlayerLabel(String duration) {
    return 'Videomensaje, $duration';
  }

  @override
  String get videoNoteAutoplayOff => 'Toca para reproducir';

  @override
  String get mediaAutoplay => 'Reproducir videomensajes automáticamente';

  @override
  String get mediaAutoplayHint =>
      'Los videomensajes empiezan sin sonido cuando aparecen en pantalla. El sonido se activa al tocarlos.';

  @override
  String get mediaAutoplayAlways => 'Siempre';

  @override
  String get mediaAutoplayWifi => 'Solo con Wi-Fi';

  @override
  String get mediaAutoplayNever => 'Nunca';

  @override
  String get videoNotePreview => 'Vista previa de la cámara';

  @override
  String searchTypeMore(int count) {
    return 'Escribe al menos $count caracteres';
  }

  @override
  String get noMessagesFoundHint =>
      'La búsqueda mira lo que se dijo, no los nombres de archivo ni los títulos de los chats.';

  @override
  String get chatSettings => 'Ajustes del chat';

  @override
  String get chatSettingsNoPermission =>
      'Solo el propietario o un administrador puede cambiar este chat';

  @override
  String get chatNameCannotBeCleared =>
      'Un nombre no se puede quitar una vez que el chat tiene uno';

  @override
  String chatSlowModeRange(int max) {
    return 'de 0 a $max segundos';
  }

  @override
  String get chatReactionsPickHint =>
      'Elige los emoji con los que se puede reaccionar';

  @override
  String get chatNotMutedLabel => 'Notificaciones activadas';

  @override
  String get chatMutedToast => 'Notificaciones desactivadas para este chat';

  @override
  String get chatUnmutedToast =>
      'Notificaciones activadas de nuevo para este chat';

  @override
  String get muteForHour => 'Silenciar 1 hora';

  @override
  String get muteForEightHours => 'Silenciar 8 horas';

  @override
  String get muteForever => 'Silenciar hasta que lo reactive';

  @override
  String get leaveChatOwnerStuck =>
      'El creador del chat no puede salir, y ya no tienes permiso para eliminarlo.';

  @override
  String get chatInviteLink => 'Enlace de invitación';

  @override
  String get chatInviteLinkHint =>
      'Cualquiera con sesión iniciada en ChatiX puede abrir este enlace y unirse. Solo se abre en la aplicación.';

  @override
  String get chatInviteLinkCopied => 'Enlace de invitación copiado';

  @override
  String get sharedMedia => 'Multimedia';

  @override
  String get sharedFiles => 'Archivos';

  @override
  String get sharedLinks => 'Enlaces';

  @override
  String get sharedVoice => 'Voz';

  @override
  String get sharedMediaEmpty => 'Aún no hay fotos ni vídeos aquí';

  @override
  String get sharedFilesEmpty => 'Aún no hay archivos aquí';

  @override
  String get sharedLinksEmpty => 'Aún no hay enlaces aquí';

  @override
  String get sharedVoiceEmpty => 'Aún no hay mensajes de voz aquí';

  @override
  String get sharedContentLocalOnly =>
      'Muestra lo que este dispositivo ha descargado del chat: el servidor no lleva un índice de multimedia compartida.';

  @override
  String get chatSettingsUnchanged => 'Todavía no has cambiado nada';

  @override
  String get membersSearchHint => 'Buscar miembros';

  @override
  String get membersSearchLoadedOnly =>
      'Solo se busca entre los miembros ya cargados.';

  @override
  String membersSearchEmpty(String query) {
    return 'Aquí nadie coincide con «$query»';
  }

  @override
  String get membersLoadMore => 'Cargar más personas';

  @override
  String get membersSectionAdmins => 'Administración';

  @override
  String get membersSectionMembers => 'Miembros';

  @override
  String get membersSectionBanned => 'Miembros bloqueados';

  @override
  String get membersBannedHint =>
      'Las personas bloqueadas no pueden leer ni escribir aquí hasta que se levante el bloqueo.';

  @override
  String get membersEmptyTitle => 'No hay miembros que mostrar';

  @override
  String get membersEmptyInvite =>
      'Añade a alguien para que este chat empiece.';

  @override
  String get membersEmptyNoInvite =>
      'Solo los miembros con permiso de invitación pueden añadir gente aquí.';

  @override
  String get chatRoleOwner => 'Propietario';

  @override
  String get chatRoleAdmin => 'Administrador';

  @override
  String get chatRoleEditor => 'Editor';

  @override
  String get chatRoleDirect => 'Directo';

  @override
  String get chatRoleMember => 'Miembro';

  @override
  String get chatRoleViewer => 'Lector';

  @override
  String get chatRoleUnknown => 'Rol desconocido';

  @override
  String get memberMutedBadge => 'Silenciado';

  @override
  String get memberBannedBadge => 'Bloqueado';

  @override
  String get memberOpenProfile => 'Abrir perfil';

  @override
  String get memberMessagePrivately => 'Escribir en privado';

  @override
  String memberKickConfirmTitle(String name) {
    return '¿Expulsar a $name?';
  }

  @override
  String get memberKickConfirmBody =>
      'Perderá el acceso a este chat, pero podrás volver a añadirlo más adelante.';

  @override
  String memberRoleChanged(String name, String role) {
    return '$name ahora es $role';
  }

  @override
  String memberKicked(String name) {
    return '$name fue expulsado';
  }

  @override
  String memberBannedToast(String name) {
    return '$name fue bloqueado';
  }

  @override
  String memberUnbanned(String name) {
    return 'Se levantó el bloqueo de $name';
  }

  @override
  String get memberActionFailed => 'No salió bien. Inténtalo de nuevo.';

  @override
  String get roleAssignHint => 'Solo puedes asignar roles por debajo del tuyo.';

  @override
  String get roleOwnerTransferHint =>
      'Propietario no está en la lista: la API no permite traspasar un chat.';

  @override
  String get banForHour => 'Una hora';

  @override
  String get banForDay => 'Un día';

  @override
  String get banForWeek => 'Una semana';

  @override
  String get inviteMembersTitle => 'Añadir personas';

  @override
  String get inviteRoleLabel => 'Se unen como';

  @override
  String inviteRoomLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sitio para $count personas más',
      one: 'Sitio para 1 persona más',
      zero: 'Este chat está lleno',
    );
    return '$_temp0';
  }

  @override
  String inviteChatFull(int limit) {
    return 'Este chat admite $limit miembros y está lleno.';
  }

  @override
  String inviteAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir $count personas',
      one: 'Añadir 1 persona',
    );
    return '$_temp0';
  }

  @override
  String inviteAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas añadidas',
      one: '1 persona añadida',
    );
    return '$_temp0';
  }

  @override
  String inviteFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudo añadir a $count personas',
      one: 'No se pudo añadir a 1 persona',
    );
    return '$_temp0';
  }

  @override
  String get inviteSearchStart =>
      'Busca personas por nombre o @username y añádelas todas de una vez.';

  @override
  String get inviteSelectionFull => 'Eso es todo lo que cabe en este chat.';

  @override
  String peopleSearchNoneFound(String query) {
    return 'No se encontró a nadie para «$query»';
  }

  @override
  String get peopleSearchHint =>
      'La búsqueda coincide con cualquier parte de un nombre o @username.';

  @override
  String get profileShareAction => 'Compartir';

  @override
  String get profileShareCopied => 'Enlace del perfil copiado';

  @override
  String get profileBirthday => 'Cumpleaños';

  @override
  String get profileEmptyTitle => 'Aquí todavía no hay nada';

  @override
  String get profileEmptyHintSelf =>
      'Escribe unas palabras sobre ti para que sepan con quién hablan.';

  @override
  String get profileEmptyHintOther => 'Esta persona no ha rellenado su perfil.';

  @override
  String get profileAccount => 'Cuenta';

  @override
  String get profileAccountNoEmail => 'Sesión iniciada';

  @override
  String get profilePhoto => 'Foto';

  @override
  String get profileNoPhoto => 'Aún no hay foto';

  @override
  String get profileOpenLinkFailed => 'No se pudo abrir este enlace';

  @override
  String get profileContactCopied => 'Copiado al portapapeles';

  @override
  String get profileCopyAction => 'Copiar';

  @override
  String devicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivos',
      one: '1 dispositivo',
      zero: 'Ningún dispositivo',
    );
    return '$_temp0';
  }

  @override
  String get changePhoto => 'Cambiar foto';

  @override
  String get setPhoto => 'Elegir foto';

  @override
  String get choosePhoto => 'Elige una foto';

  @override
  String get avatarCropTitle => 'Mueve y amplía';

  @override
  String get avatarCropHint => 'Arrastra para mover, pellizca para ampliar.';

  @override
  String get avatarCropConfirm => 'Usar la foto';

  @override
  String get avatarStagePreparing => 'Preparando…';

  @override
  String get avatarStageUploading => 'Subiendo…';

  @override
  String get avatarStageConfirming => 'Casi listo…';

  @override
  String get avatarStageProcessing => 'Procesando la foto…';

  @override
  String get avatarStageDone => 'Foto actualizada';

  @override
  String get avatarProcessingFailed => 'No se pudo actualizar la foto';

  @override
  String get avatarProcessingFailedHint =>
      'El servidor no aceptó esa imagen. Prueba con otra.';

  @override
  String get avatarNotAnImage => 'Ese archivo no es una imagen';

  @override
  String get avatarTooLarge =>
      'Esa imagen es demasiado grande. Elige una más pequeña.';

  @override
  String get avatarUnreadable => 'No se pudo abrir esa imagen';

  @override
  String get profileEditDetails => 'Datos';

  @override
  String get profileEditLinks => 'Enlaces';

  @override
  String get profileEditLinksHint =>
      'Los enlaces se guardan en cuanto añades o quitas uno, aparte del formulario de abajo.';

  @override
  String get profileNoLinks => 'Aún no hay enlaces';

  @override
  String get removeLink => 'Quitar enlace';

  @override
  String get clearDateOfBirth => 'Borrar la fecha de nacimiento';

  @override
  String get specializationHint => 'A qué te dedicas, en pocas palabras';

  @override
  String bioCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String get profileSkillsHint => 'Hasta 30 caracteres cada uno';

  @override
  String get profileSaved => 'Perfil guardado';

  @override
  String get discardChangesTitle => '¿Descartar los cambios?';

  @override
  String get discardChangesMessage => 'Se perderán los cambios de este perfil.';

  @override
  String get discardAction => 'Descartar';

  @override
  String get keepEditingAction => 'Seguir editando';

  @override
  String get camera => 'Cámara';

  @override
  String get loading => 'Cargando…';

  @override
  String fieldTooLong(int max) {
    return 'Como mucho $max caracteres';
  }

  @override
  String skillTooLong(String skill, int max) {
    return '«$skill» supera los $max caracteres';
  }

  @override
  String callRoomName(String slug) {
    return 'Sala $slug';
  }

  @override
  String get callJoinExplanation =>
      'Aquí una llamada es una sala: únete y cualquiera de este chat podrá entrar contigo.';

  @override
  String get callNoIncomingNotice =>
      'Todavía no suena en las llamadas entrantes: el servidor no las anuncia.';

  @override
  String get callWaitingForOthers => 'Esperando a que entre alguien más…';

  @override
  String get callReconnecting => 'Reconectando…';

  @override
  String get callYou => 'Tú';

  @override
  String callParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participantes',
      one: '1 participante',
      zero: 'Aún no hay nadie',
    );
    return '$_temp0';
  }

  @override
  String get callMicrophoneMute => 'Silenciar';

  @override
  String get callMicrophoneUnmute => 'Activar el micrófono';

  @override
  String get callCameraStart => 'Activar vídeo';

  @override
  String get callCameraStop => 'Detener vídeo';

  @override
  String get callSpeakerOn => 'Altavoz';

  @override
  String get callSpeakerOff => 'Auricular';

  @override
  String get callLayoutGrid => 'Cuadrícula';

  @override
  String get callLayoutSpeaker => 'Vista del que habla';

  @override
  String callPinParticipant(String name) {
    return 'Fijar a $name';
  }

  @override
  String callUnpinParticipant(String name) {
    return 'Dejar de fijar a $name';
  }

  @override
  String get callMuteForEveryone => 'Silenciar para todos';

  @override
  String get callUnmuteForEveryone => 'Dejar que hable';

  @override
  String get callQualityExcellent => 'Conexión excelente';

  @override
  String get callQualityGood => 'Buena conexión';

  @override
  String get callQualityPoor => 'Conexión débil';

  @override
  String get callQualityLost => 'Conexión perdida';

  @override
  String get callMicrophonePermissionTitle =>
      'Deja que ChatiX use el micrófono';

  @override
  String get callMicrophonePermissionBody =>
      'Los demás solo te oirán si ChatiX puede usar el micrófono. Puedes volver a silenciarte cuando quieras.';

  @override
  String get callCameraPermissionTitle => 'Deja que ChatiX use la cámara';

  @override
  String get callCameraPermissionBody =>
      'Tu vídeo solo se envía mientras la cámara está encendida, y puedes apagarla cuando quieras.';

  @override
  String get callPermissionContinue => 'Continuar';

  @override
  String get callPermissionNotNow => 'Ahora no';

  @override
  String get callPermissionOpenSettings => 'Abrir ajustes';

  @override
  String get callMicrophoneBlocked =>
      'Micrófono apagado: ChatiX no tiene permiso.';

  @override
  String get callCameraBlocked => 'Cámara apagada: ChatiX no tiene permiso.';

  @override
  String get callSelfPreview => 'Tu cámara';

  @override
  String get callSelfPreviewHint => 'Arrastra para mover';

  @override
  String get callShowControls => 'Mostrar los controles de llamada';

  @override
  String get callOngoingInChat => 'Estás en una llamada de este chat';

  @override
  String get callReturn => 'Volver';

  @override
  String callMiniPlayerLabel(String name) {
    return 'Llamada con $name';
  }

  @override
  String get callMinimize => 'Minimizar la llamada';

  @override
  String get callDismiss => 'Cerrar';

  @override
  String get notificationNewMessage => 'Nuevo mensaje';

  @override
  String get notificationReplyHint => 'Mensaje';

  @override
  String get notificationReplyFailed => 'No se envió tu respuesta';

  @override
  String get notificationActionFailed => 'No se pudo hacer eso';

  @override
  String get notificationSettingsTitle => 'Notificaciones';

  @override
  String get notificationSoundTitle => 'Sonido';

  @override
  String get notificationSoundSubtitle =>
      'Reproducir un sonido cuando llegue algo';

  @override
  String get notificationVibrationTitle => 'Vibración';

  @override
  String get notificationVibrationSubtitle => 'Vibrar cuando llegue algo';

  @override
  String get notificationPreviewTitle => 'Vista previa del mensaje';

  @override
  String get notificationPreviewSubtitle => 'Mostrar quién escribió y qué dijo';

  @override
  String get quietHoursTitle => 'Horas de silencio';

  @override
  String get quietHoursSubtitle =>
      'Las notificaciones siguen llegando, pero sin sonido';

  @override
  String get quietHoursFrom => 'Desde';

  @override
  String get quietHoursTo => 'Hasta';

  @override
  String get chatNotificationsTitle => 'Excepciones por chat';

  @override
  String get chatNotificationsEmpty => 'Aún no hay excepciones';

  @override
  String get chatNotificationsEmptyHint =>
      'Todos los chats siguen los ajustes de arriba. Cambia uno desde el propio chat.';

  @override
  String get chatNotificationsReset => 'Restablecer todo';

  @override
  String get chatNotificationProfileTitle => 'Notificaciones de este chat';

  @override
  String get chatNotificationProfileAll => 'Todos los mensajes';

  @override
  String get chatNotificationProfileMentions => 'Solo menciones';

  @override
  String get chatNotificationProfileOff => 'Nada';

  @override
  String get notificationPermissionOffTitle =>
      'Las notificaciones están desactivadas';

  @override
  String get notificationPermissionOffHint =>
      'Nada de lo de abajo te llegará hasta que permitas las notificaciones en los ajustes del sistema.';

  @override
  String get notificationsEmptyTitle => 'Aún no hay notificaciones';

  @override
  String get notificationsEmptyMessage =>
      'Aquí aparecerán invitaciones, menciones y mensajes.';

  @override
  String get notificationsEmptyUnread => 'Nada sin leer';

  @override
  String get notificationsEmptyRead => 'Aún no has leído nada';

  @override
  String get notificationsEmptyFilterHint =>
      'Cambia el filtro a «Todo» para verlo todo.';

  @override
  String get timeJustNow => 'Ahora mismo';

  @override
  String notificationsMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notificaciones marcadas como leídas',
      one: '1 notificación marcada como leída',
      zero: 'No había nada sin leer',
    );
    return '$_temp0';
  }

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count min',
      one: 'hace 1 min',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count h',
      one: 'hace 1 h',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'Ayer',
    );
    return '$_temp0';
  }

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get appearanceHint => 'Tema, acento, fondo, burbujas y multimedia';

  @override
  String get appearancePreview => 'Vista previa';

  @override
  String get previewIncomingMessage =>
      'Todo lo que hay aquí se dibuja a partir de tu color de acento.';

  @override
  String get previewOutgoingMessage => 'Sin imágenes de fondo. Solo código.';

  @override
  String get previewIncomingReply => 'Mueve los controles y míralo.';

  @override
  String get amoledTitle => 'Negro (AMOLED)';

  @override
  String get amoledHint =>
      'Fondos de negro puro. En una pantalla OLED los píxeles negros no consumen energía.';

  @override
  String get accentFromAvatar => 'Tomar el color de mi foto';

  @override
  String get accentFromAvatarApplied => 'Acento tomado de tu foto.';

  @override
  String get accentFromAvatarEmpty =>
      'Tu foto no tiene color que tomar: se ve gris.';

  @override
  String get accentFromAvatarMissing => 'Añade primero una foto de perfil.';

  @override
  String get accentFromAvatarFailed =>
      'No se pudo leer tu foto. Inténtalo de nuevo.';

  @override
  String get accentCustom => 'Tu color';

  @override
  String get wallpaperNebula => 'Nebulosa';

  @override
  String get wallpaperRibbons => 'Cintas';

  @override
  String get wallpaperPrism => 'Prisma';

  @override
  String get wallpaperHalo => 'Halo';

  @override
  String get wallpaperDunes => 'Dunas';

  @override
  String get wallpaperIntensity => 'Intensidad';

  @override
  String get wallpaperPattern => 'Patrón';

  @override
  String get appearanceDensity => 'Densidad';

  @override
  String get appearanceDensityHint =>
      'Cuánto espacio ocupan las filas y las burbujas.';

  @override
  String get textSizeHint => 'Se aplica sobre el tamaño de texto del sistema.';

  @override
  String get bubbleShape => 'Forma de las burbujas';

  @override
  String get bubbleCorners => 'Esquinas';

  @override
  String get bubbleAnchor => 'Esquina de anclaje';

  @override
  String get bubbleAnchorHint =>
      'Ajusta la esquina del lado de quien escribe, para que la burbuja lo señale.';

  @override
  String get mediaSectionTitle => 'Multimedia';

  @override
  String get autoDownload => 'Descarga automática';

  @override
  String get autoDownloadHint =>
      'Qué adjuntos se descargan antes de que los abras.';

  @override
  String get autoDownloadPhotos => 'Fotos';

  @override
  String get autoDownloadVideos => 'Vídeos';

  @override
  String get autoDownloadFiles => 'Archivos';

  @override
  String get autoDownloadVoice => 'Mensajes de voz';

  @override
  String get autoDownloadWifi => 'Wi-Fi';

  @override
  String get autoDownloadMobile => 'Datos móviles';

  @override
  String get autoDownloadNever => 'Nunca';

  @override
  String get cacheLimit => 'Límite de caché';

  @override
  String get cacheLimitHint =>
      'Los adjuntos descargados se guardan hasta superar este límite; después se borran los más antiguos.';

  @override
  String get cacheEmpty => 'Todavía no hay nada en caché';

  @override
  String get cacheClear => 'Vaciar caché';

  @override
  String get cacheMeasuring => 'Calculando…';

  @override
  String get appearanceReduceMotionNotice =>
      'Tu sistema pide menos movimiento, así que aquí nada se anima.';

  @override
  String get appearanceHighContrastNotice =>
      'El alto contraste está activado: los fondos se pintan suaves para que el texto se lea.';

  @override
  String cacheInUse(String size) {
    return '$size en uso';
  }

  @override
  String cacheCleared(String size) {
    return 'Se liberaron $size';
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
  String get attachmentTapToDownload => 'Toca para descargar';

  @override
  String get welcomeHeadline => 'Te damos la bienvenida a ChatiX';

  @override
  String get welcomeTagline => 'Mensajes que van a tu ritmo.';

  @override
  String get welcomeGetStarted => 'Empezar';

  @override
  String get welcomeSignIn => 'Ya tengo una cuenta';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingDone => 'Crear una cuenta';

  @override
  String get onboardingRealtimeTitle => 'Todo en tiempo real';

  @override
  String get onboardingRealtimeBody =>
      'Los mensajes, las ediciones y las reacciones llegan en el momento en que ocurren, y la app se abre en la conversación que dejaste antes incluso de que responda la red.';

  @override
  String get onboardingTogetherTitle => 'Chats, grupos, canales y llamadas';

  @override
  String get onboardingTogetherBody =>
      'De uno a uno, en un grupo de quinientas personas o en un canal para todos, con una llamada de voz o vídeo siempre a un toque.';

  @override
  String get onboardingPrivacyTitle => 'Solo tuyo';

  @override
  String get onboardingPrivacyBody =>
      'Mira todos los dispositivos con la sesión abierta y ciérralos, bloquea la app con tu huella y guarda los archivos en el teléfono hasta que decidas enviarlos.';

  @override
  String onboardingPageOf(int current, int total) {
    return 'Página $current de $total';
  }

  @override
  String get loginHeadline => 'Hola de nuevo';

  @override
  String get loginSubtitle => 'Inicia sesión y sigue la conversación.';

  @override
  String get registerHeadline => 'Crea tu cuenta';

  @override
  String get registerSubtitle => 'Se tarda alrededor de un minuto.';

  @override
  String get authOrContinueWith => 'o continúa con';

  @override
  String get authNoAccount => '¿No tienes cuenta?';

  @override
  String get authHaveAccount => '¿Ya tienes cuenta?';

  @override
  String get authErrorWrongLoginData =>
      'El usuario o la contraseña no son correctos.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirma tu dirección de correo antes de iniciar sesión.';

  @override
  String authErrorEmailNotConfirmedFor(String email) {
    return 'Confirma $email antes de iniciar sesión.';
  }

  @override
  String get authResendEmail => 'Enviar el correo otra vez';

  @override
  String get authErrorTooManyAttempts =>
      'Demasiados intentos. Espera un minuto y vuelve a probar.';

  @override
  String get authErrorDuplicateUsername =>
      'Este nombre de usuario ya está ocupado.';

  @override
  String get authErrorDuplicateEmail => 'Ya existe una cuenta con este correo.';

  @override
  String authErrorDuplicateField(String field) {
    return '$field ya está en uso.';
  }

  @override
  String get authErrorPasswordMismatch => 'Las contraseñas no coinciden.';

  @override
  String get authErrorInvalidCode => 'Este código ya no vale. Pide uno nuevo.';

  @override
  String get authErrorUserNotFound =>
      'No encontramos ninguna cuenta con estos datos.';

  @override
  String get authErrorOffline =>
      'Sin conexión. Revisa tu red y vuelve a probar.';

  @override
  String get authErrorGeneric => 'Algo ha salido mal. Inténtalo de nuevo.';

  @override
  String get passwordStrengthLabel => 'Seguridad de la contraseña';

  @override
  String get passwordStrengthWeak => 'Débil';

  @override
  String get passwordStrengthFair => 'Aceptable';

  @override
  String get passwordStrengthGood => 'Buena';

  @override
  String get passwordStrengthStrong => 'Fuerte';

  @override
  String get passwordShow => 'Mostrar la contraseña';

  @override
  String get passwordHide => 'Ocultar la contraseña';

  @override
  String get verifyEmailHeadline => 'Mira tu correo';

  @override
  String verifyEmailSentTo(String email) {
    return 'Hemos enviado un código de confirmación a $email.';
  }

  @override
  String get verifyEmailSentToYou =>
      'Te hemos enviado un código de confirmación.';

  @override
  String get verifyEmailClipboardHint =>
      'Copia el código del correo: ChatiX lo recoge en cuanto vuelvas.';

  @override
  String get verifyEmailCodeFromClipboard => 'Código tomado del portapapeles';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'Podrás pedir otro correo en ${seconds}s';
  }

  @override
  String get verifyEmailWrongAddress => '¿Dirección equivocada?';

  @override
  String get verifyEmailChangeAddress => 'Usar otra';

  @override
  String get biometricUnlockTitle => 'Desbloquear con biometría';

  @override
  String get biometricUnlockSubtitle =>
      'Pedir huella o rostro cada vez que se vuelva a abrir ChatiX.';

  @override
  String get biometricUnlockUnavailable =>
      'Este dispositivo no tiene biometría configurada.';

  @override
  String get biometricUnlockReason => 'Desbloquear ChatiX';

  @override
  String get biometricUnlockLockedTitle => 'ChatiX está bloqueado';

  @override
  String get biometricUnlockLockedBody => 'Desbloquea para volver a tus chats.';

  @override
  String get biometricUnlockAction => 'Desbloquear';

  @override
  String get biometricUnlockFailed =>
      'La comprobación no ha pasado. Inténtalo de nuevo.';

  @override
  String get biometricUnlockLockedOut =>
      'El sistema ha bloqueado la biometría tras demasiados intentos.';

  @override
  String get biometricUnlockNotEnrolled =>
      'Este dispositivo no tiene ninguna huella ni rostro registrado.';

  @override
  String get biometricUnlockEnableFailed =>
      'No se ha podido activar la biometría.';

  @override
  String get settingsSecuritySection => 'Seguridad';

  @override
  String get settingsAccountSection => 'Cuenta';

  @override
  String get logoutConfirmTitle => '¿Cerrar sesión?';

  @override
  String get logoutConfirmBody =>
      'Este dispositivo olvidará tus mensajes, borradores y archivos descargados. Tu cuenta no cambia.';

  @override
  String get logoutAction => 'Cerrar sesión';

  @override
  String get logoutFailed =>
      'No se ha podido cerrar la sesión. Inténtalo de nuevo.';

  @override
  String get logoutInProgress => 'Cerrando sesión…';

  @override
  String get appearanceFeel => 'Tacto';

  @override
  String get appearanceHaptics => 'Vibración';

  @override
  String get appearanceHapticsHint =>
      'Vibraciones breves al enviar un mensaje, al reaccionar o al completar un gesto. La configuración de vibración de tu dispositivo sigue mandando.';

  @override
  String get failureGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get failureRateLimited =>
      'Demasiados intentos. Espera un minuto e inténtalo de nuevo.';

  @override
  String get failureNoConnection =>
      'Sin conexión a internet. Comprueba tu red e inténtalo de nuevo.';

  @override
  String get failureTimeout =>
      'El servidor tardó demasiado en responder. Inténtalo de nuevo.';

  @override
  String get failureInsecureSessionCookie =>
      'El servidor envió una cookie de inicio de sesión insegura, así que la sesión no se guardó. Es un ajuste del servidor: contacta con soporte.';

  @override
  String get apiErrorSessionEnded =>
      'Tu sesión ha terminado. Inicia sesión de nuevo.';

  @override
  String get apiErrorSessionExpired =>
      'Tu sesión ha caducado. Inicia sesión de nuevo.';

  @override
  String get apiErrorSessionInvalid =>
      'Tu sesión ya no es válida. Inicia sesión de nuevo.';

  @override
  String get apiErrorSessionSignedOut =>
      'Se cerró esta sesión. Inicia sesión de nuevo.';

  @override
  String get apiErrorAccessDenied => 'No tienes permiso para hacer eso.';

  @override
  String get apiErrorValidation =>
      'Algunos datos no son válidos. Revísalos e inténtalo de nuevo.';

  @override
  String get apiErrorNotFoundGeneric =>
      'No hemos encontrado eso: puede que se haya eliminado.';

  @override
  String get apiErrorTooLongGeneric =>
      'Ese valor es demasiado largo. Acórtalo.';

  @override
  String get apiErrorLimitExceededGeneric =>
      'Se ha alcanzado un límite, así que esta acción no está disponible.';

  @override
  String get apiErrorWrongLoginData => 'Usuario o contraseña incorrectos.';

  @override
  String get apiErrorPasswordMismatch => 'Las contraseñas no coinciden.';

  @override
  String get apiErrorDuplicateUser => 'Ese usuario o correo ya está en uso.';

  @override
  String get apiErrorEmailNotConfirmed =>
      'Confirma tu correo antes de iniciar sesión.';

  @override
  String get apiErrorOauthProviderUnsupported =>
      'Ese proveedor de inicio de sesión no es compatible.';

  @override
  String get apiErrorOauthStateNotFound =>
      'El intento de inicio de sesión caducó. Inténtalo de nuevo.';

  @override
  String get apiErrorOauthLinkedAnotherUser =>
      'Esa cuenta ya está vinculada a otro usuario.';

  @override
  String get apiErrorProfileExists => 'Ya tienes un perfil.';

  @override
  String get apiErrorNotChatMember => 'No eres miembro de este chat.';

  @override
  String get apiErrorAlreadyChatMember => 'Esa persona ya está en este chat.';

  @override
  String get apiErrorInvalidChatRole => 'Ese no es un rol de chat válido.';

  @override
  String get apiErrorDirectChatExists =>
      'Ya tienes un chat directo con esta persona.';

  @override
  String get apiErrorMessageTooLong =>
      'Ese mensaje es demasiado largo. Acórtalo.';

  @override
  String get apiErrorInvalidMessage =>
      'Ese mensaje no se puede enviar tal como está.';

  @override
  String get apiErrorSlowModeLimit =>
      'El modo lento está activo: espera antes de enviar otro mensaje.';

  @override
  String get apiErrorSlowModeOutOfRange =>
      'El modo lento debe estar entre 0 segundos y 24 horas.';

  @override
  String get apiErrorAttachmentLimitExceeded =>
      'Demasiados archivos adjuntos para un mensaje.';

  @override
  String get apiErrorAttachmentNotFound =>
      'Ese archivo adjunto ya no está disponible.';

  @override
  String get apiErrorAttachmentValidation =>
      'Ese archivo no se puede adjuntar: revisa su tipo y tamaño.';

  @override
  String get apiErrorEmptyAttachmentUpload => 'Elige un archivo para adjuntar.';

  @override
  String get apiErrorInvalidUploadToken =>
      'La subida caducó. Adjunta el archivo de nuevo.';

  @override
  String get apiErrorAvatarNotImage =>
      'Un avatar debe ser un archivo de imagen.';

  @override
  String get apiErrorActiveCallExists =>
      'Ya hay una llamada activa en este chat.';

  @override
  String get apiErrorNoActiveCall =>
      'No hay ninguna llamada activa en este chat.';

  @override
  String get apiErrorLivekitUnauthorized => 'No puedes unirte a esta llamada.';

  @override
  String get apiErrorLivekitError =>
      'El servicio de llamadas no está disponible ahora mismo.';

  @override
  String get apiErrorInvalidReaction =>
      'Ese emoji no se puede usar como reacción.';

  @override
  String get apiErrorReactionNotAllowed =>
      'Esa reacción no está permitida en este chat.';

  @override
  String get apiErrorReactionsDisabled =>
      'Las reacciones están desactivadas en este chat.';

  @override
  String get apiErrorTooManyReactions =>
      'No se pueden añadir más reacciones aquí.';

  @override
  String get apiErrorMaxLimitCursor =>
      'Se reanudaron demasiados chats a la vez.';

  @override
  String a11yMessageFrom(String author, String time) {
    return 'Mensaje de $author, $time';
  }

  @override
  String a11yMessageMine(String time) {
    return 'Tu mensaje, $time';
  }

  @override
  String get a11ySystemMessage => 'Mensaje del sistema';

  @override
  String a11yReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reacciones',
      one: '1 reacción',
    );
    return '$_temp0';
  }

  @override
  String get a11yReactionYours => 'incluida la tuya';

  @override
  String get a11yMessageActionsHint => 'mostrar acciones del mensaje';

  @override
  String a11yMessageAttachmentsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos adjuntos',
      one: '1 archivo adjunto',
    );
    return '$_temp0';
  }

  @override
  String get reviewPromptTitle => '¿Te gusta la aplicación?';

  @override
  String get reviewPromptBody => '¿Quieres compartir tu opinión con nosotros?';

  @override
  String get reviewPromptDecline => 'No, gracias';

  @override
  String get reviewPromptAccept => 'Claro';

  @override
  String get feedbackTitle => 'Tu opinión importa';

  @override
  String get feedbackBody =>
      'Cuéntanos qué te parece la aplicación. Si te gusta, una reseña en la tienda nos ayudaría mucho.';

  @override
  String get feedbackHint => 'Escribe tu opinión aquí';

  @override
  String get feedbackSubmit => 'Enviar';

  @override
  String get updateRequiredTitle => 'Actualización necesaria';

  @override
  String get updateAvailableTitle => 'Actualización disponible';

  @override
  String updateRequiredBody(String version) {
    return 'Se necesita la versión $version para seguir usando ChatiX.';
  }

  @override
  String updateAvailableBody(String version) {
    return 'La versión $version está disponible.';
  }

  @override
  String get updateWhatsNew => 'Novedades';

  @override
  String get updateLater => 'Más tarde';

  @override
  String get updateNow => 'Actualizar ahora';

  @override
  String get updateAction => 'Actualizar';

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
  String get attachmentDownload => 'Descargar';

  @override
  String get attachmentDownloadFailed => 'No se pudo descargar el archivo';

  @override
  String get attachmentShareFailed => 'No se pudo compartir el archivo';

  @override
  String get attachmentRevealFailed => 'No se pudo abrir la carpeta';

  @override
  String get messageSaveFile => 'Guardar';

  @override
  String get messageShareFile => 'Compartir';

  @override
  String get messageShowInFolder => 'Mostrar en la carpeta';

  @override
  String get bubbleFill => 'Tus burbujas';

  @override
  String get bubbleFillGradient => 'Degradado';

  @override
  String get bubbleFillSolid => 'Color sólido';

  @override
  String get deleteMessageTitle => '¿Eliminar el mensaje?';

  @override
  String get deleteMessageForEveryone =>
      'Desaparecerá para todos los participantes.';

  @override
  String get deleteMessagesForEveryone =>
      'Desaparecerán para todos los participantes.';

  @override
  String get messageDeleteFailed => 'No se pudo eliminar el mensaje.';

  @override
  String get validationLoginIdentifierRequired =>
      'Introduce tu correo o nombre de usuario';

  @override
  String get validationUsernameRequired => 'Introduce un nombre de usuario';

  @override
  String validationMinLength(int min) {
    String _temp0 = intl.Intl.pluralLogic(
      min,
      locale: localeName,
      other: 'Al menos $min caracteres',
      one: 'Al menos $min carácter',
    );
    return '$_temp0';
  }

  @override
  String get validationUsernameCharacters =>
      'Solo se permiten letras latinas, números, espacios y , . \' -';

  @override
  String get validationEmailRequired => 'Introduce tu correo';

  @override
  String get validationEmailInvalid => 'Introduce un correo válido';

  @override
  String get validationPasswordRequired => 'Introduce una contraseña';

  @override
  String get validationPasswordUppercase =>
      'Añade al menos una letra mayúscula';

  @override
  String get validationPasswordLowercase =>
      'Añade al menos una letra minúscula';

  @override
  String get validationPasswordDigit => 'Añade al menos un número';

  @override
  String validationPasswordSpecial(String characters) {
    return 'Añade al menos un carácter especial: $characters';
  }

  @override
  String get validationPasswordRepeatRequired => 'Repite tu contraseña';

  @override
  String get validationPasswordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get validationFieldRequired => 'Este campo es obligatorio';

  @override
  String get resetPasswordRequestIntro =>
      'Introduce el correo de tu cuenta y te enviaremos un código para restablecer la contraseña.';

  @override
  String get resetPasswordConfirmIntro =>
      'Introduce el código del correo y una contraseña nueva.';

  @override
  String get createChatDirectSearchLabel => '¿A quién quieres escribir?';

  @override
  String get addPeopleSearchLabel => 'Añade personas por nombre o @usuario';

  @override
  String get createChatDirectHelper =>
      'Elige a una persona: un chat directo tiene exactamente dos miembros';

  @override
  String createChatMembersHelper(int max) {
    return 'Hasta $max personas ahora; puedes añadir más después';
  }

  @override
  String get createChatDirectNeedsPeer =>
      'Un chat directo necesita exactamente a otra persona: búscala por nombre o @usuario';

  @override
  String createChatDirectTooMany(int count) {
    return 'Un chat directo solo tiene a otra persona, pero hay $count seleccionadas: elige Grupo';
  }

  @override
  String get createChatNameRequired => 'Ponle un nombre al chat';

  @override
  String createChatTooManyMembers(int max) {
    return 'Ahora puedes añadir hasta $max personas; añade al resto cuando se cree el chat';
  }

  @override
  String get createChatFailed => 'No se pudo crear el chat';

  @override
  String get settingsRowHint => 'Notificaciones, apariencia, privacidad';

  @override
  String profileBirthdayWithAge(String date, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age años',
      one: '$age año',
    );
    return '$date ($_temp0)';
  }
}
