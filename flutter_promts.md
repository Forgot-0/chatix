Выполни все промты по порядку в одном ответе проверяй не реализован ли уже промт и если он полностью готов пропускай его и переходи к следующему. Если промт реализован частично то доведи его до полной реализации.
https://github.com/Forgot-0/social_github/tree/main

## Промпт 4 — Реакции на сообщения (новая фича)

```
Контекст: api-docs.md §6.7 — целый новый раздел, реализованный на бэкенде,
но полностью отсутствующий в chatix. Нужна фича с нуля по существующему в
модуле паттерну Clean Architecture.

Сначала прочитай api-docs.md §6.7 целиком (эндпоинты, семантика "одна
реакция на пользователя", DTO, лимиты/ошибки, WS-событие), а для стиля —
как устроены соседние фичи (chat_rest_data_source.dart, chat_repository.dart,
use-case файлы, message_bubble.dart) и core/websocket/ws_event.dart +
ws_event_parser.dart (прочитай докстринг файла целиком — там объяснено,
почему WSEvent это sealed-иерархия, а не freezed union).

Задача:
1. Domain: ReactionSummaryEntity (emoji, count, reactedByMe),
   ReactionUserEntity (userId, emoji), MessageReactionsEntity (messageId,
   summaries, emoji, users, hasNext, nextUserId) — по MessageReactionsDTO
   из §6.7.3. ⚠️ Модель single-choice: у пользователя ровно одна реакция на
   сообщение (UniqueConstraint(message_id, user_id) на бэкенде) — не
   проектируй под "набор эмодзи от одного юзера".
2. Data + repository + 3 use-case'а под 3 REST-эндпоинта §6.7.1: PUT/DELETE
   .../reactions/{emoji}/, GET .../reactions/. ⚠️ {emoji} — path-параметр,
   обязательно URL-encode перед подстановкой в путь (эмодзи — многобайтовый
   unicode).
3. WS: добавь ReactionUpdated в sealed-иерархию ws_event.dart (payload:
   messageId, emoji, count — АБСОЛЮТНОЕ значение, не дельта; changedBy) и в
   парсер — тип на проводе "chats.message.reaction_updated" (НЕ короткий
   алиас, в отличие от других событий типа "new_message"). Добавление
   нового sealed-подкласса обязано сломать компиляцию во всех exhaustive
   switch по WSEvent — пройдись по ним и добавь обработку, найди все места
   через ошибки компилятора, а не через grep.
4. Обработка в проекции чата (там же, где сейчас применяются
   MessageEdited/MessageDeleted к локальному состоянию сообщения): найти
   сообщение по messageId, найти summary по emoji, выставить count в
   абсолютное значение из payload, если count == 0 — убрать чипс; если
   changedBy == текущий пользователь — не трогать локальный reactedByMe (он
   уже выставлен оптимистично при отправке PUT/DELETE).
5. UI в message_bubble.dart: чипсы реакций под сообщением (тап по своей —
   toggle через DELETE, тап по чужой — PUT со своим эмодзи, long-press —
   шторка "кто поставил" через GET ?emoji=). Оптимистичный UI: при смене
   эмодзи сразу снимать подсветку со старого чипса локально, не дожидаясь
   WS-события.
6. ⚠️ MessageDTO/MessageEntity реакций не содержит — сводку нужно грузить
   отдельным запросом при открытии чата/истории и дальше держать в
   актуальном состоянии через WS-событие.

Прогони flutter analyze — все места, где switch по WSEvent был исчерпывающим,
должны либо явно обработать ReactionUpdated, либо дать ошибку компиляции —
это и есть страховка, ради которой иерархия sealed.
```

---

## Промпт 5 — Мелкие расхождения и багфиксы

