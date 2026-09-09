# Аудит клиента ChatiX против api-docs.md (§3–§7)

> Дата: 2026-09-09. Ветка `main`, коммит `990cfad`.
> Базовая линия перед аудитом: `flutter analyze` — **0 issues**, `flutter test` — **314 passed**.
>
> **Обновление:** ярусы 1 и 2 бэклога (T-1…T-14) реализованы. Состояние после них —
> `flutter analyze` 0 issues, `flutter test` **369 passed**. Таблицы разделов 1–4
> описывают состояние ДО правок; актуальный статус — в разделе 5.

Обозначения покрытия UI:
- ✅ — есть пользовательский путь, фича доведена до продукта;
- 🟡 — путь есть, но упирается в заглушку/отладочный вывод;
- ❌ — реализовано в data/domain, в UI не выведено;
- — — не реализовано вовсе.

---

## 1. Таблицы покрытия

### 1.1 §3 Аутентификация и пользователи

| Эндпоинт | Реализация в клиенте | UI | Замечания |
|---|---|---|---|
| `POST /users/register/` | [auth_remote_data_source.dart:50](lib/features/auth/data/datasources/auth_remote_data_source.dart:50) | ✅ `register_screen.dart` | ок |
| `POST /auth/login/` | [auth_remote_data_source.dart:69](lib/features/auth/data/datasources/auth_remote_data_source.dart:69) | ✅ `login_screen.dart` | `form-urlencoded` + поле `username` — соответствует §0.4 |
| `POST /auth/refresh/` | [auth_interceptor.dart:167](lib/core/network/interceptors/auth_interceptor.dart:167) | ✅ (прозрачно) | single-flight через `Lock`, реюз токена соседним запросом, терминальные коды разобраны — соответствует §0.6 |
| `POST /auth/logout/` | [auth_remote_data_source.dart:82](lib/features/auth/data/datasources/auth_remote_data_source.dart:82) | ✅ `profile_screen.dart` | ок |
| `POST /auth/verifications/email/` | [auth_remote_data_source.dart:94](lib/features/auth/data/datasources/auth_remote_data_source.dart:94) | ✅ `verify_email_screen.dart` | ок |
| `POST /auth/verifications/email/verify/` | [auth_remote_data_source.dart:103](lib/features/auth/data/datasources/auth_remote_data_source.dart:103) | ✅ `verify_email_screen.dart` | ок |
| `POST /auth/password-resets/` | [auth_remote_data_source.dart:112](lib/features/auth/data/datasources/auth_remote_data_source.dart:112) | ✅ `reset_password_request_screen.dart` | ок |
| `POST /auth/password-resets/confirm/` | [auth_remote_data_source.dart:121](lib/features/auth/data/datasources/auth_remote_data_source.dart:121) | ✅ `reset_password_confirm_screen.dart` | ок |
| `GET /auth/oauth/{provider}/authorize/` | [auth_remote_data_source.dart:138](lib/features/auth/data/datasources/auth_remote_data_source.dart:138) | 🟡 `oauth_buttons.dart` | Кнопки видны на логине ([login_screen.dart:163](lib/features/auth/presentation/screens/login_screen.dart:163)), но `oauth_callback_screen.dart` — тупик с текстом «not fully wired up yet». См. §3, задача T-12 |
| `GET /auth/oauth/{provider}/authorize/connect/` | там же, флаг `connect: true` | ❌ | привязка провайдера к аккаунту в UI отсутствует |
| `GET /auth/oauth/{provider}/callback/` | — | — | обмена `code`+`state` на токен нет. Нужна схема `redirect_uri` от бэкенда (§3.8 сам просит уточнить) |
| `GET /users/me/` | [auth_remote_data_source.dart:88](lib/features/auth/data/datasources/auth_remote_data_source.dart:88) | ✅ | облегчённый `{id, username, email}` — модель совпадает (§0.15) |
| `POST/DELETE /users/{id}/roles|permissions/` | — | — | админский RBAC, вне продукта |
| `GET /users/` (админ) | — | — | вне продукта |
| `GET /users/sessions/` | — | — | «мои устройства/сессии» — фича есть на бэке, клиента нет. Ответ — голый массив (§0.16) |
| `GET /roles/`, `/permissions/`, `/sessions/` | — | — | админский RBAC, вне продукта |

### 1.2 §4 Профили

| Эндпоинт | Реализация | UI | Замечания |
|---|---|---|---|
| `GET /profiles/` | [profile_remote_data_source.dart:59](lib/features/profile/data/datasources/profile_remote_data_source.dart:59) | ✅ `profiles_list_screen.dart`, `chat_search_screen.dart`, `user_search_field.dart` | `PageResult` считает `has_next` сам ([page_result.dart:18](lib/core/models/page_result.dart:18)) — соответствует §0.3 |
| `GET /profiles/{id}/` | [profile_remote_data_source.dart:88](lib/features/profile/data/datasources/profile_remote_data_source.dart:88) | ✅ `profile_screen.dart` | ок |
| `GET /profiles/my/` | [profile_remote_data_source.dart:96](lib/features/profile/data/datasources/profile_remote_data_source.dart:96) | 🟡 | **ЭНДПОИНТА НЕ СУЩЕСТВУЕТ.** См. §3, нарушение V-1 — свой профиль не открывается |
| `PUT /profiles/{id}/` | [profile_remote_data_source.dart:104](lib/features/profile/data/datasources/profile_remote_data_source.dart:104) | ✅ `profile_edit_screen.dart` | именно `PUT`, не `PATCH` — верно (§4.4) |
| `POST /profiles/avatar/presign/` | [profile_remote_data_source.dart:126](lib/features/profile/data/datasources/profile_remote_data_source.dart:126) | ✅ `avatar_picker_widget.dart` | ок |
| `PUT <presigned>` (аватар) | [avatar_uploader_impl.dart:17](lib/features/profile/data/datasources/avatar_uploader_impl.dart:17) | ✅ | сырые байты, без multipart, `Content-Length` выставлен — верно (§1.3) |
| `POST /profiles/avatar/upload_complete/` | [profile_remote_data_source.dart:139](lib/features/profile/data/datasources/profile_remote_data_source.dart:139) | ✅ | асинхронная валидация учтена: есть poll-стадии в `avatar_upload_stage.dart` (§0.10) |
| `POST /profiles/{id}/contacts/` | [profile_remote_data_source.dart:150](lib/features/profile/data/datasources/profile_remote_data_source.dart:150) | ✅ `profile_edit_screen.dart` | ок |
| `DELETE /profiles/{id}/{provider}/delete/` | [profile_remote_data_source.dart:163](lib/features/profile/data/datasources/profile_remote_data_source.dart:163) | ✅ | нестандартный путь воспроизведён точно (§4.6) |

