// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Flutter Riverpod Clean Architecture';

  @override
  String get welcomeMessage =>
      'Добро пожаловать во Flutter Riverpod Clean Architecture';

  @override
  String get home => 'Главная';

  @override
  String get settings => 'Настройки';

  @override
  String get profile => 'Профиль';

  @override
  String get darkMode => 'Тёмная тема';

  @override
  String get lightMode => 'Светлая тема';

  @override
  String get systemMode => 'Как в системе';

  @override
  String get language => 'Язык';

  @override
  String get change_language => 'Сменить язык приложения';

  @override
  String get theme => 'Тема';

  @override
  String get change_theme => 'Сменить тему приложения';

  @override
  String get notifications => 'Уведомления';

  @override
  String get notification_settings => 'Настроить уведомления';

  @override
  String get localization_demo => 'Демо локализации';

  @override
  String get localization_demo_description =>
      'Посмотреть возможности локализации в действии';

  @override
  String get language_settings => 'Настройки языка';

  @override
  String get select_your_language => 'Выберите язык';

  @override
  String get language_explanation =>
      'Выбранный язык будет применён во всём приложении';

  @override
  String get localization_assets_demo => 'Демо локализации и ресурсов';

  @override
  String get current_language => 'Текущий язык';

  @override
  String get language_code => 'Код языка';

  @override
  String get language_name => 'Название языка';

  @override
  String get formatting_examples => 'Примеры форматирования';

  @override
  String get date_full => 'Дата (полная)';

  @override
  String get date_short => 'Дата (короткая)';

  @override
  String get time => 'Время';

  @override
  String get currency => 'Валюта';

  @override
  String get percent => 'Проценты';

  @override
  String get localized_assets => 'Локализованные ресурсы';

  @override
  String get localized_assets_explanation =>
      'Этот раздел показывает, как загружать разные ресурсы в зависимости от выбранного языка. Изображения, звуки и другие файлы могут быть свои для каждого языка.';

  @override
  String get image_example => 'Пример локализованного изображения';

  @override
  String get welcome_image_caption => 'Это изображение выбрано по вашему языку';

  @override
  String get common_image_example => 'Пример общего изображения';

  @override
  String get common_image_caption =>
      'Это изображение одинаково для всех языков';

  @override
  String get logout => 'Выйти';

  @override
  String get login => 'Вход';

  @override
  String get email => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get signIn => 'Войти';

  @override
  String get register => 'Регистрация';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get errorOccurred => 'Произошла ошибка';

  @override
  String get tryAgain => 'Попробовать снова';

  @override
  String greeting(String name) {
    return 'Здравствуйте, $name!';
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
      other: '$countString элемента',
      many: '$countString элементов',
      few: '$countString элемента',
      one: '$countString элемент',
      zero: 'Ничего нет',
    );
    return '$_temp0';
  }

  @override
  String lastUpdated(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Обновлено: $dateString';
  }

  @override
  String get browsePeople => 'Люди';

  @override
  String get chatDirect => 'Личный чат';

  @override
  String get chatGroup => 'Группа';

  @override
  String get chatSupergroup => 'Супергруппа';

  @override
  String get chatChannel => 'Канал';

  @override
  String get chatFallbackTitle => 'Чат';

  @override
  String membersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
      zero: 'Нет участников',
    );
    return '$_temp0';
  }

  @override
  String get attachmentProcessing => 'Обработка…';

  @override
  String get attachmentFailed => 'Не удалось загрузить';

  @override
  String get attachmentOpenFailed => 'Не удалось открыть этот файл';

  @override
  String get imageLoadFailed => 'Изображение недоступно';

  @override
  String get close => 'Закрыть';

  @override
  String get addReaction => 'Добавить реакцию';

  @override
  String get reactionsDisabled => 'Реакции в этом чате отключены';

  @override
  String reactionLimitReached(Object limit) {
    return 'На одно сообщение можно поставить не больше $limit реакций';
  }

  @override
  String get messageNotFound => 'Это сообщение больше недоступно';

  @override
  String get chatInfo => 'О чате';

  @override
  String get chatName => 'Название';

  @override
  String get chatDescription => 'Описание';

  @override
  String get chatPublic => 'Публичный чат';

  @override
  String get chatPublicHint => 'Присоединиться может любой, у кого есть ссылка';

  @override
  String get chatAdminOnly => 'Только администраторы';

  @override
  String get chatAdminOnlyHint => 'Писать могут только администраторы';

  @override
  String get chatSlowMode => 'Медленный режим';

  @override
  String get chatSlowModeOff => 'Выключен';

  @override
  String chatSlowModeSeconds(Object seconds) {
    return '$seconds с между сообщениями';
  }

  @override
  String get chatReactionsMode => 'Реакции';

  @override
  String get chatReactionsAll => 'Все, любые эмодзи';

  @override
  String get chatReactionsSome => 'Только выбранные эмодзи';

  @override
  String get chatReactionsNone => 'Отключены';

  @override
  String get leaveChat => 'Покинуть чат';

  @override
  String get leaveChatConfirm =>
      'Покинуть этот чат? Вы перестанете получать его сообщения.';

  @override
  String get leaveChatOwnerBlocked =>
      'Создатель чата не может выйти — вместо этого удалите чат.';

  @override
  String get deleteChat => 'Удалить чат';

  @override
  String get deleteChatConfirm =>
      'Удалить этот чат у всех? Это нельзя отменить.';

  @override
  String get saveChanges => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get chatSettingsSaved => 'Чат обновлён';

  @override
  String get viewMembers => 'Участники';

  @override
  String get messageEdited => 'изменено';

  @override
  String get messageReply => 'Ответить';

  @override
  String get messageForward => 'Переслать';

  @override
  String get messageEdit => 'Изменить';

  @override
  String get messageDelete => 'Удалить';

  @override
  String get messageSelect => 'Выбрать';

  @override
  String get messageReact => 'Реакция';

  @override
  String get messageCopy => 'Копировать текст';

  @override
  String get messageCopied => 'Скопировано';

  @override
  String get linkOpenFailed => 'Эту ссылку нечем открыть';

  @override
  String get messageDetails => 'Подробности';

  @override
  String replyingTo(String author) {
    return 'Ответ $author';
  }

  @override
  String forwardedFrom(String author) {
    return 'Переслано от $author';
  }

  @override
  String get forwardedMessage => 'Пересланное сообщение';

  @override
  String get detailsSentAt => 'Отправлено';

  @override
  String get detailsAuthor => 'От';

  @override
  String get detailsSequence => 'Номер в чате';

  @override
  String get detailsEdited => 'Изменено';

  @override
  String get detailsEditedYes => 'Да';

  @override
  String get detailsDelivery => 'Доставка';

  @override
  String get detailsAttachments => 'Вложения';

  @override
  String get backToLatest => 'К последним сообщениям';

  @override
  String get messageRead => 'Прочитано';

  @override
  String get messageSent => 'Отправлено';

  @override
  String get dateToday => 'Сегодня';

  @override
  String get dateYesterday => 'Вчера';

  @override
  String get unreadMessages => 'Непрочитанные сообщения';

  @override
  String get noMessagesYet => 'Сообщений пока нет';

  @override
  String get editingMessage => 'Изменение сообщения';

  @override
  String get scrollToBottom => 'Перейти к новым сообщениям';

  @override
  String newMessagesBelow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count новых сообщения ниже',
      many: '$count новых сообщений ниже',
      few: '$count новых сообщения ниже',
      one: '$count новое сообщение ниже',
      zero: 'Новых сообщений нет',
    );
    return '$_temp0';
  }

  @override
  String get connectionReconnecting => 'Переподключение…';

  @override
  String get connectionOffline => 'Нет сети — потяните, чтобы обновить';

  @override
  String get attachmentFallbackLabel => 'Вложение';

  @override
  String get composerJoinToSend => 'Вступите в чат, чтобы писать сообщения';

  @override
  String get composerBanned => 'Вы заблокированы в этом чате';

  @override
  String get composerMuted => 'Вам запрещено писать в этом чате';

  @override
  String get composerAdminsOnly =>
      'В этом чате могут писать только администраторы';

  @override
  String get composerNoPermission => 'У вас нет прав писать здесь';

  @override
  String attachmentSelection(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла',
      many: '$count файлов',
      few: '$count файла',
      one: '$count файл',
    );
    return '$_temp0, $size';
  }

  @override
  String get attachmentReady => 'Готово к отправке';

  @override
  String attachMediaLimits(int count, String size) {
    return 'До $count, каждый до $size';
  }

  @override
  String attachDocumentLimits(String size) {
    return 'Один файл, до $size';
  }

  @override
  String get messageDensity => 'Плотность сообщений';

  @override
  String get densityCompact => 'Плотно';

  @override
  String get densityCozy => 'Средне';

  @override
  String get densityComfortable => 'Свободно';

  @override
  String get voiceSlideToCancel => 'Влево — отмена, вверх — зафиксировать';

  @override
  String get voiceReleaseToCancel => 'Отпустите, чтобы отменить';

  @override
  String get voiceRecordingLocked =>
      'Запись — нажмите отправить, когда закончите';

  @override
  String get voiceLimitReached => 'Достигнута максимальная длина';

  @override
  String get voicePermissionDenied => 'Доступ к микрофону выключен';

  @override
  String get voiceMessage => 'Голосовое сообщение';

  @override
  String get voicePlay => 'Воспроизвести голосовое сообщение';

  @override
  String get voicePause => 'Приостановить голосовое сообщение';

  @override
  String get voiceUnavailable => 'Недоступно';

  @override
  String get voiceNotListened => 'Ещё не прослушано';

  @override
  String voiceSpeedLabel(String speed) {
    return 'Скорость воспроизведения $speed';
  }

  @override
  String get voiceRecording => 'Запись';

  @override
  String voiceTimeLeft(String time) {
    return 'Осталось $time';
  }

  @override
  String get voiceCancelRecording => 'Отмена';

  @override
  String get voiceSendRecording => 'Отправить голосовое сообщение';

  @override
  String get attach => 'Прикрепить';

  @override
  String get messageHint => 'Сообщение';

  @override
  String get unknownChat => 'Неизвестный чат';

  @override
  String get unknownProfile => 'Неизвестный профиль';

  @override
  String get goToChats => 'К чатам';

  @override
  String get pageNotFound => 'Страница не найдена';

  @override
  String pathDoesNotExist(String path) {
    return '$path не существует';
  }

  @override
  String get retry => 'Повторить';

  @override
  String get clear => 'Очистить';

  @override
  String get add => 'Добавить';

  @override
  String get save => 'Сохранить';

  @override
  String get readAll => 'Прочитать все';

  @override
  String get filter => 'Фильтр';

  @override
  String get filterAll => 'Все';

  @override
  String get filterUnread => 'Только непрочитанные';

  @override
  String get filterRead => 'Только прочитанные';

  @override
  String get showAll => 'Показать все';

  @override
  String get notificationsLoadFailed => 'Не удалось загрузить уведомления.';

  @override
  String get profiles => 'Люди';

  @override
  String get searchByName => 'Поиск по имени';

  @override
  String get searchByUsername => 'Поиск по имени пользователя';

  @override
  String get searchPeopleHint => 'Поиск по имени или @username';

  @override
  String get profilesLoadFailed => 'Не удалось загрузить профили.';

  @override
  String get signInToViewProfile => 'Войдите, чтобы посмотреть профиль';

  @override
  String get signInToEditProfile => 'Войдите, чтобы изменить профиль';

  @override
  String get profileAbout => 'О себе';

  @override
  String get profileSkills => 'Навыки';

  @override
  String get profileContacts => 'Контакты';

  @override
  String get sendMessageAction => 'Написать';

  @override
  String get editProfile => 'Изменить профиль';

  @override
  String get displayName => 'Отображаемое имя';

  @override
  String get specialization => 'Специализация';

  @override
  String get bio => 'О себе';

  @override
  String get dateOfBirth => 'Дата рождения';

  @override
  String get addContact => 'Добавить контакт';

  @override
  String get contactProvider => 'Сервис (например, telegram)';

  @override
  String get contactHandle => 'Контакт (например, @handle)';

  @override
  String get skillsHint => 'Введите навык и нажмите Enter';

  @override
  String get photoLibraryFailed => 'Не удалось открыть галерею';

  @override
  String get chats => 'Чаты';

  @override
  String get searchChatsAndPeople => 'Поиск по чатам и людям';

  @override
  String get chatsLoadFailed => 'Не удалось загрузить ваши чаты.';

  @override
  String get noChatsYet => 'Чатов пока нет';

  @override
  String get noChatsYetHint => 'Начните разговор, и он появится здесь.';

  @override
  String get newChat => 'Новый чат';

  @override
  String get chatTypeDirect => 'Личный';

  @override
  String get chatTypeGroup => 'Группа';

  @override
  String get chatTypeSuper => 'Супер';

  @override
  String get chatTypeChannel => 'Канал';

  @override
  String get chatPublicHintCreate => 'Этот чат сможет найти и открыть любой';

  @override
  String get chatSlowModeSecondsField => 'Медленный режим (секунды)';

  @override
  String get createChat => 'Создать чат';

  @override
  String get membersTitle => 'Участники';

  @override
  String get membersLoadFailed => 'Не удалось загрузить участников';

  @override
  String get addMember => 'Добавить участника';

  @override
  String get changeRole => 'Изменить роль';

  @override
  String get banMember => 'Заблокировать';

  @override
  String get banMemberTitle => 'Блокировка участника';

  @override
  String get kickMember => 'Исключить';

  @override
  String get banReason => 'Причина (необязательно)';

  @override
  String get banUntil => 'Указать дату';

  @override
  String get searchPeople => 'Люди';

  @override
  String get noPeopleFound => 'Никого не найдено';

  @override
  String get callConnecting => 'Соединение…';

  @override
  String get callJoin => 'Присоединиться к звонку';

  @override
  String get callEnded => 'Звонок завершён';

  @override
  String get callRejoin => 'Вернуться в звонок';

  @override
  String get callLeave => 'Выйти';

  @override
  String get callTitle => 'Звонок';

  @override
  String selectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String deleteMessagesTitle(int count) {
    return 'Удалить сообщений: $count?';
  }

  @override
  String get cannotBeUndone => 'Это нельзя отменить.';

  @override
  String get chatLoadFailed => 'Не удалось загрузить чат';

  @override
  String get attachMedia => 'Фото и видео';

  @override
  String get attachDocument => 'Документ';

  @override
  String get messageForwarded => 'Сообщение переслано';

  @override
  String get forwardTo => 'Переслать в';

  @override
  String get noOtherChats => 'Других чатов нет';

  @override
  String get chatsLoadFailedShort => 'Не удалось загрузить чаты';

  @override
  String get messageWaitingToSend => 'Ожидает отправки';

  @override
  String get messageNotSent => 'Не отправлено';

  @override
  String get connectionBusy => 'Подключение…';

  @override
  String get connectionWaitingForNetwork => 'Ожидание сети';

  @override
  String get wsDiagnostics => 'Диагностика соединения';

  @override
  String wsDiagnosticsFrames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Записано $count кадра',
      many: 'Записано $count кадров',
      few: 'Записано $count кадра',
      one: 'Записан $count кадр',
      zero: 'Кадры не записаны',
    );
    return '$_temp0';
  }

  @override
  String get wsDiagnosticsCopied => 'Диагностика скопирована';

  @override
  String get discard => 'Отменить';

  @override
  String get reactedTitle => 'Отреагировали';

  @override
  String get noReactionsYet => 'Так ещё никто не отреагировал';

  @override
  String get showMore => 'Показать ещё';

  @override
  String get bulkForwarding => 'Пересылка';

  @override
  String get bulkDeleting => 'Удаление';

  @override
  String bulkProgress(String label, int done, int total) {
    return '$label $done из $total…';
  }

  @override
  String bulkComplete(String label, int total) {
    return '$label завершена ($total)';
  }

  @override
  String bulkPartial(int done, int total, int failed, String reason) {
    return 'Успешно $done из $total — не удалось $failed: $reason';
  }

  @override
  String get callTokenUnavailable => 'Не удалось начать звонок';

  @override
  String get loginTitle => 'Вход';

  @override
  String get emailOrUsername => 'Email или имя пользователя';

  @override
  String get emailOrUsernameHint => 'you@example.com или ваше имя пользователя';

  @override
  String get passwordHint => 'Введите пароль';

  @override
  String get logIn => 'Войти';

  @override
  String get username => 'Имя пользователя';

  @override
  String get usernameHint => 'от 4 до 100 символов';

  @override
  String get emailHint => 'Введите email';

  @override
  String get passwordRule => '8+ символов, прописные/строчные/цифра/спецсимвол';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get confirmPasswordHint => 'Повторите пароль';

  @override
  String get signInTitle => 'Вход';

  @override
  String get backToSignIn => 'Вернуться ко входу';

  @override
  String get setNewPassword => 'Задать новый пароль';

  @override
  String get resetCode => 'Код восстановления';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get confirmNewPassword => 'Повторите новый пароль';

  @override
  String get resetPassword => 'Сбросить пароль';

  @override
  String get passwordUpdated => 'Пароль обновлён — войдите снова.';

  @override
  String get sendCode => 'Отправить код';

  @override
  String get haveCodeAlready => 'У меня уже есть код';

  @override
  String get resetCodeSent => 'Код восстановления отправлен на ваш email.';

  @override
  String get verifyEmailTitle => 'Подтверждение email';

  @override
  String get verifyEmailHint =>
      'Вставьте токен из письма, которое мы отправили.';

  @override
  String get verificationToken => 'Токен подтверждения';

  @override
  String get verify => 'Подтвердить';

  @override
  String get resendLimitHint =>
      'Мы можем отправить письмо ещё раз — до 3 раз в час.';

  @override
  String get resendVerification => 'Отправить письмо ещё раз';

  @override
  String get emailVerified => 'Email подтверждён';

  @override
  String get verificationSent => 'Письмо отправлено — проверьте почту.';

  @override
  String get browserOpenFailed => 'Не удалось открыть браузер для входа';

  @override
  String continueWith(String provider) {
    return 'Продолжить через $provider';
  }

  @override
  String get peopleSearchFailed => 'Не удалось выполнить поиск людей';

  @override
  String get startChatFailed => 'Не удалось начать чат с этим человеком';

  @override
  String get profileLoadFailed => 'Не удалось загрузить профиль';

  @override
  String get myProfileLoadFailed => 'Не удалось загрузить ваш профиль';

  @override
  String get saveChangesFailed => 'Не удалось сохранить изменения';

  @override
  String get avatarUpdateFailed => 'Не удалось обновить аватар';

  @override
  String get oauthCancelled => 'Вход отменён';

  @override
  String get oauthCancelledHint =>
      'Ничего не изменилось. Попробуйте снова или войдите по имени и паролю.';

  @override
  String get oauthFailed => 'Не удалось завершить вход';

  @override
  String get oauthFailedHint => 'Войдите по имени пользователя и паролю.';

  @override
  String get realtimeRejected =>
      'Обновления в реальном времени для этого чата выключены';

  @override
  String get forwardComment => 'Добавить комментарий (необязательно)';

  @override
  String get forwardAction => 'Переслать';

  @override
  String get banDuration => 'На какой срок';

  @override
  String get banForever => 'Навсегда';

  @override
  String get banUntilDate => 'До даты';

  @override
  String get banLift => 'Снять блокировку';

  @override
  String get banLiftHint =>
      'Отправляет прошедшую дату, которую сервер понимает как разблокировку';

  @override
  String get banPickDate => 'Выберите дату';

  @override
  String get myDevices => 'Мои устройства';

  @override
  String get devicesLoadFailed => 'Не удалось загрузить ваши устройства.';

  @override
  String get noDevices => 'Нет активных сессий';

  @override
  String get deviceActive => 'Активна';

  @override
  String get deviceInactive => 'Завершена';

  @override
  String deviceLastActive(String date) {
    return 'Последняя активность $date';
  }

  @override
  String get designSystem => 'Дизайн-система';

  @override
  String get accentColor => 'Акцентный цвет';

  @override
  String get chatWallpaper => 'Фон чата';

  @override
  String get wallpaperAurora => 'Аврора';

  @override
  String get wallpaperMesh => 'Сетка';

  @override
  String get wallpaperPlain => 'Однотонный';

  @override
  String get textSize => 'Размер текста';

  @override
  String get textSizeSmall => 'Мелкий';

  @override
  String get textSizeDefault => 'Обычный';

  @override
  String get textSizeLarge => 'Крупный';

  @override
  String get textSizeExtraLarge => 'Очень крупный';

  @override
  String get resetAppearance => 'Сбросить оформление';

  @override
  String get showcaseAccents => 'Акценты';

  @override
  String get showcaseNeutrals => 'Нейтральные';

  @override
  String get showcaseNeutralsLight => 'Светлая шкала';

  @override
  String get showcaseNeutralsDark => 'Тёмная шкала';

  @override
  String get showcaseRadii => 'Скругления';

  @override
  String get showcaseSpacing => 'Отступы';

  @override
  String get showcaseElevation => 'Тени';

  @override
  String get showcaseMotion => 'Движение';

  @override
  String get showcaseMotionFast => 'Быстро';

  @override
  String get showcaseMotionBase => 'Обычно';

  @override
  String get showcaseMotionSlow => 'Медленно';

  @override
  String get showcaseMotionReplay => 'Повторить';

  @override
  String get showcaseTypography => 'Типографика';

  @override
  String get showcaseTabularFigures => 'Табличные цифры';

  @override
  String get showcaseBubbles => 'Пузыри сообщений';

  @override
  String get showcaseReactions => 'Реакции';

  @override
  String get showcaseAuthors => 'Цвета авторов';

  @override
  String get showcaseComponents => 'Компоненты';

  @override
  String get showcaseIncomingSample =>
      'Входящее: тёплая подложка, тонкая рамка.';

  @override
  String get showcaseStackedSample => 'Второе сообщение в той же серии.';

  @override
  String get showcaseOutgoingSample => 'Исходящее: акцентный градиент.';

  @override
  String get messageSending => 'Отправляется';

  @override
  String get onlineNow => 'В сети';

  @override
  String userTyping(String name) {
    return '$name печатает…';
  }

  @override
  String severalTyping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count человека печатают…',
      many: '$count человек печатают…',
      few: '$count человека печатают…',
      one: '$count человек печатает…',
    );
    return '$_temp0';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вложения',
      many: '$count вложений',
      few: '$count вложения',
      one: '$count вложение',
    );
    return '$_temp0';
  }

  @override
  String get contacts => 'Контакты';

  @override
  String get profileSettingsHint => 'Ваше имя, аватар и контакты';

  @override
  String get noChatSelected => 'Чат не выбран';

  @override
  String get noChatSelectedHint =>
      'Выберите разговор из списка, чтобы начать читать.';

  @override
  String get newDirectChat => 'Новый личный чат';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get newChannel => 'Новый канал';

  @override
  String get quickActionsHint => 'Начать что-то новое';

  @override
  String unreadMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count непрочитанных сообщения',
      many: '$count непрочитанных сообщений',
      few: '$count непрочитанных сообщения',
      one: '$count непрочитанное сообщение',
      zero: 'Непрочитанных сообщений нет',
    );
    return '$_temp0';
  }

  @override
  String unreadNotificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count новых уведомления',
      many: '$count новых уведомлений',
      few: '$count новых уведомления',
      one: '$count новое уведомление',
      zero: 'Новых уведомлений нет',
    );
    return '$_temp0';
  }

  @override
  String get noContactsFound => 'По этому имени никого нет';

  @override
  String get noContactsFoundHint =>
      'Попробуйте короче или с другим написанием.';

  @override
  String get noContactsYet => 'Пока некого показать';

  @override
  String get previewYou => 'Вы';

  @override
  String get previewPhoto => 'Фото';

  @override
  String get previewVideo => 'Видео';

  @override
  String get previewVoice => 'Голосовое сообщение';

  @override
  String get previewVideoNote => 'Видеосообщение';

  @override
  String get previewFile => 'Файл';

  @override
  String get previewNoText => 'Сообщение';

  @override
  String get draftLabel => 'Черновик:';

  @override
  String get markAsRead => 'Отметить прочитанным';

  @override
  String get archiveChat => 'В архив';

  @override
  String get unarchiveChat => 'Из архива';

  @override
  String get pinChat => 'Закрепить';

  @override
  String get unpinChat => 'Открепить';

  @override
  String get muteChat => 'Отключить звук';

  @override
  String get unmuteChat => 'Включить звук';

  @override
  String get archivedChats => 'Архив';

  @override
  String get chatPinnedLabel => 'Закреплён';

  @override
  String get chatMutedLabel => 'Уведомления выключены';

  @override
  String get chatArchivedToast => 'Чат в архиве';

  @override
  String get chatDeletedToast => 'Чат удалён';

  @override
  String get undo => 'Отменить';

  @override
  String get allChatsArchived => 'Всё в архиве';

  @override
  String previewVoiceWithDuration(String duration) {
    return 'Голосовое сообщение $duration';
  }

  @override
  String archivedChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count чата',
      many: '$count чатов',
      few: '$count чата',
      one: '$count чат',
    );
    return '$_temp0';
  }

  @override
  String get chatFolders => 'Папки';

  @override
  String get chatFoldersAll => 'Все чаты';

  @override
  String get folderPresetUnread => 'Непрочитанные';

  @override
  String get folderPresetPersonal => 'Личные';

  @override
  String get folderPresetGroups => 'Группы';

  @override
  String get folderPresetChannels => 'Каналы';

  @override
  String get folderPresetNoReply => 'Ждут моего ответа';

  @override
  String get newFolder => 'Новая папка';

  @override
  String get editFolder => 'Изменить папку';

  @override
  String get folderName => 'Название папки';

  @override
  String get folderIcon => 'Значок';

  @override
  String get folderRules => 'Правила';

  @override
  String get folderMatchModeTitle => 'Чат попадает сюда, если';

  @override
  String get folderMatchAll => 'Он подходит под все правила';

  @override
  String get folderMatchAny => 'Он подходит хотя бы под одно правило';

  @override
  String get addFolderRule => 'Добавить правило';

  @override
  String get removeFolderRule => 'Удалить правило';

  @override
  String get folderRuleChatType => 'Тип чата';

  @override
  String folderRuleChatTypeIn(String types) {
    return 'Тип — $types';
  }

  @override
  String get folderRuleUnread => 'Есть непрочитанные сообщения';

  @override
  String get folderRuleRead => 'Непрочитанного нет';

  @override
  String get folderRulePinned => 'Закреплён';

  @override
  String get folderRuleNotPinned => 'Не закреплён';

  @override
  String get folderRuleNoReply => 'Ждёт моего ответа';

  @override
  String folderRuleNoReplyDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Ждёт моего ответа больше $days дня',
      many: 'Ждёт моего ответа больше $days дней',
      few: 'Ждёт моего ответа больше $days дней',
      one: 'Ждёт моего ответа больше $days дня',
      zero: 'Ждёт моего ответа',
    );
    return '$_temp0';
  }

  @override
  String get folderRuleDaysLabel => 'Дней без моего ответа';

  @override
  String get folderRuleDaysAny => 'Любое';

  @override
  String get folderRuleMember => 'Есть человек';

  @override
  String folderRuleMemberNamed(String name) {
    return 'Есть $name';
  }

  @override
  String get folderRulePickPerson => 'Выберите человека';

  @override
  String get folderRuleNoPeople =>
      'Люди появятся здесь, когда у вас будут с ними чаты';

  @override
  String get folderRuleMemberLocalNote =>
      'Сравнивается с тем, что уже известно списку чатов: вы, все, чей состав загружен, последний отправитель и создатель чата.';

  @override
  String get deleteFolder => 'Удалить папку';

  @override
  String get deleteFolderConfirm =>
      'Удалить эту папку? Чаты из неё останутся на месте.';

  @override
  String get folderNameRequired => 'Дайте папке название';

  @override
  String folderNameTooLong(int count) {
    return 'Название папки — не больше $count символов';
  }

  @override
  String get folderRulesRequired => 'Добавьте хотя бы одно правило';

  @override
  String folderLimitReached(int count) {
    return 'Можно хранить не больше $count папок';
  }

  @override
  String pinLimitReached(int count) {
    return 'Закрепить можно только $count чатов. Сначала открепите один.';
  }

  @override
  String get foldersEmpty => 'Папок пока нет';

  @override
  String get foldersEmptyHint =>
      'Папка — это набор правил, а не список. Чаты попадают в неё и выходят сами.';

  @override
  String get folderReadyMade => 'Готовые';

  @override
  String get folderYours => 'Ваши папки';

  @override
  String folderRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count правила',
      many: '$count правил',
      few: '$count правила',
      one: '$count правило',
    );
    return '$_temp0';
  }

  @override
  String get folderEmptyChats => 'В этой папке пусто';

  @override
  String get folderEmptyChatsHint =>
      'Чаты появятся здесь, как только подойдут под её правила.';

  @override
  String get hideFolderTabs => 'Скрыть полосу папок';

  @override
  String get hideFolderTabsHint =>
      'Папки останутся, но вкладки над списком показываться не будут';

  @override
  String get unarchiveOnNewMessage => 'Возвращать при новом сообщении';

  @override
  String get unarchiveOnNewMessageHint =>
      'Чат из архива вернётся в список, когда в нём кто-нибудь напишет';

  @override
  String get organizerDeviceOnly =>
      'Папки хранятся на этом устройстве и не переносятся вместе с аккаунтом. Закрепления, архив и беззвучные чаты — переносятся.';

  @override
  String get chatPinnedZone => 'Закреплённые';

  @override
  String get chatUnarchivedToast => 'Возвращён в список';

  @override
  String get searchTabMessages => 'Сообщения';

  @override
  String get searchEverything => 'Поиск по чатам, людям и сообщениям';

  @override
  String get searchRecentQueries => 'Недавние запросы';

  @override
  String get searchRecentChats => 'Недавно открытые';

  @override
  String get searchClearHistory => 'Очистить';

  @override
  String get searchRemoveFromHistory => 'Убрать из недавних запросов';

  @override
  String get searchStartTitle => 'Найдите чат, человека или сообщение';

  @override
  String get searchStartHint =>
      'Чаты ищутся по названию, люди — по имени пользователя, сообщения — по тексту.';

  @override
  String get searchLoadedHistoryOnly => 'Поиск по тому, что есть на устройстве';

  @override
  String get searchLoadedHistoryExplained =>
      'Сервер недоступен, поэтому искали только среди сообщений, уже загруженных на это устройство.';

  @override
  String get noChatsFound => 'Чаты не найдены';

  @override
  String get noChatsFoundHint =>
      'Чаты ищутся по названию и описанию среди уже загруженных.';

  @override
  String get noPeopleFoundHint =>
      'Попробуйте другое написание или поиск по имени пользователя.';

  @override
  String get noMessagesFound => 'Сообщения не найдены';

  @override
  String get messageSearchFailed => 'Не удалось выполнить поиск сообщений';

  @override
  String get searchInChat => 'Поиск в этом чате';

  @override
  String searchMatchPosition(int current, int total) {
    return '$current из $total';
  }

  @override
  String get searchNoMatches => 'Совпадений нет';

  @override
  String get searchOlderMatch => 'Более раннее совпадение';

  @override
  String get searchNewerMatch => 'Более позднее совпадение';

  @override
  String get searchInChatHint => 'Поиск в этом чате';

  @override
  String get searchChatDescriptionMatch => 'Совпадение в описании';

  @override
  String get searchOpenChat => 'Открыть чат';

  @override
  String get reactionSectionRecent => 'Недавние';

  @override
  String get reactionSectionFaces => 'Смайлики';

  @override
  String get reactionSectionPeople => 'Люди';

  @override
  String get reactionSectionHearts => 'Сердца';

  @override
  String get reactionSectionCelebration => 'Праздник';

  @override
  String get reactionSectionFood => 'Еда';

  @override
  String get reactionSectionNature => 'Природа';

  @override
  String get reactionSectionSymbols => 'Символы';

  @override
  String get reactionsNoneAllowed => 'В этом чате нет доступных реакций';

  @override
  String reactionsUsed(int used, int limit) {
    return '$used из $limit';
  }

  @override
  String reactionMessageLimitReached(Object limit) {
    return 'На этом сообщении уже $limit разных реакций';
  }

  @override
  String get moreReactions => 'Ещё реакции';

  @override
  String get reactionFailed => 'Реакция не сохранена';

  @override
  String get reactionTooFast => 'Слишком много реакций сразу';

  @override
  String get reactionNotAllowed => 'Эта реакция здесь недоступна';

  @override
  String get reactionsNobody => 'Пока никого';

  @override
  String reactionUserFallback(Object id) {
    return 'Пользователь $id';
  }

  @override
  String composerCharactersLeft(int count) {
    return 'Осталось $count';
  }

  @override
  String get composerSendLabel => 'Отправить';

  @override
  String get composerSaveEditLabel => 'Сохранить изменения';

  @override
  String get composerRecordLabel =>
      'Удерживайте, чтобы записать голосовое сообщение';

  @override
  String composerReplyingTo(Object name) {
    return 'Ответ $name';
  }

  @override
  String composerSlowModeWait(int seconds) {
    return 'Медленный режим: ждать $seconds с';
  }

  @override
  String composerSlowModeHint(int seconds) {
    return 'В этом чате можно писать раз в $seconds с';
  }

  @override
  String get attachSheetTitle => 'Прикрепить';

  @override
  String get attachRecent => 'Недавние';

  @override
  String get attachCamera => 'Камера';

  @override
  String get attachVoice => 'Голосовое сообщение';

  @override
  String get attachVideoNote => 'Видеосообщение';

  @override
  String attachVoiceHint(int seconds) {
    return 'Отправляется отдельно, до $seconds с';
  }

  @override
  String attachVideoNoteHint(int seconds, int pixels) {
    return 'Отправляется отдельно, до $seconds с и $pixels px';
  }

  @override
  String get attachGalleryDenied =>
      'Разрешите доступ к фото, чтобы выбирать отсюда';

  @override
  String get attachGalleryAllow => 'Разрешить';

  @override
  String attachMediaFull(int count) {
    return 'До $count фото или видео в одном сообщении';
  }

  @override
  String attachSendCount(int count) {
    return 'Прикрепить $count';
  }

  @override
  String get attachUnavailable => 'Не удалось прочитать этот файл';

  @override
  String videoNoteTooLarge(int pixels) {
    return 'Эта камера снимает выше $pixels px, а для видеосообщений сервер это отклоняет';
  }

  @override
  String composerTooLongBy(int count) {
    return 'На $count больше лимита';
  }

  @override
  String get videoNoteTapToRecord => 'Нажмите, чтобы записать';

  @override
  String get videoNoteNoCamera => 'На этом устройстве нет камеры для записи';

  @override
  String get videoNoteCameraDenied =>
      'Разрешите доступ к камере и микрофону, чтобы записать видеосообщение';

  @override
  String get videoNoteCameraFailed => 'Не удалось запустить камеру';

  @override
  String get videoNoteDiscarded => 'Ничего не записано';

  @override
  String get attachmentOpen => 'Открыть';

  @override
  String attachmentSavedTo(String path) {
    return 'Сохранено в $path';
  }

  @override
  String get attachmentSaveFailed => 'Не удалось сохранить этот файл';

  @override
  String get attachmentUploading => 'Загрузка';

  @override
  String mediaViewerCounter(int index, int count) {
    return '$index из $count';
  }

  @override
  String get mediaViewerUnavailable => 'Это медиа больше недоступно';

  @override
  String get mediaPreviewHint => 'Уберите всё, что не собирались отправлять';

  @override
  String get mediaPreviewCaptionHint => 'Добавить подпись';

  @override
  String get mediaPreviewRemove => 'Убрать';

  @override
  String get composerRecordVideoNoteLabel =>
      'Удерживайте, чтобы записать видеосообщение';

  @override
  String get composerSwitchToVideoNote => 'Перейти к видеосообщению';

  @override
  String get composerSwitchToVoice => 'Перейти к голосовому сообщению';

  @override
  String get videoNoteSwitchCamera => 'Сменить камеру';

  @override
  String get videoNoteDoubleTapToSwitch => 'Двойное нажатие — сменить камеру';

  @override
  String get videoNoteOpeningCamera => 'Открываем камеру…';

  @override
  String get videoNoteHoldToRecord => 'Удерживайте для записи';

  @override
  String get videoNoteSend => 'Отправить видеосообщение';

  @override
  String get videoNoteRecordingLabel => 'Запись видеосообщения';

  @override
  String get videoNoteTapForSound => 'Нажмите для звука';

  @override
  String get videoNoteTapToMute => 'Нажмите, чтобы выключить звук';

  @override
  String get videoNoteHoldForFullScreen => 'Удерживайте для полного экрана';

  @override
  String videoNotePlayerLabel(String duration) {
    return 'Видеосообщение, $duration';
  }

  @override
  String get videoNoteAutoplayOff => 'Нажмите для воспроизведения';

  @override
  String get mediaAutoplay => 'Автовоспроизведение видеосообщений';

  @override
  String get mediaAutoplayHint =>
      'Видеосообщения запускаются без звука, когда попадают на экран. Звук включается по нажатию.';

  @override
  String get mediaAutoplayAlways => 'Всегда';

  @override
  String get mediaAutoplayWifi => 'Только по Wi-Fi';

  @override
  String get mediaAutoplayNever => 'Никогда';

  @override
  String get videoNotePreview => 'Изображение с камеры';

  @override
  String searchTypeMore(int count) {
    return 'Введите хотя бы $count символа';
  }

  @override
  String get noMessagesFoundHint =>
      'Поиск смотрит внутрь сказанного, а не на имена файлов или названия чатов.';

  @override
  String get chatSettings => 'Настройки чата';

  @override
  String get chatSettingsNoPermission =>
      'Менять этот чат может только владелец или администратор';

  @override
  String get chatNameCannotBeCleared =>
      'Название нельзя убрать, если оно у чата уже есть';

  @override
  String chatSlowModeRange(int max) {
    return 'от 0 до $max секунд';
  }

  @override
  String get chatReactionsPickHint =>
      'Выберите эмодзи, которыми можно реагировать';

  @override
  String get chatNotMutedLabel => 'Уведомления включены';

  @override
  String get chatMutedToast => 'Уведомления этого чата выключены';

  @override
  String get chatUnmutedToast => 'Уведомления этого чата снова включены';

  @override
  String get muteForHour => 'Выключить на 1 час';

  @override
  String get muteForEightHours => 'Выключить на 8 часов';

  @override
  String get muteForever => 'Выключить, пока не включу сам';

  @override
  String get leaveChatOwnerStuck =>
      'Создатель чата не может выйти, а прав удалить этот чат у вас больше нет.';

  @override
  String get chatInviteLink => 'Ссылка-приглашение';

  @override
  String get chatInviteLinkHint =>
      'Любой, кто вошёл в ChatiX, может открыть эту ссылку и вступить. Она открывается только в приложении.';

  @override
  String get chatInviteLinkCopied => 'Ссылка-приглашение скопирована';

  @override
  String get sharedMedia => 'Медиа';

  @override
  String get sharedFiles => 'Файлы';

  @override
  String get sharedLinks => 'Ссылки';

  @override
  String get sharedVoice => 'Голосовые';

  @override
  String get sharedMediaEmpty => 'Фото и видео здесь пока нет';

  @override
  String get sharedFilesEmpty => 'Файлов здесь пока нет';

  @override
  String get sharedLinksEmpty => 'Ссылок здесь пока нет';

  @override
  String get sharedVoiceEmpty => 'Голосовых сообщений здесь пока нет';

  @override
  String get sharedContentLocalOnly =>
      'Показывает то, что это устройство загрузило из чата — у сервера нет указателя общих медиа.';

  @override
  String get chatSettingsUnchanged => 'Пока ничего не изменилось';

  @override
  String get membersSearchHint => 'Поиск участников';

  @override
  String get membersSearchLoadedOnly =>
      'Ищем только среди уже загруженных участников.';

  @override
  String membersSearchEmpty(String query) {
    return 'Здесь никто не подходит под «$query»';
  }

  @override
  String get membersLoadMore => 'Загрузить ещё людей';

  @override
  String get membersSectionAdmins => 'Управление';

  @override
  String get membersSectionMembers => 'Участники';

  @override
  String get membersSectionBanned => 'Заблокированные';

  @override
  String get membersBannedHint =>
      'Заблокированные не могут читать и писать здесь, пока блокировку не снимут.';

  @override
  String get membersEmptyTitle => 'Участников нет';

  @override
  String get membersEmptyInvite => 'Добавьте кого-нибудь, чтобы чат начался.';

  @override
  String get membersEmptyNoInvite =>
      'Добавлять людей сюда могут только участники с правом приглашать.';

  @override
  String get chatRoleOwner => 'Владелец';

  @override
  String get chatRoleAdmin => 'Администратор';

  @override
  String get chatRoleEditor => 'Редактор';

  @override
  String get chatRoleDirect => 'Личный';

  @override
  String get chatRoleMember => 'Участник';

  @override
  String get chatRoleViewer => 'Читатель';

  @override
  String get chatRoleUnknown => 'Неизвестная роль';

  @override
  String get memberMutedBadge => 'Без права писать';

  @override
  String get memberBannedBadge => 'Заблокирован';

  @override
  String get memberOpenProfile => 'Открыть профиль';

  @override
  String get memberMessagePrivately => 'Написать лично';

  @override
  String memberKickConfirmTitle(String name) {
    return 'Исключить $name?';
  }

  @override
  String get memberKickConfirmBody =>
      'Доступ к этому чату пропадёт, но человека можно добавить снова.';

  @override
  String memberRoleChanged(String name, String role) {
    return '$name теперь $role';
  }

  @override
  String memberKicked(String name) {
    return '$name исключён';
  }

  @override
  String memberBannedToast(String name) {
    return '$name заблокирован';
  }

  @override
  String memberUnbanned(String name) {
    return 'Блокировка с $name снята';
  }

  @override
  String get memberActionFailed => 'Не получилось. Попробуйте ещё раз.';

  @override
  String get roleAssignHint => 'Назначать можно только роли ниже вашей.';

  @override
  String get roleOwnerTransferHint =>
      'Владельца нет в списке: API не позволяет передать чат другому.';

  @override
  String get banForHour => 'На час';

  @override
  String get banForDay => 'На день';

  @override
  String get banForWeek => 'На неделю';

  @override
  String get inviteMembersTitle => 'Добавить людей';

  @override
  String get inviteRoleLabel => 'Вступят как';

  @override
  String inviteRoomLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Место ещё для $count человека',
      many: 'Место ещё для $count человек',
      few: 'Место ещё для $count человек',
      one: 'Место ещё для $count человека',
      zero: 'Чат заполнен',
    );
    return '$_temp0';
  }

  @override
  String inviteChatFull(int limit) {
    return 'В этом чате $limit участников, и он заполнен.';
  }

  @override
  String inviteAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавить $count человека',
      many: 'Добавить $count человек',
      few: 'Добавить $count человек',
      one: 'Добавить $count человека',
    );
    return '$_temp0';
  }

  @override
  String inviteAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count человека добавлено',
      many: '$count человек добавлено',
      few: '$count человека добавлено',
      one: '$count человек добавлен',
    );
    return '$_temp0';
  }

  @override
  String inviteFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count человека не удалось добавить',
      many: '$count человек не удалось добавить',
      few: '$count человек не удалось добавить',
      one: '$count человека не удалось добавить',
    );
    return '$_temp0';
  }

  @override
  String get inviteSearchStart =>
      'Найдите людей по имени или @username и добавьте всех сразу.';

  @override
  String get inviteSelectionFull => 'Больше в этот чат не поместится.';

  @override
  String peopleSearchNoneFound(String query) {
    return 'По запросу «$query» никого нет';
  }

  @override
  String get peopleSearchHint =>
      'Поиск совпадает с любой частью имени или @username.';

  @override
  String get profileShareAction => 'Поделиться';

  @override
  String get profileShareCopied => 'Ссылка на профиль скопирована';

  @override
  String get profileBirthday => 'День рождения';

  @override
  String get profileEmptyTitle => 'Здесь пока пусто';

  @override
  String get profileEmptyHintSelf =>
      'Напишите пару слов о себе, чтобы люди понимали, с кем говорят.';

  @override
  String get profileEmptyHintOther => 'Этот человек не заполнил профиль.';

  @override
  String get profileAccount => 'Аккаунт';

  @override
  String get profileAccountNoEmail => 'Вы вошли';

  @override
  String get profilePhoto => 'Фото';

  @override
  String get profileNoPhoto => 'Фото пока нет';

  @override
  String get profileOpenLinkFailed => 'Не удалось открыть эту ссылку';

  @override
  String get profileContactCopied => 'Скопировано в буфер обмена';

  @override
  String get profileCopyAction => 'Копировать';

  @override
  String devicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count устройства',
      many: '$count устройств',
      few: '$count устройства',
      one: '$count устройство',
      zero: 'Устройств нет',
    );
    return '$_temp0';
  }

  @override
  String get changePhoto => 'Сменить фото';

  @override
  String get setPhoto => 'Выбрать фото';

  @override
  String get choosePhoto => 'Выберите фото';

  @override
  String get avatarCropTitle => 'Подвиньте и приблизьте';

  @override
  String get avatarCropHint =>
      'Перетаскивайте, чтобы двигать, сводите пальцы, чтобы масштабировать.';

  @override
  String get avatarCropConfirm => 'Использовать фото';

  @override
  String get avatarStagePreparing => 'Подготовка…';

  @override
  String get avatarStageUploading => 'Загрузка…';

  @override
  String get avatarStageConfirming => 'Почти готово…';

  @override
  String get avatarStageProcessing => 'Обрабатываем фото…';

  @override
  String get avatarStageDone => 'Фото обновлено';

  @override
  String get avatarProcessingFailed => 'Не удалось обновить фото';

  @override
  String get avatarProcessingFailedHint =>
      'Сервер не принял это изображение. Попробуйте другое.';

  @override
  String get avatarNotAnImage => 'Этот файл не изображение';

  @override
  String get avatarTooLarge =>
      'Это изображение слишком большое. Выберите поменьше.';

  @override
  String get avatarUnreadable => 'Не удалось открыть это изображение';

  @override
  String get profileEditDetails => 'Данные';

  @override
  String get profileEditLinks => 'Ссылки';

  @override
  String get profileEditLinksHint =>
      'Ссылки сохраняются сразу при добавлении или удалении, отдельно от формы ниже.';

  @override
  String get profileNoLinks => 'Ссылок пока нет';

  @override
  String get removeLink => 'Удалить ссылку';

  @override
  String get clearDateOfBirth => 'Очистить дату рождения';

  @override
  String get specializationHint => 'Чем вы занимаетесь, в нескольких словах';

  @override
  String bioCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String get profileSkillsHint => 'До 30 символов каждый';

  @override
  String get profileSaved => 'Профиль сохранён';

  @override
  String get discardChangesTitle => 'Отменить изменения?';

  @override
  String get discardChangesMessage => 'Правки этого профиля будут потеряны.';

  @override
  String get discardAction => 'Отменить';

  @override
  String get keepEditingAction => 'Продолжить правку';

  @override
  String get camera => 'Камера';

  @override
  String get loading => 'Загрузка…';

  @override
  String fieldTooLong(int max) {
    return 'Не больше $max символов';
  }

  @override
  String skillTooLong(String skill, int max) {
    return '«$skill» длиннее $max символов';
  }

  @override
  String callRoomName(String slug) {
    return 'Комната $slug';
  }

  @override
  String get callJoinExplanation =>
      'Звонок здесь — это комната: присоединитесь, и к вам сможет присоединиться любой из этого чата.';

  @override
  String get callNoIncomingNotice =>
      'Звонок при входящем вызове пока недоступен — сервер о них не сообщает.';

  @override
  String get callWaitingForOthers => 'Ждём, пока кто-нибудь присоединится…';

  @override
  String get callReconnecting => 'Переподключение…';

  @override
  String get callYou => 'Вы';

  @override
  String callParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
      zero: 'Здесь пока никого',
    );
    return '$_temp0';
  }

  @override
  String get callMicrophoneMute => 'Выключить микрофон';

  @override
  String get callMicrophoneUnmute => 'Включить микрофон';

  @override
  String get callCameraStart => 'Включить видео';

  @override
  String get callCameraStop => 'Выключить видео';

  @override
  String get callSpeakerOn => 'Динамик';

  @override
  String get callSpeakerOff => 'Разговорный динамик';

  @override
  String get callLayoutGrid => 'Сетка';

  @override
  String get callLayoutSpeaker => 'Крупно говорящего';

  @override
  String callPinParticipant(String name) {
    return 'Закрепить $name';
  }

  @override
  String callUnpinParticipant(String name) {
    return 'Открепить $name';
  }

  @override
  String get callMuteForEveryone => 'Выключить микрофон для всех';

  @override
  String get callUnmuteForEveryone => 'Разрешить говорить';

  @override
  String get callQualityExcellent => 'Отличное соединение';

  @override
  String get callQualityGood => 'Хорошее соединение';

  @override
  String get callQualityPoor => 'Слабое соединение';

  @override
  String get callQualityLost => 'Соединение потеряно';

  @override
  String get callMicrophonePermissionTitle =>
      'Разрешите ChatiX доступ к микрофону';

  @override
  String get callMicrophonePermissionBody =>
      'Остальные услышат вас, только если ChatiX может пользоваться микрофоном. Выключить его можно в любой момент.';

  @override
  String get callCameraPermissionTitle => 'Разрешите ChatiX доступ к камере';

  @override
  String get callCameraPermissionBody =>
      'Видео передаётся, только пока камера включена, и выключить её можно в любой момент.';

  @override
  String get callPermissionContinue => 'Продолжить';

  @override
  String get callPermissionNotNow => 'Не сейчас';

  @override
  String get callPermissionOpenSettings => 'Открыть настройки';

  @override
  String get callMicrophoneBlocked =>
      'Микрофон выключен: у ChatiX нет разрешения.';

  @override
  String get callCameraBlocked => 'Камера выключена: у ChatiX нет разрешения.';

  @override
  String get callSelfPreview => 'Ваша камера';

  @override
  String get callSelfPreviewHint => 'Перетащите, чтобы подвинуть';

  @override
  String get callShowControls => 'Показать управление звонком';

  @override
  String get callOngoingInChat => 'Вы в звонке в этом чате';

  @override
  String get callReturn => 'Вернуться';

  @override
  String callMiniPlayerLabel(String name) {
    return 'Звонок с $name';
  }

  @override
  String get callMinimize => 'Свернуть звонок';

  @override
  String get callDismiss => 'Закрыть';

  @override
  String get notificationNewMessage => 'Новое сообщение';

  @override
  String get notificationReplyHint => 'Сообщение';

  @override
  String get notificationReplyFailed => 'Ваш ответ не отправлен';

  @override
  String get notificationActionFailed => 'Не удалось это сделать';

  @override
  String get notificationSettingsTitle => 'Уведомления';

  @override
  String get notificationSoundTitle => 'Звук';

  @override
  String get notificationSoundSubtitle =>
      'Проигрывать звук, когда что-то приходит';

  @override
  String get notificationVibrationTitle => 'Вибрация';

  @override
  String get notificationVibrationSubtitle =>
      'Вибрировать, когда что-то приходит';

  @override
  String get notificationPreviewTitle => 'Превью сообщения';

  @override
  String get notificationPreviewSubtitle => 'Показывать, кто написал и что';

  @override
  String get quietHoursTitle => 'Тихие часы';

  @override
  String get quietHoursSubtitle => 'Уведомления приходят, но без звука';

  @override
  String get quietHoursFrom => 'С';

  @override
  String get quietHoursTo => 'До';

  @override
  String get chatNotificationsTitle => 'Исключения по чатам';

  @override
  String get chatNotificationsEmpty => 'Исключений пока нет';

  @override
  String get chatNotificationsEmptyHint =>
      'Все чаты следуют настройкам выше. Изменить можно изнутри чата.';

  @override
  String get chatNotificationsReset => 'Сбросить все';

  @override
  String get chatNotificationProfileTitle => 'Уведомления из этого чата';

  @override
  String get chatNotificationProfileAll => 'Все сообщения';

  @override
  String get chatNotificationProfileMentions => 'Только упоминания';

  @override
  String get chatNotificationProfileOff => 'Ничего';

  @override
  String get notificationPermissionOffTitle => 'Уведомления выключены';

  @override
  String get notificationPermissionOffHint =>
      'Ничего из того, что ниже, до вас не дойдёт, пока вы не разрешите уведомления в системных настройках.';

  @override
  String get notificationsEmptyTitle => 'Уведомлений пока нет';

  @override
  String get notificationsEmptyMessage =>
      'Приглашения, упоминания и сообщения появятся здесь.';

  @override
  String get notificationsEmptyUnread => 'Непрочитанного нет';

  @override
  String get notificationsEmptyRead => 'Прочитанного пока нет';

  @override
  String get notificationsEmptyFilterHint =>
      'Переключите фильтр на «Все», чтобы увидеть всё.';

  @override
  String get timeJustNow => 'Только что';

  @override
  String notificationsMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count уведомления отмечено прочитанными',
      many: '$count уведомлений отмечено прочитанными',
      few: '$count уведомления отмечено прочитанными',
      one: '$count уведомление отмечено прочитанным',
      zero: 'Непрочитанного не было',
    );
    return '$_temp0';
  }

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мин назад',
      one: '1 мин назад',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ч назад',
      one: '1 ч назад',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня назад',
      many: '$count дней назад',
      few: '$count дня назад',
      one: 'Вчера',
    );
    return '$_temp0';
  }

  @override
  String get appearanceTitle => 'Оформление';

  @override
  String get appearanceHint => 'Тема, акцент, фон, пузыри и медиа';

  @override
  String get appearancePreview => 'Предпросмотр';

  @override
  String get previewIncomingMessage => 'Всё здесь построено на вашем акценте.';

  @override
  String get previewOutgoingMessage => 'Никаких картинок в фоне. Только код.';

  @override
  String get previewIncomingReply => 'Двигайте ручки и смотрите.';

  @override
  String get amoledTitle => 'Чёрная (AMOLED)';

  @override
  String get amoledHint =>
      'Настоящий чёрный фон. На OLED-экране чёрные пиксели не тратят энергию вовсе.';

  @override
  String get accentFromAvatar => 'Взять цвет с моего фото';

  @override
  String get accentFromAvatarApplied => 'Акцент взят с вашего фото.';

  @override
  String get accentFromAvatarEmpty =>
      'На вашем фото нет цвета, который можно взять — оно читается как серое.';

  @override
  String get accentFromAvatarMissing => 'Сначала добавьте фото профиля.';

  @override
  String get accentFromAvatarFailed =>
      'Не удалось прочитать ваше фото. Попробуйте снова.';

  @override
  String get accentCustom => 'Ваш цвет';

  @override
  String get wallpaperNebula => 'Туманность';

  @override
  String get wallpaperRibbons => 'Ленты';

  @override
  String get wallpaperPrism => 'Призма';

  @override
  String get wallpaperHalo => 'Гало';

  @override
  String get wallpaperDunes => 'Дюны';

  @override
  String get wallpaperIntensity => 'Насыщенность';

  @override
  String get wallpaperPattern => 'Узор';

  @override
  String get appearanceDensity => 'Плотность';

  @override
  String get appearanceDensityHint =>
      'Сколько места занимают строки и пузыри сообщений.';

  @override
  String get textSizeHint => 'Применяется поверх системного размера текста.';

  @override
  String get bubbleShape => 'Форма пузыря';

  @override
  String get bubbleCorners => 'Углы';

  @override
  String get bubbleAnchor => 'Угол-хвостик';

  @override
  String get bubbleAnchorHint =>
      'Подтягивает последний пузырь серии к стороне отправителя, чтобы он указывал на того, кто написал.';

  @override
  String get mediaSectionTitle => 'Медиа';

  @override
  String get autoDownload => 'Автозагрузка';

  @override
  String get autoDownloadHint =>
      'Какие вложения скачиваются до того, как вы их откроете.';

  @override
  String get autoDownloadPhotos => 'Фото';

  @override
  String get autoDownloadVideos => 'Видео';

  @override
  String get autoDownloadFiles => 'Файлы';

  @override
  String get autoDownloadVoice => 'Голосовые сообщения';

  @override
  String get autoDownloadWifi => 'Wi-Fi';

  @override
  String get autoDownloadMobile => 'Мобильный интернет';

  @override
  String get autoDownloadNever => 'Никогда';

  @override
  String get cacheLimit => 'Лимит кэша';

  @override
  String get cacheLimitHint =>
      'Скачанные вложения хранятся, пока не превысят лимит, а потом первыми удаляются самые старые.';

  @override
  String get cacheEmpty => 'В кэше пока ничего нет';

  @override
  String get cacheClear => 'Очистить кэш';

  @override
  String get cacheMeasuring => 'Считаем…';

  @override
  String get appearanceReduceMotionNotice =>
      'Система просит уменьшить анимацию, поэтому здесь ничего не движется.';

  @override
  String get appearanceHighContrastNotice =>
      'Включён высокий контраст, поэтому фоны рисуются приглушённо, чтобы текст читался.';

  @override
  String cacheInUse(String size) {
    return 'Занято $size';
  }

  @override
  String cacheCleared(String size) {
    return 'Освобождено $size';
  }

  @override
  String sizeMegabytes(String value) {
    return '$value МБ';
  }

  @override
  String sizeGigabytes(String value) {
    return '$value ГБ';
  }

  @override
  String get attachmentTapToDownload => 'Нажмите, чтобы скачать';

  @override
  String get welcomeHeadline => 'Добро пожаловать в ChatiX';

  @override
  String get welcomeTagline => 'Сообщения, которые за вами успевают.';

  @override
  String get welcomeGetStarted => 'Начать';

  @override
  String get welcomeSignIn => 'У меня уже есть аккаунт';

  @override
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingDone => 'Создать аккаунт';

  @override
  String get onboardingRealtimeTitle => 'Всё в реальном времени';

  @override
  String get onboardingRealtimeBody =>
      'Сообщения, правки и реакции приходят в тот же момент — а приложение открывается на том разговоре, где вы его оставили, ещё до ответа сети.';

  @override
  String get onboardingTogetherTitle => 'Чаты, группы, каналы, звонки';

  @override
  String get onboardingTogetherBody =>
      'Один на один, группа на пятьсот человек или канал для всех — и голосовой или видеозвонок всегда в одно нажатие.';

  @override
  String get onboardingPrivacyTitle => 'Только ваше';

  @override
  String get onboardingPrivacyBody =>
      'Смотрите все устройства, где выполнен вход, и завершайте любое из них, закрывайте приложение отпечатком пальца и держите файлы на телефоне, пока не отправите.';

  @override
  String onboardingPageOf(int current, int total) {
    return 'Страница $current из $total';
  }

  @override
  String get loginHeadline => 'С возвращением';

  @override
  String get loginSubtitle => 'Войдите, чтобы продолжить разговор.';

  @override
  String get registerHeadline => 'Создайте аккаунт';

  @override
  String get registerSubtitle => 'Это займёт около минуты.';

  @override
  String get authOrContinueWith => 'или продолжить через';

  @override
  String get authNoAccount => 'Нет аккаунта?';

  @override
  String get authHaveAccount => 'Уже есть аккаунт?';

  @override
  String get authErrorWrongLoginData => 'Неверное имя пользователя или пароль.';

  @override
  String get authErrorEmailNotConfirmed => 'Подтвердите email перед входом.';

  @override
  String authErrorEmailNotConfirmedFor(String email) {
    return 'Подтвердите $email перед входом.';
  }

  @override
  String get authResendEmail => 'Отправить письмо ещё раз';

  @override
  String get authErrorTooManyAttempts =>
      'Слишком много попыток. Подождите минуту и попробуйте снова.';

  @override
  String get authErrorDuplicateUsername => 'Это имя пользователя уже занято.';

  @override
  String get authErrorDuplicateEmail => 'Аккаунт с этим email уже существует.';

  @override
  String authErrorDuplicateField(String field) {
    return '$field уже используется.';
  }

  @override
  String get authErrorPasswordMismatch => 'Пароли не совпадают.';

  @override
  String get authErrorInvalidCode =>
      'Этот код больше не действует. Запросите новый.';

  @override
  String get authErrorUserNotFound => 'Аккаунт с такими данными не найден.';

  @override
  String get authErrorOffline =>
      'Нет соединения. Проверьте сеть и попробуйте снова.';

  @override
  String get authErrorGeneric => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get passwordStrengthLabel => 'Надёжность пароля';

  @override
  String get passwordStrengthWeak => 'Слабый';

  @override
  String get passwordStrengthFair => 'Так себе';

  @override
  String get passwordStrengthGood => 'Хороший';

  @override
  String get passwordStrengthStrong => 'Надёжный';

  @override
  String get passwordShow => 'Показать пароль';

  @override
  String get passwordHide => 'Скрыть пароль';

  @override
  String get verifyEmailHeadline => 'Проверьте почту';

  @override
  String verifyEmailSentTo(String email) {
    return 'Мы отправили код подтверждения на $email.';
  }

  @override
  String get verifyEmailSentToYou => 'Мы отправили вам код подтверждения.';

  @override
  String get verifyEmailClipboardHint =>
      'Скопируйте код из письма — ChatiX подхватит его, как только вы вернётесь.';

  @override
  String get verifyEmailCodeFromClipboard => 'Код взят из буфера обмена';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'Новое письмо можно запросить через $seconds с';
  }

  @override
  String get verifyEmailWrongAddress => 'Не тот адрес?';

  @override
  String get verifyEmailChangeAddress => 'Указать другой';

  @override
  String get biometricUnlockTitle => 'Разблокировка по биометрии';

  @override
  String get biometricUnlockSubtitle =>
      'Запрашивать отпечаток пальца или лицо при открытии ChatiX.';

  @override
  String get biometricUnlockUnavailable =>
      'На этом устройстве биометрия не настроена.';

  @override
  String get biometricUnlockReason => 'Разблокировать ChatiX';

  @override
  String get biometricUnlockLockedTitle => 'ChatiX заблокирован';

  @override
  String get biometricUnlockLockedBody =>
      'Разблокируйте, чтобы вернуться к чатам.';

  @override
  String get biometricUnlockAction => 'Разблокировать';

  @override
  String get biometricUnlockFailed => 'Проверка не прошла. Попробуйте снова.';

  @override
  String get biometricUnlockLockedOut =>
      'Система заблокировала биометрию после слишком многих попыток.';

  @override
  String get biometricUnlockNotEnrolled =>
      'На этом устройстве не добавлен ни отпечаток, ни лицо.';

  @override
  String get biometricUnlockEnableFailed => 'Не удалось включить биометрию.';

  @override
  String get settingsSecuritySection => 'Безопасность';

  @override
  String get settingsAccountSection => 'Аккаунт';

  @override
  String get logoutConfirmTitle => 'Выйти?';

  @override
  String get logoutConfirmBody =>
      'Это устройство забудет ваши сообщения, черновики и скачанные файлы. Аккаунт останется как есть.';

  @override
  String get logoutAction => 'Выйти';

  @override
  String get logoutFailed => 'Не удалось выйти. Попробуйте снова.';

  @override
  String get logoutInProgress => 'Выходим…';

  @override
  String get appearanceFeel => 'Ощущения';

  @override
  String get appearanceHaptics => 'Тактильный отклик';

  @override
  String get appearanceHapticsHint =>
      'Короткие вибрации, когда сообщение уходит, реакция ставится или жест срабатывает. Системная настройка вибрации при этом продолжает действовать.';

  @override
  String get failureGeneric => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get failureRateLimited =>
      'Слишком много попыток. Подождите минуту и попробуйте снова.';

  @override
  String get failureNoConnection =>
      'Нет соединения с интернетом. Проверьте сеть и попробуйте снова.';

  @override
  String get failureTimeout =>
      'Сервер слишком долго не отвечает. Попробуйте ещё раз.';

  @override
  String get failureInsecureSessionCookie =>
      'Сервер прислал небезопасную cookie входа, поэтому сессия не сохранена. Это настройка сервера — обратитесь в поддержку.';

  @override
  String get apiErrorSessionEnded => 'Сессия завершена. Войдите снова.';

  @override
  String get apiErrorSessionExpired => 'Срок сессии истёк. Войдите снова.';

  @override
  String get apiErrorSessionInvalid =>
      'Сессия больше недействительна. Войдите снова.';

  @override
  String get apiErrorSessionSignedOut => 'Из этой сессии вышли. Войдите снова.';

  @override
  String get apiErrorAccessDenied => 'У вас нет прав на это действие.';

  @override
  String get apiErrorValidation =>
      'Некоторые данные заполнены неверно. Проверьте и попробуйте снова.';

  @override
  String get apiErrorNotFoundGeneric =>
      'Не удалось это найти — возможно, оно удалено.';

  @override
  String get apiErrorTooLongGeneric =>
      'Значение слишком длинное. Сократите его.';

  @override
  String get apiErrorLimitExceededGeneric =>
      'Достигнут лимит, поэтому действие недоступно.';

  @override
  String get apiErrorWrongLoginData => 'Неверное имя пользователя или пароль.';

  @override
  String get apiErrorPasswordMismatch => 'Пароли не совпадают.';

  @override
  String get apiErrorDuplicateUser =>
      'Такое имя пользователя или email уже заняты.';

  @override
  String get apiErrorEmailNotConfirmed => 'Подтвердите email перед входом.';

  @override
  String get apiErrorOauthProviderUnsupported =>
      'Этот способ входа не поддерживается.';

  @override
  String get apiErrorOauthStateNotFound =>
      'Попытка входа устарела. Попробуйте ещё раз.';

  @override
  String get apiErrorOauthLinkedAnotherUser =>
      'Этот аккаунт уже привязан к другому пользователю.';

  @override
  String get apiErrorProfileExists => 'У вас уже есть профиль.';

  @override
  String get apiErrorNotChatMember => 'Вы не участник этого чата.';

  @override
  String get apiErrorAlreadyChatMember => 'Этот человек уже в чате.';

  @override
  String get apiErrorInvalidChatRole => 'Недопустимая роль в чате.';

  @override
  String get apiErrorDirectChatExists =>
      'У вас уже есть личный чат с этим человеком.';

  @override
  String get apiErrorMessageTooLong =>
      'Сообщение слишком длинное. Сократите его.';

  @override
  String get apiErrorInvalidMessage => 'Такое сообщение нельзя отправить.';

  @override
  String get apiErrorSlowModeLimit =>
      'Включён медленный режим — подождите перед следующим сообщением.';

  @override
  String get apiErrorSlowModeOutOfRange =>
      'Медленный режим должен быть от 0 секунд до 24 часов.';

  @override
  String get apiErrorAttachmentLimitExceeded =>
      'Слишком много вложений в одном сообщении.';

  @override
  String get apiErrorAttachmentNotFound => 'Это вложение больше недоступно.';

  @override
  String get apiErrorAttachmentValidation =>
      'Этот файл нельзя прикрепить — проверьте тип и размер.';

  @override
  String get apiErrorEmptyAttachmentUpload => 'Выберите файл для отправки.';

  @override
  String get apiErrorInvalidUploadToken =>
      'Срок загрузки истёк. Прикрепите файл заново.';

  @override
  String get apiErrorAvatarNotImage => 'Аватар должен быть изображением.';

  @override
  String get apiErrorActiveCallExists => 'В этом чате уже идёт звонок.';

  @override
  String get apiErrorNoActiveCall => 'В этом чате нет активного звонка.';

  @override
  String get apiErrorLivekitUnauthorized =>
      'Вы не можете присоединиться к этому звонку.';

  @override
  String get apiErrorLivekitError => 'Сервис звонков сейчас недоступен.';

  @override
  String get apiErrorInvalidReaction =>
      'Этот эмодзи нельзя использовать как реакцию.';

  @override
  String get apiErrorReactionNotAllowed =>
      'Эта реакция не разрешена в этом чате.';

  @override
  String get apiErrorReactionsDisabled => 'Реакции отключены в этом чате.';

  @override
  String get apiErrorTooManyReactions => 'Больше реакций добавить нельзя.';

  @override
  String get apiErrorMaxLimitCursor =>
      'Слишком много чатов возобновлено за раз.';

  @override
  String a11yMessageFrom(String author, String time) {
    return 'Сообщение от $author, $time';
  }

  @override
  String a11yMessageMine(String time) {
    return 'Ваше сообщение, $time';
  }

  @override
  String get a11ySystemMessage => 'Системное сообщение';

  @override
  String a11yReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count реакции',
      many: '$count реакций',
      few: '$count реакции',
      one: '$count реакция',
    );
    return '$_temp0';
  }

  @override
  String get a11yReactionYours => 'включая вашу';

  @override
  String get a11yMessageActionsHint => 'показать действия с сообщением';

  @override
  String a11yMessageAttachmentsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вложения',
      many: '$count вложений',
      few: '$count вложения',
      one: '$count вложение',
    );
    return '$_temp0';
  }

  @override
  String get reviewPromptTitle => 'Нравится приложение?';

  @override
  String get reviewPromptBody => 'Поделитесь с нами своим мнением?';

  @override
  String get reviewPromptDecline => 'Не сейчас';

  @override
  String get reviewPromptAccept => 'Конечно';

  @override
  String get feedbackTitle => 'Ваше мнение важно';

  @override
  String get feedbackBody =>
      'Расскажите, что вы думаете о приложении. Если оно вам нравится, отзыв в магазине приложений очень нам поможет.';

  @override
  String get feedbackHint => 'Напишите отзыв здесь';

  @override
  String get feedbackSubmit => 'Отправить';

  @override
  String get updateRequiredTitle => 'Нужно обновление';

  @override
  String get updateAvailableTitle => 'Доступно обновление';

  @override
  String updateRequiredBody(String version) {
    return 'Для работы ChatiX нужна версия $version.';
  }

  @override
  String updateAvailableBody(String version) {
    return 'Доступна версия $version.';
  }

  @override
  String get updateWhatsNew => 'Что нового';

  @override
  String get updateLater => 'Позже';

  @override
  String get updateNow => 'Обновить сейчас';

  @override
  String get updateAction => 'Обновить';

  @override
  String sizeBytes(String value) {
    return '$value Б';
  }

  @override
  String sizeKilobytes(String value) {
    return '$value КБ';
  }

  @override
  String attachmentDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get attachmentDownload => 'Скачать';

  @override
  String get attachmentDownloadFailed => 'Не удалось скачать файл';

  @override
  String get attachmentShareFailed => 'Не удалось поделиться файлом';

  @override
  String get attachmentRevealFailed => 'Не удалось открыть папку';

  @override
  String get messageSaveFile => 'Сохранить';

  @override
  String get messageShareFile => 'Поделиться';

  @override
  String get messageShowInFolder => 'Показать в папке';

  @override
  String get bubbleFill => 'Ваши пузыри';

  @override
  String get bubbleFillGradient => 'Градиент';

  @override
  String get bubbleFillSolid => 'Сплошной цвет';
}