```
Прочитай api-docs.md §6.2, §6.4, §6.6 и:
lib/features/chat/domain/entities/message_entity.dart (forwardedFromAuthorId),
lib/features/chat/data/models/message_model.dart,
lib/features/chat/domain/entities/call_token_entity.dart,
lib/features/chat/domain/usecases/create_chat_use_case.dart и другие места
обработки кодов ошибок бэкенда для чатов.

Пройдись по расхождениям, для каждого явно реши, что делать (если решил не
чинить — напиши почему в комментарии рядом, не пропускай молча):

1. forwardedFromAuthorId: по api-docs теперь number, а не string (в
   message_entity.dart сейчас докстринг объясняет это поле как "String?
   намеренно, так на проводе" — расхождение с текущим api-docs.md). Поменяй
   тип на int?, обнови докстринг и модель + .g.dart.
2. Добавь обработку кода SLOW_MODE_OUT_OF_RANGE (400) при создании/
   обновлении чата и TOO_LONG_CHAT_ROLE_NAME (400) при добавлении участника
   — туда же, где сейчас обрабатываются соседние коды типа
   MEMBER_LIMIT_EXCEEDED/DIRECT_CHAT_EXISTS.
3. call_token_entity.dart: реши, нужен ли эквивалент LiveKitParticipantsDTO
   (identity, name, state, joinedAt) — сначала проверь, откуда сейчас берётся
   список участников звонка в call_screen.dart (вероятно, из самого LiveKit
   SDK, а не с бэкенда), и заводи модель только если она реально нужна
   REST-слою, не дублируй то, что и так приходит из livekit_client.
4. Задокументируй (в докстринге join_call_use_case.dart или рядом)
   ROOM_TOKEN_TTL=3600 и ROOM_MAX_PARTICIPANTS=100, и то, что эндпоинта
   "завершить звонок" в REST нет — выход только через LiveKit SDK disconnect.
5. Проверь get_attachment_download_url_use_case.dart/использование в UI —
   presigned url живёт 300 секунд, кэшировать нужно скачанный файл по
   s3_key, а не сам url; убедись, что url нигде не кэшируется дольше своего
   urlExpiresIn.
```

---

## Промпт 6 — Финальный прогон (последним)

```
Пройдись по lib/features/chat и lib/core/websocket:
1. Проверь докстринги, которые явно описывают старое поведение как факт
   (после промптов 1-5 точно устарели: "the DTO carries no username/avatar"
   в chat_member_entity.dart, "String? намеренно" про forwardedFromAuthorId)
   — поправь текст под новую реальность, не удаляя объяснения "почему",
   если они ещё верны.
2. dart run build_runner build --delete-conflicting-outputs — все .g.dart
   должны быть синхронны с моделями после промптов 1-5.
3. flutter analyze — ноль новых warning/error.
4. flutter test — существующие тесты в test/features/chat не должны
   ломаться логически; если тест ломается из-за смены формы DTO (а не
   поведения) — поправь тест под новую структуру, не откатывай изменения.
5. Сводка: какие разделы api-docs.md теперь полностью покрыты кодом, а что
   осталось TODO (например, запись голосовых/видео-кружков с устройства,
   если отложили в Промпте 3) — списком с путями к файлам и номерами
   разделов api-docs.md.
```

---

# Часть 2 — Telegram-like UX (найдено ручной сверкой кода)

В `chatix` уже есть `flutter_promts.md` — 10 промптов на визуальный редизайн
(тема, форма пузырей, composer, нав-шелл, авторизация, профиль/настройки,
анимации). Он полезен, но чисто визуальный. Ниже — то, что визуальным
редизайном не решается: реальные функциональные дыры, которые я нашёл, читая
код (`create_chat_screen.dart`, `chat_members_screen.dart`,
`chat_detail_provider.dart`, `profile_screen.dart`, `message_bubble.dart`).
Если ещё не гонял `flutter_promts.md` — его тоже стоит прогнать, но это не
блокирует промпты ниже, они не пересекаются по файлам.

Порядок внутри части 2 не строгий, кроме того, что Промпт 12 (финальный
прогон) — последний. Промпт 7 логично первым, раз это исходный запрос.

## Промпт 7 — Выбор участников по username вместо голого ID