### 1.3 §5 Чаты — REST

| Эндпоинт | Реализация (`chat_rest_data_source.dart`) | UI | Замечания |
|---|---|---|---|
| `GET /chats/` | [:190](lib/features/chat/data/datasources/chat_rest_data_source.dart:190) | ✅ `chats_list_screen.dart` | двусоставной курсор `last_activity_at` + `last_chat_id` передаётся полностью (§5.2) |
| `POST /chats/` | [:210](lib/features/chat/data/datasources/chat_rest_data_source.dart:210) | ✅ `create_chat_screen.dart`, `chat_search_screen.dart`, `profile_screen.dart` | pre-check `direct → memberIds.length == 1` на клиенте — хорошо. Но дедуп 1:1 опирается на `DIRECT_CHAT_EXISTS`, которого не бывает — нарушение V-2 |
| `GET /chats/{id}/` | [:251](lib/features/chat/data/datasources/chat_rest_data_source.dart:251) | ✅ `chat_detail_screen.dart` | `ChatModel` покрывает обе формы (`ChatDTO` и `ChatDetailDTO` с `members`) |
| `PATCH /chats/{id}/` | [:259](lib/features/chat/data/datasources/chat_rest_data_source.dart:259) | ❌ | нет экрана настроек чата. Недоступны: `name`, `description`, `is_public`, `admin_only`, `slow_mode_seconds`, `reactions_mode`, `allowed_reactions`, `permissions` |
| `DELETE /chats/{id}/` | [:289](lib/features/chat/data/datasources/chat_rest_data_source.dart:289) | ❌ | чат нельзя удалить из UI |
| `POST /chats/{id}/join/` | [:295](lib/features/chat/data/datasources/chat_rest_data_source.dart:295) | ❌ | и нет поверхности для обнаружения публичных чатов — нужен бэкенд |
| `POST /chats/{id}/leave/` | [:301](lib/features/chat/data/datasources/chat_rest_data_source.dart:301) | ❌ | из чата нельзя выйти. `canLeaveChat` уже учитывает ловушку `created_by` (§5.2) и не используется |
| `GET /chats/{id}/members/` | [:307](lib/features/chat/data/datasources/chat_rest_data_source.dart:307) | ✅ `chat_members_screen.dart` | `include_presence=true`, `presence` джойнится по `user_id` отдельным массивом ([chat_members_provider.dart:123](lib/features/chat/presentation/providers/chat_members_provider.dart:123)) — верно (§5.3) |
| `POST /chats/{id}/members/` | [:327](lib/features/chat/data/datasources/chat_rest_data_source.dart:327) | ✅ | `assignableChatRoles` не даёт пригласить овнером — верно (§5.3) |
| `PATCH /members/{uid}/role/` | [:340](lib/features/chat/data/datasources/chat_rest_data_source.dart:340) | ✅ | `canAssignChatRole` — только роль строго ниже своей (§5.3) |
| `PATCH /members/{uid}/ban/` | [:353](lib/features/chat/data/datasources/chat_rest_data_source.dart:353) | ✅ | `banned_to` с датой; семантика null/прошлое/будущее в UI не объяснена |
| `DELETE /members/{uid}/` | [:370](lib/features/chat/data/datasources/chat_rest_data_source.dart:370) | ✅ | ок |
| `GET /chats/{id}/messages/` | [:376](lib/features/chat/data/datasources/chat_rest_data_source.dart:376) | ✅ | курсор `cursor_message_seq`, `has_next` — реальное поле, читается как есть |
| `GET /messages/context/` | [:394](lib/features/chat/data/datasources/chat_rest_data_source.dart:394) | ❌ | **usecase не вызывается нигде.** Значит «перейти к сообщению» не работает ни из цитаты-ответа, ни из пуша |
| `POST /chats/{id}/messages/` | [:409](lib/features/chat/data/datasources/chat_rest_data_source.dart:409) | ✅ | `Idempotency-Key` генерируется всегда и переиспользуется при retry ([chat_detail_provider.dart:634](lib/features/chat/presentation/providers/chat_detail_provider.dart:634)) — образцово (§5.4) |
| `GET /messages/{mid}/` | [:436](lib/features/chat/data/datasources/chat_rest_data_source.dart:436) | ❌ | не используется |
| `PATCH /messages/{mid}/` | [:447](lib/features/chat/data/datasources/chat_rest_data_source.dart:447) | ✅ | `canEditMessage` = только автор, без обхода по правам — верно (§5.4) |
| `DELETE /messages/{mid}/` | [:462](lib/features/chat/data/datasources/chat_rest_data_source.dart:462) | ✅ | `canDeleteMessage` = автор ИЛИ `message:delete` — верно (§5.4) |
| `POST /messages/forward/` | [:473](lib/features/chat/data/datasources/chat_rest_data_source.dart:473) | ✅ | одиночный и bulk-форвард. `comment` в UI не предлагается; `Idempotency-Key` для forward **не** передаётся (§5.4 разрешает) |
| `POST /messages/read/` | [:493](lib/features/chat/data/datasources/chat_rest_data_source.dart:493) | ✅ | ок |
| `POST /attachments/upload-requests/` | [:502](lib/features/chat/data/datasources/chat_rest_data_source.dart:502) | ✅ | голый массив в ответе разобран верно (§5.5) |
| `PUT <upload_url>` | [chat_attachment_uploader_impl.dart:19](lib/features/chat/data/datasources/chat_attachment_uploader_impl.dart:19) | ✅ | сырые байты/стрим, без multipart — верно |
| `POST /attachments/.../confirm/` | [:535](lib/features/chat/data/datasources/chat_rest_data_source.dart:535) | ✅ | готовность ждётся по WS `attachment_success` ([chat_socket_provider.dart:58](lib/features/chat/presentation/providers/chat_socket_provider.dart:58)) — верно (§5.5) |
| `GET .../download-url/` | [:547](lib/features/chat/data/datasources/chat_rest_data_source.dart:547) | 🟡 | ссылка показывается как `SelectableText` в диалоге ([chat_detail_screen.dart:710](lib/features/chat/presentation/screens/chat_detail_screen.dart:710)) — отладочный UI в пользовательском пути |
| `POST /calls/join/` | [:563](lib/features/chat/data/datasources/chat_rest_data_source.dart:563) | 🟡 | из `chat_detail_screen` показывает диалог с сырым LiveKit-токеном ([:483](lib/features/chat/presentation/screens/chat_detail_screen.dart:473)). Полноценный `call_screen.dart` существует, но недостижим |
| `POST /calls/participants/{uid}/mute/` | [:571](lib/features/chat/data/datasources/chat_rest_data_source.dart:571) | ❌ | вызывается только из `call_provider`, который живёт в недостижимом `CallScreen` |
| `PUT .../reactions/{emoji}/` | [:587](lib/features/chat/data/datasources/chat_rest_data_source.dart:587) | ✅ | эмодзи URL-кодируется (§5.7.1) |
| `DELETE .../reactions/{emoji}/` | [:600](lib/features/chat/data/datasources/chat_rest_data_source.dart:600) | ✅ | ок |
| `PUT .../reactions/` (set) | [:613](lib/features/chat/data/datasources/chat_rest_data_source.dart:613) | ❌ | `replaceReactions` есть в провайдере, но ни один виджет его не вызывает — нет панели выбора реакций |
| `DELETE .../reactions/` | [:626](lib/features/chat/data/datasources/chat_rest_data_source.dart:626) | ❌ | то же |
| `GET .../reactions/` | [:637](lib/features/chat/data/datasources/chat_rest_data_source.dart:637) | ✅ | шторка «кто поставил» с курсорной пагинацией ([chat_detail_screen.dart:1155](lib/features/chat/presentation/screens/chat_detail_screen.dart:1155)) |

### 1.4 §6 WebSocket

Сервис: [chat_socket_service.dart](lib/core/websocket/chat_socket_service.dart), парсер: [ws_event_parser.dart](lib/core/websocket/ws_event_parser.dart).

**Команды клиент → сервер**

| `op` | Реализация | Замечания |
|---|---|---|
| `subscribe` | [:186](lib/core/websocket/chat_socket_service.dart:186) | `last_seq` из локального максимума — верно (§6.5.2) |
| `unsubscribe` | [:204](lib/core/websocket/chat_socket_service.dart:204) | вызывается в `_teardown` экрана чата |
| `resume` | [:210](lib/core/websocket/chat_socket_service.dart:210) | клампится до 20 курсоров (`_selectFreshestCursors`) — обходит ловушку `MAX_LIMIT_CURSOR` (§6.3) |
| `ping` | [:378](lib/core/websocket/chat_socket_service.dart:378) | проактивный при простое > 0.6·`heartbeat_timeout` |
| `pong` | [:258](lib/core/websocket/chat_socket_service.dart:258) | ответ на каждый `ws.ping` — верно (§6.2.3) |

**События сервер → клиент**

| `type` | Парсинг | Обработка в состоянии | UI | Замечания |
|---|---|---|---|---|
| `ws.ready` | [:91](lib/core/websocket/ws_event_parser.dart:91) | [chat_socket_service.dart:306](lib/core/websocket/chat_socket_service.dart:306) | ✅ баннер соединения | `heartbeat_interval/timeout` берутся из payload, не хардкод |
| `ws.subscribed` | [:106](lib/core/websocket/ws_event_parser.dart:106) | курсор поднимается | — | ок |
| `ws.unsubscribed` | [:117](lib/core/websocket/ws_event_parser.dart:117) | no-op | — | ок |
| `ws.history` | [:123](lib/core/websocket/ws_event_parser.dart:123) | [chat_detail_provider.dart:330](lib/features/chat/presentation/providers/chat_detail_provider.dart:330) | ✅ | докачка пропущенного + `mark_read`. `has_more` **игнорируется**: если история не влезла в одну пачку, остаток не догружается |
| `ws.pong` | [:21](lib/core/websocket/ws_event_parser.dart:21) | no-op | — | ок |
| `ws.ping` | [:151](lib/core/websocket/ws_event_parser.dart:151) | → `pong` | — | форма без `payload` учтена (§6.4) |
| `ws.error` | [:158](lib/core/websocket/ws_event_parser.dart:158) | лог | ❌ | `NOT_CHAT_MEMBER` только пишется в лог — пользователь не узнаёт, что подписка отклонена |
| `new_message` | [:208](lib/core/websocket/ws_event_parser.dart:208) | detail [:301](lib/features/chat/presentation/providers/chat_detail_provider.dart:301), list [:186](lib/features/chat/presentation/providers/chat_list_provider.dart:186) | ✅ | `payload.message` берётся целиком, рефетча нет — верно. Но в списке чатов `last_message` не обновляется (нарушение V-5) |
| `message_edited` | [:232](lib/core/websocket/ws_event_parser.dart:232) | [:215](lib/features/chat/presentation/providers/chat_detail_provider.dart:215) | ✅ | замена по `message.id` |
| `message_deleted` | [:257](lib/core/websocket/ws_event_parser.dart:257) | [:218](lib/features/chat/presentation/providers/chat_detail_provider.dart:218) | ✅ | tombstone по `event.message_id`, без рефетча — верно |
| `messages_read` | [:278](lib/core/websocket/ws_event_parser.dart:278) | [:395](lib/features/chat/presentation/providers/chat_detail_provider.dart:395) | ✅ | `peerReadSeq` per-reader, галочки только в direct |
| `member_joined` | [:333](lib/core/websocket/ws_event_parser.dart:333) | [:275](lib/features/chat/presentation/providers/chat_detail_provider.dart:275) | 🟡 | если добавили **меня** в чат, которого нет в списке, чат не появится (нарушение V-6) |
| `member_left` | [:351](lib/core/websocket/ws_event_parser.dart:351) | [:272](lib/features/chat/presentation/providers/chat_detail_provider.dart:272) | ✅ | ок |
| `member_kick` | [:367](lib/core/websocket/ws_event_parser.dart:367) | [:266](lib/features/chat/presentation/providers/chat_detail_provider.dart:266) | ✅ | адресная доставка исключённому учтена (`isGone`) |
| `member_banned` | [:387](lib/core/websocket/ws_event_parser.dart:387) | [:269](lib/features/chat/presentation/providers/chat_detail_provider.dart:269) | ✅ | `ban: false` = разбан → рефетч строки. Учтено исчезновение чата у забаненного (§5.3) |
| `chat_created` | [:408](lib/core/websocket/ws_event_parser.dart:408) | [chat_list_provider.dart:228](lib/features/chat/presentation/providers/chat_list_provider.dart:228) | ✅ | дозапрос `GET /chats/{id}/` с защитой от гонок |
| `chat_updated` | [:433](lib/core/websocket/ws_event_parser.dart:433) | [:241](lib/features/chat/presentation/providers/chat_detail_provider.dart:241) | ✅ | все поля дельты, включая `reactions_mode`/`allowed_reactions` |
| `chat_deleted` | [:469](lib/core/websocket/ws_event_parser.dart:469) | [:263](lib/features/chat/presentation/providers/chat_detail_provider.dart:263) | ✅ | `isGone` + удаление из списка |
| `reaction_update` | [:300](lib/core/websocket/ws_event_parser.dart:300) | [:437](lib/features/chat/presentation/providers/chat_detail_provider.dart:437) | ✅ | снимок групп из `payload.reaction`, `reacted_by_me` реконсилится локально по `actorId` — верно (§5.7.6). Поддержаны оба wire-имени |
| `attachment_success` | [:482](lib/core/websocket/ws_event_parser.dart:482) | [chat_socket_provider.dart:65](lib/features/chat/presentation/providers/chat_socket_provider.dart:65) | ✅ | другая форма payload (`user_id/chat_id/tokens`) учтена |
| `typing_start/stop`, `call_*` | [:43](lib/core/websocket/ws_event_parser.dart:43) `WsUnimplementedEvent` | лог | — | правильно: бэкенд их не публикует (§6.4) |