```
Контекст: сейчас и создание чата, и добавление участника требуют вручную
вводить числовой user_id — это плохой UX и совсем не похоже на Telegram,
где начинаешь печатать имя/username и видишь живые подсказки. В проекте
уже есть рабочий поиск профилей по username: GetProfilesUseCase.execute(
username: ...) (lib/features/profile/domain/usecases/get_profiles_use_case.dart)
и profileListProvider/ProfileListController.search(username: ...)
(lib/features/profile/presentation/providers/profile_list_provider.dart) —
эндпоинт GET /profiles/ публичный (api-docs §4.2), сейчас он используется в
ProfilesListScreen только с фильтром displayName, но параметр username уже
поддержан на всех уровнях (use case → repository → provider), просто никто
его не вызывает.

Точки, которые нужно переделать — обе сейчас принимают голый числовой ID:
- lib/features/chat/presentation/screens/create_chat_screen.dart —
  _memberIdsController: TextField с keyboardType: TextInputType.number,
  парсится через .split(',').map(int.tryParse) в геттере _memberIds.
- lib/features/chat/presentation/screens/chat_members_screen.dart —
  класс _AddMemberDialog, тоже TextField(keyboardType: TextInputType.number)
  с int.tryParse(_controller.text).

Задача:
1. Собери переиспользуемый виджет для поиска пользователя по username —
   например lib/features/profile/presentation/widgets/user_search_field.dart:
   TextField с debounce (~300 мс, Timer, чтобы не долбить GET /profiles/ на
   каждое нажатие клавиши) поверх profileListProvider.search(username: ...),
   с выпадающим списком результатов (аватар + displayName + @username через
   ProfileAvatar, который уже используется в ProfilesListScreen), и колбэком
   onSelected(ProfileEntity). Пустой ввод — список сворачивается, ничего не
   грузим.
2. Для множественного выбора (create_chat_screen.dart, группа/канал — можно
   выбрать несколько участников) — обёртка над этим полем, которая после
   выбора добавляет пользователя в список "чипсов" сверху (аватар + имя +
   крестик убрать), очищает поле поиска и не даёт выбрать одного и того же
   пользователя дважды. Замени _memberIdsController и весь текущий геттер
   _memberIds на List<ProfileEntity> _selectedMembers, откуда memberIds
   вычисляется как _selectedMembers.map((p) => p.id).toList() — вся
   остальная логика _submit (direct-чат = ровно один участник, лимит
   maxInitialMembers и т.д.) не меняется, меняется только источник id.
3. Для одиночного выбора (chat_members_screen.dart, _AddMemberDialog) —
   тот же виджет без чипсов: выбор в списке сразу закрывает диалог и
   возвращает выбранный ProfileEntity.id, как раньше возвращался int из
   TextField.
4. Не удаляй сам факт, что addMember/createChat в итоге получают int
   user_id — с бэкендом ничего не меняется, меняется только то, как этот id
   находится в UI.
5. (Опционально, отдельно, не обязательно в этом промпте) В
   lib/features/project/presentation/widgets/project_member_management.dart
   есть точно такой же паттерн голого TextInputType.number для user id —
   если после этого промпта останется время, вынеси user_search_field.dart
   так, чтобы он не тянул зависимости от chat/project feature (сам виджет
   и так живёт в profile feature, куда оба фичи уже имеют доступ), и
   переиспользуй его там же для единообразия — но это не блокер для чата.

Покажи, как теперь выглядит create_chat_screen.dart и _AddMemberDialog —
и что происходит, если поиск ничего не находит (пустой стейт, не пустой
экран).
```

## Промпт 8 — Кнопка «Написать» на экране профиля

```
Контекст: сейчас единственный способ начать личный чат с человеком — это
экран создания чата с ручным вводом ID (или, после Промпта 7, с поиском по
username) — но в Telegram чат чаще всего стартуют прямо с экрана профиля
кнопкой "Написать". В chatix на lib/features/profile/presentation/screens/
profile_screen.dart такой кнопки нет вообще (grep по "Message"/"chat" в
файле — пусто).

Задача:
1. На profile_screen.dart добавь кнопку (FAB или AppBar action) "Написать" /
   "Message" — видима только если открытый профиль не свой собственный
   (сравни profile.id с текущим userId, как это уже делается в canEdit-
   проверке того же экрана).
2. По нажатию — вызови createChatUseCaseProvider с chatType: ChatType.direct,
   memberIds: [profile.id] (тот же use case, что использует
   create_chat_screen.dart) и перейди на ChatDetailRoute(chat.id).
3. ⚠️ Обработай 409 DIRECT_CHAT_EXISTS так же, как это уже сделано в
   create_chat_screen.dart._existingDirectChatId — открыть существующий чат
   вместо ошибки. Не дублируй этот метод копипастой: вынеси его в общее
   место (например статическую функцию в create_chat_use_case.dart рядом с
   самим use case, или в core/error/) и используй из обоих экранов.

Не трогай саму форму создания группового чата — это только про direct-чат
с одним конкретным человеком, которого пользователь уже смотрит.
```