**Жизненный цикл соединения**

| Требование §6 | Статус |
|---|---|
| Дедуп по `payload.event_id` (at-least-once) | ✅ [:59](lib/core/websocket/chat_socket_service.dart:59), LRU на 512 id, тест `chat_socket_dedup_test.dart` |
| Токен через query `?token=` | ✅ [:461](lib/core/websocket/chat_socket_service.dart:461) |
| Экспоненциальный backoff + jitter | ✅ [:428](lib/core/websocket/chat_socket_service.dart:428) |
| `1008` → невалидный токен, не реконнектить молча | ✅ [:410](lib/core/websocket/chat_socket_service.dart:410) → инвалидация `authProvider` |
| `1001`/`1012` → тихий реконнект | ✅ [:416](lib/core/websocket/chat_socket_service.dart:416) |
| `resume` после реконнекта | ✅ [:324](lib/core/websocket/chat_socket_service.dart:324) |
| `initial_chat_id` + `initial_last_seq` при connect | ❌ не используется — лишний round-trip при «открыл чат» (§6.1) |
| Subprotocol `chat.v1` | ❌ не предлагается (опционально) |

### 1.5 §7 Уведомления

| Эндпоинт | Реализация | UI | Замечания |
|---|---|---|---|
| `POST /devices/` | [notification_remote_data_source.dart:37](lib/features/notification/data/datasources/notification_remote_data_source.dart:37) | 🟡 | вызывается после логина ([auth_provider.dart:127](lib/features/auth/presentation/providers/auth_provider.dart:127)), но токен — фейковый: `DebugNotificationService` отдаёт `debug-token-<ts>` ([debug_notification_service.dart:32](lib/core/notifications/debug_notification_service.dart:32)). См. V-8 |
| `GET /notifications/` | [:54](lib/features/notification/data/datasources/notification_remote_data_source.dart:54) | ✅ `notifications_screen.dart` | фильтр `is_read`, пагинация через `PageResult` |
| `GET /notifications/unread_count/` | [:79](lib/features/notification/data/datasources/notification_remote_data_source.dart:79) | ✅ бейдж в `app_shell.dart` | ок |
| `PATCH /notifications/{id}/read/` | [:88](lib/features/notification/data/datasources/notification_remote_data_source.dart:88) | ✅ | ок |
| `PATCH /notifications/read_all/` | [:100](lib/features/notification/data/datasources/notification_remote_data_source.dart:100) | ✅ «Read all» | голое число в ответе разобрано верно (§0.17) |
| Переход по уведомлению | [notification_route_resolver.dart:4](lib/features/notification/presentation/utils/notification_route_resolver.dart:4) | 🟡 | ведёт только в чат. `NotificationEntity.messageId` уже разобран ([notification_entity.dart:59](lib/features/notification/domain/entities/notification_entity.dart:59)) и игнорируется — нет прыжка к сообщению |

---

## 2. Бэкенд умеет, data/domain умеет, пользователь — нет

Самый дешёвый источник фич: код уже написан и покрыт слоями, не хватает экрана или кнопки.