## Промпт 9 — Мультивыбор сообщений (массовый форвард/удаление)

```
Контекст: у message_bubble.dart уже есть long-press → showModalBottomSheet
с Reply/Forward/Edit/Delete на ОДНО сообщение (_showActions). В Telegram
long-press также включает режим множественного выбора — отметить несколько
сообщений и переслать/удалить их разом. Сейчас такого режима нет вообще.

Прочитай lib/features/chat/presentation/widgets/message_bubble.dart
(_showActions, колбэки onReply/onForward/onEdit/onDelete, как они приходят
из chat_detail_screen.dart) и lib/features/chat/domain/usecases/
forward_message_use_case.dart, delete_message_use_case.dart — оба берут
ОДИН message_id за вызов, отдельного bulk-эндпоинта на бэкенде нет и в
api-docs.md не описан.

Задача:
1. В _showActions добавь пункт "Select" ("Выбрать") — включает режим
   мультивыбора на экране чата (состояние: Set<String> selectedMessageIds
   в chat_detail_provider.dart или в локальном UI-state экрана — выбери
   то, что аккуратнее ложится на существующую архитектуру провайдера,
   реши сам и объясни выбор).
2. В режиме выбора: тап по сообщению переключает чекбокс вместо обычного
   действия, в AppBar — счётчик выбранных + кнопки Forward/Delete
   (аналог общей "шапки выбора" в Telegram), кнопка "Отмена" сбрасывает
   режим.
3. Массовый Forward и массовый Delete — НЕ выдумывай bulk-эндпоинт на
   бэкенде (в api-docs его нет): выполни как серию последовательных
   вызовов forwardMessageUseCase/deleteMessageUseCase по одному на каждый
   выбранный id, с индикатором прогресса ("3 из 7") и общим отчётом об
   ошибках в конце (если часть сообщений не удалилась/не переслалась —
   покажи, какие именно, не проглатывай молча).
4. Reply/Edit скрой в режиме мультивыбора (они не имеют смысла для
   нескольких сообщений сразу) — оставь только Forward/Delete/Cancel.

Не трогай одиночный режим (_showActions без выбора) — он остаётся как есть,
мультивыбор — это отдельный режим поверх него.
```

## Промпт 10 — Read receipts (галочки статуса прочтения)

```
Контекст: код уже прямо документирует эту дыру. В
lib/features/chat/presentation/providers/chat_detail_provider.dart, кейс
`case MessagesRead():` содержит комментарий: "Nothing on this screen
renders it yet (per-message read ticks would need it)". WS-событие
messages_read (api-docs §7.4) приходит на КАЖДОЕ прочтение любым
участником — {seq, readerId} — и сейчас просто отбрасывается.

Задача:
1. В состоянии chat_detail_provider.dart заведи Map<int, int> — последний
   прочитанный seq на каждого readerId (кроме себя), обновляемую по
   каждому MessagesRead-событию вместо текущего `break;`. Это состояние
   существует только в рамках открытой сессии экрана (WS отдаёт дельты, а
   не снапшот чужих read-курсоров при входе в чат — сверься с api-docs §6.2/
   §6.3/§7, там нет эндпоинта "чей ещё последний прочитанный seq" кроме
   собственного ChatDTO.last_read) — так и задокументируй как известное
   ограничение: галочки станут точными только после того, как второй
   участник прочитает что-то, пока экран открыт, а не сразу при входе.
2. Для direct-чата (ChatType.direct, ровно 2 участника) — это готовая
   Telegram-семантика: single check ("отправлено") пока
   peerLastReadSeq < message.seq, double check ("прочитано") когда
   peerLastReadSeq >= message.seq. Отрисуй в message_bubble.dart рядом со
   временем, только у СВОИХ сообщений (у чужих тиков в Telegram нет).
3. Для группы/супергруппы/канала не пытайся показать "прочитано всеми N
   участниками" в этом промпте — это отдельная фича с другой семантикой
   (Telegram считает по каждому), просто оставь одинарную галочку
   "отправлено" без попытки агрегировать чужие read-курсоры по всем
   членам — не выдумывай агрегацию, которую бэкенд не считает за тебя.
4. Не путай это с MarkReadRequest/markRead (api-docs) — это НАШ собственный
   read-курсор, отправляемый на бэкенд; здесь речь только про отображение
   ЧУЖОГО прочтения, которое приходит обратно по WS.

Покажи, что произойдёт при реконнекте (WsSubscribed/WsHistory) — не
потеряется ли собранная за сессию карта read-курсоров, и стоит ли её
сбрасывать при смене чата (скорее да — она валидна только для текущего
chatId).
```

## Промпт 11 — Единый поиск (чаты + люди)

```
Контекст: в Telegram верхний поиск в списке чатов ищет одновременно и по
открытым диалогам, и по контактам/пользователям — один инпут, а не два
разных экрана. Сейчас в chatix это два независимых, слабо связанных места:
- ProfilesListScreen (lib/features/profile/presentation/screens/
  profiles_list_screen.dart) — работающий поиск, но только по displayName
  (хотя username тоже поддержан на уровне провайдера, см. Промпт 7).
- Строка поиска в списке чатов, если она уже добавлена промптом 7 из
  flutter_promts.md — там прямо написано "пока чисто UI, без реальной
  фильтрации, если такого провайдера нет" — то есть это заглушка.

Прочитай lib/features/chat/presentation/screens/chats_list_screen.dart и
lib/features/chat/presentation/providers/chat_list_provider.dart (есть ли
там реально работающий локальный/серверный фильтр чатов по имени, или
пока правда только UI-заглушка) и lib/features/profile/presentation/
providers/profile_list_provider.dart.

Задача:
1. Реши на основе того, что реально нашёл: если фильтрация списка чатов по
   имени УЖЕ работает (провайдер это поддерживает) — сделай общий
   поисковый экран/шторку, который по одному инпуту параллельно
   (Future.wait) бьёт в chatListProvider-фильтр и в
   getProfilesUseCaseProvider(username: query), и показывает два
   раздела результата — "Чаты" и "Люди" — с общим debounce на ввод.
2. Если фильтрации чатов по имени НА САМОМ ДЕЛЕ нет нигде (ни в
   провайдере, ни на бэкенде в api-docs §6.2 — там GET /chats/ не принимает
   параметр поиска по имени) — не выдумывай серверный поиск чатов: раздел
   "Чаты" в едином поиске делай локальной фильтрацией уже загруженных в
   chatListProvider.state.items по name/last_message.content (то, что уже
   есть у клиента в памяти), это честно и не требует нового backend-
   контракта. Явно напиши в комментарии, что это локальный, а не
   полнотекстовый по всей истории поиск.
3. Раздел "Люди" — используй getProfilesUseCaseProvider(username: query)
   напрямую (или переиспользуй profileListProvider.search), тап по
   результату — как в Промпте 8, сразу открывает/создаёт direct-чат с этим
   человеком.
4. Не трогай ProfilesListScreen как отдельный самостоятельный экран
   "Люди" — он может остаться, единый поиск это дополнение, а не замена.
```

## Промпт 12 — Финальный прогон по Части 2

```
1. Пройдись по Промптам 7-11: везде, где раньше был голый int user_id в UI
   (create_chat_screen.dart, chat_members_screen.dart, любые новые места),
   его больше не должно остаться без причины — если где-то намеренно
   оставлен id (например в диагностическом виде типа "User #123" как
   фолбэк, когда profile == null) — это ок, отметь явно, что это фолбэк.
2. flutter analyze — ноль новых warning/error, dart run build_runner build
   --delete-conflicting-outputs, если добавлялись новые json_serializable
   модели.
3. flutter test — если ломаются существующие виджет-тесты
   create_chat_screen/chat_members_screen из-за смены разметки (не
   поведения) — поправь тест под новую структуру.
4. Сводка одним списком: что из "стало похоже на Telegram" реально
   заработало end-to-end (нашёл пользователя по username → добавил/создал
   чат → увидел галочки прочтения), а что осталось на уровне UI-заглушки с
   TODO (например, групповые read receipts из Промпта 10, п.3) — с путями к
   файлам, чтобы было понятно, что доделывать дальше.
```