| # | Возможность | Что уже готово | Чего не хватает |
|---|---|---|---|
| G-1 | **Экран звонка** | `call_screen.dart` (422 стр.), `call_provider.dart` (292 стр.), `livekit_client` в pubspec, маршрут `ChatCallRoute` **объявлен в роутере** ([app_router.dart:107](lib/core/router/app_router.dart:107)) | ни одного `context.push(ChatCallRoute...)` в коде. Кнопка «Call» вместо этого показывает диалог с сырым токеном |
| G-2 | **Выйти из чата** | `leaveChatUseCase`, `canLeaveChat` (учитывает ловушку `created_by`) | экран/меню «инфо о чате» |
| G-3 | **Удалить чат** | `deleteChatUseCase`, право `chat:delete` в `hasChatPermission` | то же меню |
| G-4 | **Настройки чата** | `updateChatUseCase` со всеми полями: имя, описание, `is_public`, `admin_only`, `slow_mode_seconds`, `reactions_mode`, `allowed_reactions`, `permissions` | экран редактирования чата. `hasAnyChatManagementAction` написан специально для этого меню и **не используется нигде** |
| G-5 | **Прыжок к сообщению** | `getMessagesContextUseCase` + `GET /messages/context/` полностью реализованы | тап по цитате-ответу и по пушу с `message_id` |
| G-6 | **Панель реакций** | `replaceReactions`/`clearReactions` в провайдере ([chat_detail_provider.dart:507](lib/features/chat/presentation/providers/chat_detail_provider.dart:507)), `reactionPolicy` с проверкой `mode=some` | оверлей-панель выбора эмодзи. Сейчас реакцию можно только переключить у **уже существующего** чипса — первую поставить невозможно |
| G-7 | **Мьют участника в звонке** | `muteCallParticipantUseCase` + право `call:mute_member` | зависит от G-1 |
| G-8 | **Присоединиться к публичному чату** | `joinChatUseCase` | поверхность обнаружения. **Требует бэкенда** — нет эндпоинта «список публичных чатов» |
| G-9 | **Экран настроек** | `settings_screen.dart`, `language_settings_screen.dart`, маршрут `/settings` в роутере | точки входа нет: в `AppShell` три таба (Chats/Alerts/Profile), ни один не ведёт в `/settings` |
| G-10 | **Список профилей** | `profiles_list_screen.dart`, маршрут `/profiles` | точки входа нет; попасть можно только по прямому URL |
| G-11 | **Комментарий при форварде** | `forwardMessage(comment:)` в data/domain | поле ввода в диалоге выбора чата |
| G-12 | **Свои сессии/устройства** | — | `GET /users/sessions/` не реализован даже в data. Дешёвая фича безопасности |
| G-13 | **Привязка OAuth к аккаунту** | `getOAuthUrl(connect: true)` | кнопка в `profile_edit_screen` + рабочий callback (см. V-3) |

---

## 3. Нарушения §0 и контракта api-docs

Сначала — что сделано **правильно**, чтобы не искать проблем там, где их нет:
трейлинг-слэш централизован (`buildPath` + `TrailingSlashInterceptor`, единственное исключение `/health`);
ошибки читаются как `body['error']['code']` ([api_client.dart:152](lib/core/network/api_client.dart:152));
429 обрабатывается отдельной ветвью через `body['detail']` ([api_client.dart:145](lib/core/network/api_client.dart:145));
токен не кэшируется вручную, всё через refresh-интерцептор;
дедуп по `event_id` есть; `PageResult.has_next` считается на клиенте; курсоры чатов двусоставные.

Найденные нарушения:

| # | Серьёзность | Где | Что не так |
|---|---|---|---|
| **V-1** | 🔴 блокер | [profile_remote_data_source.dart:96](lib/features/profile/data/datasources/profile_remote_data_source.dart:96) | `GET /profiles/my/` — **такого эндпоинта в api-docs нет** (§4 знает только `/profiles/` и `/profiles/{profile_id}/`). FastAPI сматчит это как `profile_id = "my"` → `422 VALIDATION`. Путь боевой: [profile_detail_provider.dart](lib/features/profile/presentation/providers/profile_detail_provider.dart) вызывает `getMyProfile()` всегда, когда `profileId == currentUserId`, то есть **свой профиль не открывается вообще**. Починка — использовать `fetchProfile(currentUserId)`, `profile.id === user.id` (§4.1) |
| **V-3** | 🟠 | [login_screen.dart:163](lib/features/auth/presentation/screens/login_screen.dart:163) → [oauth_callback_screen.dart](lib/features/auth/presentation/screens/oauth_callback_screen.dart) | OAuth-кнопки в продакшн-UI ведут на экран с текстом «not fully wired up yet». Обмен `code`+`state` (§3.8.3) не реализован. Нарушает DoD «никаких TODO-заглушек в пользовательских путях» |
| **V-4** | 🟠 | [chat_members_screen.dart:179](lib/features/chat/presentation/screens/chat_members_screen.dart:179) | `NetworkImage(avatarUrl)`, где `avatarUrl` — это `ChatProfileDTO.avatar_url`, а он по §5.3 «presigned URL, генерируется на лету». `ImageCache` во Flutter ключуется строкой URL: подпись меняется на каждом рефетче → промах кэша каждый раз, и картинка ломается, когда подпись истекает у живого виджета. Кэшировать надо по `avatar_s3_key` (поле есть в DTO и в `ChatProfileEntity`) |
| **V-5** | 🟠 | [chat_realtime_merge.dart:55](lib/features/chat/presentation/providers/chat_realtime_merge.dart:55) | `applyNewMessageToRow` двигает `lastActivityAt`, `seqCounter` и `unreadCount`, но **не выставляет `lastMessage`** — притом что декодированный `MessageEntity` уже на руках ([chat_list_provider.dart:187](lib/features/chat/presentation/providers/chat_list_provider.dart:187)). Превью в списке чатов остаётся старым до полного рефетча |
| **V-6** | 🟡 | [chat_list_provider.dart:265](lib/features/chat/presentation/providers/chat_list_provider.dart:265) | `member_joined` с моим `user_id` попадает в `_onMembershipChange(removed: false)` → только правит `memberCount` у строки, которой в списке нет. Если меня **добавили** в существующий чат, он не появится до ручного refresh. `_refetchRow` для этого уже написан, просто не вызывается |
| **V-7** | 🟡 | [chat_detail_provider.dart:330](lib/features/chat/presentation/providers/chat_detail_provider.dart:330) | `ws.history.has_more` не используется. §6.4 обещает `has_more` + `next_last_seq`: при большом разрыве часть пропущенных сообщений не догрузится, дыра закроется только через `loadMore`/refresh |
| **V-8** | 🟡 | [notification_providers.dart:7](lib/core/notifications/notification_providers.dart:7) | В прод-провайдере зашит `DebugNotificationService`, отдающий `debug-token-<timestamp>`. Этот мусор регистрируется на реальном `POST /devices/` — пуши не придут никогда, а на бэке копятся нерабочие устройства |
| **V-9** | 🟡 | [chat_rest_data_source.dart:473](lib/features/chat/data/datasources/chat_rest_data_source.dart:473) | `POST /messages/forward/` идёт **без** `Idempotency-Key`, хотя §5.4 его поддерживает и для форварда, а в UI есть bulk-форвард пачкой. Обрыв сети посреди пачки → дубли |
| **V-10** | 🟡 | [chat_detail_screen.dart:710](lib/features/chat/presentation/screens/chat_detail_screen.dart:710), [:483](lib/features/chat/presentation/screens/chat_detail_screen.dart:473) | Presigned URL вложения и LiveKit-токен выводятся пользователю как `SelectableText`. Помимо UX это утечка подписанных креденшелов в буфер обмена/скриншоты |
| **V-11** | 🟡 | вся `lib/features/**` | **Ни один файл фич не использует `AppLocalizations`.** Причина глубже, чем казалось: сгенерированный gen_l10n-класс `lib/gen/l10n/**` **не был подключён к приложению вообще** — `main.dart` регистрировал только рукописный `AppLocalizationsDelegate` из `lib/l10n/l10n.dart` с map-переводами, а ARB-пайплайн собирался «в стол». Плюс `intl_fr.arb` лежал пустым (0 байт). Исправлено в T-6: оба делегата зарегистрированы, `intl_fr.arb` — валидный. Сама миграция строк — T-15. В `intl_en.arb` 47 ключей, все — демо/логин; весь UI чатов, профиля, участников, уведомлений — хардкод английского. Прямое нарушение правила «ЛЮБАЯ новая пользовательская строка идёт в ARB» |
| **V-12** | 🟢 | [chat_detail_screen.dart:1054](lib/features/chat/presentation/screens/chat_detail_screen.dart:1054) | Кнопка микрофона всегда `onPressed: null` с тултипом «Voice messages are not available yet» — заглушка в пользовательском пути. `voice`/`video_note` полностью готовы в data/domain (`AttachmentType.voice`, лимиты, MIME) |
| **V-13** | 🟢 | [chat_socket_service.dart:461](lib/core/websocket/chat_socket_service.dart:461) | `initial_chat_id`/`initial_last_seq` (§6.1) не передаются — лишний round-trip на каждом входе в чат. Не баг, упущенная оптимизация |
| **V-15** | 🟠 | [avatar_upload_provider.dart:60](lib/features/profile/presentation/providers/avatar_upload_provider.dart:60) | **Найдено при написании тестов к T-1.** `await ref.read(provider.future)` на провайдере, который бросил `Failure`, **никогда не завершается**: Riverpod доводит `.future` до конца только для брошенных `Error`, а `Failure` — обычный `Equatable` (проверено изолированно: `Failure`, `Exception` и произвольный объект — зависают, `StateError` — нет). Путь `AsyncValue.hasError` при этом работает, поэтому UI c `.when(error:)` не страдает. Но опрос аватара обёрнут в `try/catch` в расчёте на бросок — при неудачном `GET /profiles/{id}/` (в т.ч. штатный 404 сразу после регистрации, §4.1) цикл повиснет вместо `continue`. Единственное место в `lib/`, где ждут `.future` |
| **V-14** | 🟢 | [ws_event_parser.dart:163](lib/core/websocket/ws_event_parser.dart:163) | `ws.error` c кодом `NOT_CHAT_MEMBER` только логируется. Пользователь остаётся на экране чата, который не получает событий, без единого сигнала |

> Отдельно: правило §5.5 «кэшировать файл по `s3_key`, НЕ url» формально не нарушено — клиент **вообще ничего не кэширует** и не отображает медиа, `s3Key` доезжает до энтити и нигде не читается. Как только появится превью изображений (T-8), ключом кэша обязан стать `s3_key`.

---

## 4. Оценка экранов `lib/features/chat/presentation/screens/**`

| Экран | Строк | Оценка | Обоснование |
|---|---|---|---|
| `chat_members_screen.dart` | 466 | **продуктовый** (минус ARB) | самый зрелый экран чата: курсорная пагинация, presence-точка, аватары, смена роли с матрицей прав, бан с датой, кик, инвайт, пустое состояние, состояние ошибки с retry |
| `create_chat_screen.dart` | 224 | **рабочий** | все 4 типа чата, `is_public`, `admin_only`, `slow_mode`, валидация direct-чата. Нет `reactions_mode`/`allowed_reactions`/`permissions`, нет аватара чата |
| `chat_search_screen.dart` | 289 | **рабочий** | дебаунс 300 мс, защита от гонок по `_requestId`, поиск людей + локальная фильтрация чатов. Поиск по сообщениям невозможен — **нужен бэкенд** |
| `chats_list_screen.dart` | 215 | **рабочий** | пагинация, refresh, unread-бейдж, живые WS-обновления, приличные превью по типам. Но: direct-чаты не идентифицируют собеседника, аватаров нет, превью не живое (V-5) |
| `chat_detail_screen.dart` | 1267 | **рабочий текст / черновик медиа** | текстовая переписка сделана хорошо: optimistic pending с retry/discard, идемпотентность, баннер соединения, bulk-выделение, форвард, реакции, галочки прочтения. Всё медийное и звонки — черновик: диалоги с URL и токеном, выключенный микрофон, вложения строчками |
| `call_screen.dart` | 422 | **черновик по факту** | код выглядит рабочим (LiveKit `Room.connect`, сетка участников, мьют по правам), но экран **недостижим** из приложения — а значит не продукт |

### Три самых слабых места UX

**1. Вложения в мессенджере не визуальны.**
[message_bubble.dart:313](lib/features/chat/presentation/widgets/message_bubble.dart:313) рендерит любое вложение — фото, видео, голосовое, видео-кружок — одинаковой строкой «иконка + имя файла + размер». Тап открывает `AlertDialog` с текстом presigned-ссылки и надписью «Expires in 300s» ([chat_detail_screen.dart:710](lib/features/chat/presentation/screens/chat_detail_screen.dart:710)). Ни одного пикселя контента. При этом `cached_network_image` уже в зависимостях, а `AttachmentDTO` несёт `width`/`height`/`duration_seconds` для правильных плейсхолдеров без сдвига layout.

**2. Direct-чат не имеет лица.**
У direct-чата `name == null` (бэкенд его не заполняет), поэтому [chats_list_screen.dart:188](lib/features/chat/presentation/screens/chats_list_screen.dart:188) подставляет литерал `'Direct chat'`, а `leading` — обезличенный `Icon(Icons.person_outline)`. Список личных переписок выглядит как стопка идентичных строк «Direct chat». То же в шапке чата: `chat.name ?? 'Chat'` ([chat_detail_screen.dart:246](lib/features/chat/presentation/screens/chat_detail_screen.dart:246)) и в диалоге форварда. Данные для починки уже приходят даром: `ChatProfileDTO` (`username`, `display_name`, `avatar_url`, `avatar_s3_key`) вложен и в `members`, и в `last_message.profile` — ходить в `/profiles/` не нужно. `ChatEntity` не имеет ни одного хелпера разрешения собеседника.

**3. Тупики и отладочные окна в живых путях.**
Кнопка «Call» → диалог с сырым LiveKit-токеном, при готовом и недостижимом `CallScreen`. Микрофон — навсегда серый. OAuth-кнопки → «not fully wired up yet». Из чата нельзя выйти, чат нельзя удалить или переименовать. `/settings` недостижим. Каждый из этих случаев — код, который уже написан, но не соединён проводом.

### Разрыв с дизайн-ориентиром §2

Из паттернов §2.1 в `message_bubble.dart` реализованы только контекстное меню по долгому нажатию и чипсы реакций. Отсутствуют: свайп-по-сообщению → ответ; панель реакций поверх сообщения; группировка подряд идущих сообщений одного автора; липкий разделитель дат; разделитель «непрочитанные»; плавающая кнопка «вниз» со счётчиком; переход к оригиналу из цитаты (`_ReplyPreview` — не кликабельный `Text`); удержание микрофона для записи; редактирование в поле ввода (сейчас — `AlertDialog` с `TextField`, [chat_detail_screen.dart:613](lib/features/chat/presentation/screens/chat_detail_screen.dart:613)).

Из айдентики §2.2 не реализовано ничего: пузыри крашены в `primaryContainer`/`surfaceContainerHighest` из ColorScheme, радиус симметричный `circular(14)`, градиента исходящего пузыря нет, акцентов violet/mint нет, цвета автора по `user_id` нет, обоев чата нет, режимов плотности нет, табличных цифр нет.

---

## 5. Задачи, отсортированные по «польза / стоимость»

Стоимость: **XS** ≤ полчаса, **S** ≤ полдня, **M** ≤ 2 дня, **L** — больше.

### Ярус 1 — почти бесплатно, чинит сломанное

| # | Задача | Стоимость | Польза |
|---|---|---|---|
| T-1 | **V-1**: заменить `GET /profiles/my/` на `fetchProfile(currentUserId)`. Тест на путь запроса | XS | Свой профиль перестанет отдавать 422 — сейчас экран профиля просто не работает |
| T-2 | **G-1**: кнопка «Call» → `context.push(ChatCallRoute.locationOf(chatId))`, удалить диалог с токеном | XS | 700 строк готового кода звонков становятся продуктом; уходит утечка токена (часть V-10) |
| T-3 | **V-5**: добавить `lastMessage: message` в `applyNewMessageToRow` + тест мерджа | XS | Превью в списке чатов становится живым |
| T-4 | **V-9**: передавать `Idempotency-Key` в `forwardMessage` | XS | Bulk-форвард перестаёт дублировать при обрыве |
| T-5 | **V-6**: в `_onMembershipChange` при `userId == myUserId && !removed` вызвать `_refetchRow` + тест | XS | Чат, в который тебя добавили, появляется сам |
| T-6 | **G-9/G-10**: точки входа в `/settings` и `/profiles` (иконка в шапке профиля) | XS | Два готовых экрана перестают быть мёртвыми |
| T-7 | **V-3**: убрать OAuth-кнопки с логина до готовности callback (или спрятать за feature-flag — `feature_flag_service` уже есть) | XS | Уходит тупик из главного пользовательского пути |

### Ярус 2 — дешёвая большая польза ✅ СДЕЛАНО

| # | Задача | Статус | Что получилось |
|---|---|---|---|
| T-8 | Идентичность собеседника | ✅ | `ChatEntity.peerProfile(myUserId)` достаёт визави из данных, которые уже приходят: `members` (ChatDetailDTO) или `last_message.profile` (ChatDTO в списке) — ни одного лишнего запроса. Единая точка именования — [chat_title.dart](lib/features/chat/presentation/utils/chat_title.dart): `name` → имя собеседника → локализованный тип чата. Применено в тайле списка, в новой шапке чата (аватар + имя + `@username`/счётчик участников, тап → инфо) и в диалоге форварда |
| T-9 | Превью изображений | ✅ | [attachment_preview.dart](lib/features/chat/presentation/widgets/attachment_preview.dart): одиночная картинка занимает пузырь в своём соотношении сторон (`width`/`height` из DTO — layout не прыгает при загрузке), несколько складываются в сетку 2×N. Тап → полноэкранный просмотр с зумом вместо диалога с текстом ссылки. Кэш по `s3_key`; протухшая подпись ловится в `errorWidget` и один раз перевыпускается через [attachment_url_provider.dart](lib/features/chat/presentation/providers/attachment_url_provider.dart) (§5.5). Не-картинки открываются во внешнем приложении по свежей ссылке |
| T-10 | Экран «Информация о чате» | ✅ | [chat_info_screen.dart](lib/features/chat/presentation/screens/chat_info_screen.dart) + маршрут `ChatInfoRoute`. Имя, описание, `is_public`, `admin_only`, `slow_mode_seconds`, `reactions_mode`; переход к участникам; «Выйти» и «Удалить». PATCH шлёт **только изменённые** поля — это настоящий partial update (§5.2). Права разводят редактируемый и read-only вид. Создателю вместо неработающей кнопки «Выйти» показывается причина: `Chat.leave()` сверяется с `created_by`, и он заперт в чате навсегда (§5.2) |
| T-11 | Панель реакций | ✅ | [reaction_picker.dart](lib/features/chat/presentation/widgets/reaction_picker.dart) поверх листа действий. До этого **первую** реакцию поставить было физически нельзя — чипсы под пузырём умеют только переключать уже существующие. Строка фильтруется политикой чата, так что при `mode = "some"` тап не может получить `REACTION_NOT_ALLOWED`; на лимите в 3 эмодзи свои остаются активными (снять можно всегда), чужие гаснут |
| T-12 | Переход к сообщению | ✅ | `ChatDetailController.revealMessage` — если сообщение в окне, просто подсветка; иначе `GET /messages/context/`. `seq` берётся из вложенного `reply_to` (бесплатно), иначе одним `GET /messages/{id}/` — тот самый usecase, который раньше не использовался. Слайс **заменяет** окно, а не подмешивается: склейка оставила бы невидимую дыру и сломала бы обратную пагинацию. Плюс путь из пуша: `message_id` теперь доезжает через `ChatDetailRoute(chatId, messageId:)` до экрана |
| T-13 | Кэш аватаров по `s3_key` | ✅ | [chat_avatar.dart](lib/features/chat/presentation/widgets/chat_avatar.dart) — один виджет на аватар участника: `CachedNetworkImageProvider(url, cacheKey: avatar_s3_key)`, инициал-фолбэк, точка присутствия. `NetworkImage(avatarUrl)` в списке участников убран |
| T-14 | Дочитывание `ws.history` | ✅ | `_continueHistory` переподписывается с `next_last_seq`, пока `has_more`. Три предохранителя: курсор обязан расти, `next_last_seq == null` игнорируется, и не больше 20 страниц — иначе сервер, отвечающий одним и тем же курсором, запер бы клиента в цикле subscribe/history |

**Тесты, добавленные ярусом:** +35 (334 → 369). Пять поведенческих правок проверены мутацией
(T-8, T-11, T-12, T-13, T-14): на откате падают, на исправленном коде проходят.

- [chat_peer_test.dart](test/features/chat/domain/entities/chat_peer_test.dart) — разрешение собеседника из обоих источников + отказ выдавать моё же сообщение за визави
- [chat_detail_reveal_test.dart](test/features/chat/presentation/providers/chat_detail_reveal_test.dart) — переход к сообщению во всех ветках, включая замену окна
- [chat_detail_history_test.dart](test/features/chat/presentation/providers/chat_detail_history_test.dart) — прогон `ws.history` через настоящий контроллер и фейковый сокет
- [chat_avatar_test.dart](test/features/chat/presentation/widgets/chat_avatar_test.dart) — ключ кэша не зависит от подписи URL
- [reaction_picker_test.dart](test/features/chat/presentation/widgets/reaction_picker_test.dart) — белый список и лимит на пользователя

**Найдено и починено по дороге (оба нашлись при написании тестов):**

- `ChatDetailController._teardown` вызывал `ref.read` внутри `onDispose`. Riverpod это запрещает и роняет assertion **при каждом закрытии экрана чата в debug-сборке**; в release ассерты вырезаны, поэтому баг не был виден. Сокет теперь захватывается в `build` и отвязывается без `ref`.
- Тестовый фейк сокета висел в `tearDown`: `close()` у single-subscription `StreamController`, которого никто не слушал, не завершается никогда. Переведён на broadcast.

**Локализация:** 45 новых ключей заведено во всех 6 локалях; ни одной новой строки мимо ARB.
В `lib/features/chat` остаётся ~72 старых захардкоженных строки (экраны создания чата, участников,
поиска) — это T-15, отдельная механическая задача.

**Тема:** новые виджеты собраны на токенах `ColorScheme`; светлая и тёмная отрендерены и сверены.
Единственные жёсткие цвета — чёрный фон полноэкранного просмотра медиа, как и в `call_screen.dart`.

### Ярус 3 — дорого, но обязательно

| # | Задача | Стоимость | Польза |
|---|---|---|---|
| T-15 | **V-11**: миграция всех строк в ARB (~200 строк: чат, участники, профиль, уведомления, роутер). Механическая, но большая | L | Снимает сквозное нарушение правила проекта. Чем позже, тем дороже |
| T-16 | **§2.2**: айдентика ChatiX — палитра violet/mint, асимметричные радиусы 20/20/20/6, градиент исходящего пузыря, цвет автора из `user_id`, табличные цифры, единая пружина 220 мс. Через `app_theme_extension.dart` | L | Приложение перестаёт быть дефолтным Material |
| T-17 | **§2.1**: группировка сообщений, липкий разделитель дат, разделитель «непрочитанные», FAB «вниз» со счётчиком, свайп-по-сообщению → ответ, правка в поле ввода вместо `AlertDialog` | L | Основной набор ожидаемых паттернов мессенджера |
| T-18 | **V-8**: настоящий FCM/APNs вместо `DebugNotificationService`; `firebase_messaging`, разрешения, каналы | M | Пуши начинают работать; бэкенд перестаёт получать мусорные устройства |
| T-19 | **V-12/G-?**: голосовые сообщения — нужен пакет записи (в pubspec нет), удержание микрофона, свайп-отмена, waveform-плеер, `attachment_type: "voice"`, лимит 600 с | L | Крупная фича, data-слой готов целиком |
| T-20 | Видео: `video_note` (кружки) и превью видео — нужен `video_player`/`chewie` | L | Data-слой готов; зависимостей нет |

### Ярус 4 — мелочи и гигиена

| # | Задача | Стоимость |
|---|---|---|
| T-21 | **V-2**: свой дедуп direct-чатов до `POST /chats/` (искать существующий 1:1 по `peerId` в загруженном списке; при промахе — принять риск дубля и залогировать). Оставить чтение `DIRECT_CHAT_EXISTS` как ремень безопасности | S |
| T-22 | **V-14**: показывать `ws.error NOT_CHAT_MEMBER` пользователю (тот же баннер, что `isGone`) | XS |
| T-23 | **V-13**: `initial_chat_id`/`initial_last_seq` в `_buildUri` — минус один round-trip на вход в чат | XS |
| T-24 | **G-11**: поле «комментарий» в диалоге форварда (`comment` уже прокинут до data) | XS |
| T-25 | **G-12**: `GET /users/sessions/` + экран «Мои устройства» (голый массив, не `PageResult` — §0.16) | S |
| T-26 | Семантика `banned_to` в UI бана (null = навсегда, прошлое = разбан) — сейчас пользователь угадывает | XS |
| T-27 | Аватар чата: `ChatDTO.avatar_s3_key` приходит, не отображается; эндпоинта загрузки аватара чата в §5 нет — **требует бэкенда** | XS (чтение) |
| T-28 | Удалить `lib/examples/**` и `component_showcase_screen.dart` из прод-сборки либо спрятать за флагом | XS |

---
