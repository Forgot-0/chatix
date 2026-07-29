# Манифест изменений — lib/features/auth (chatix)

Каждый путь ниже — точный путь **от корня репозитория** `chatix/`.
Внутри архива структура папок такая же, как в репо — просто распакуйте
поверх рабочей копии (или скопируйте файлы вручную по указанным путям).

## Новые файлы (создать)

```
lib/features/auth/domain/usecases/get_current_user_use_case.dart
lib/features/auth/domain/usecases/request_email_verification_use_case.dart
lib/features/auth/domain/usecases/confirm_email_verification_use_case.dart
lib/features/auth/domain/usecases/request_password_reset_use_case.dart
lib/features/auth/domain/usecases/confirm_password_reset_use_case.dart
lib/features/auth/domain/usecases/get_oauth_url_use_case.dart
lib/features/auth/presentation/screens/verify_email_screen.dart
lib/features/auth/presentation/screens/reset_password_request_screen.dart
lib/features/auth/presentation/screens/reset_password_confirm_screen.dart
lib/features/auth/presentation/utils/auth_field_validators.dart
lib/features/auth/presentation/widgets/oauth_buttons.dart
test/features/auth/domain/usecases/register_use_case_test.dart
test/features/auth/domain/usecases/get_current_user_use_case_test.dart
```

## Изменённые файлы (перезаписать существующие)

```
lib/core/constants/app_constants.dart
lib/core/providers/network_providers.dart
lib/core/router/app_router.dart
lib/features/auth/data/datasources/auth_remote_data_source.dart
lib/features/auth/data/models/user_model.dart
lib/features/auth/data/models/user_model.g.dart
lib/features/auth/data/repositories/auth_repository_impl.dart
lib/features/auth/domain/entities/user_entity.dart
lib/features/auth/domain/repositories/auth_repository.dart
lib/features/auth/domain/usecases/login_use_case.dart
lib/features/auth/domain/usecases/register_use_case.dart
lib/features/auth/domain/usecases/logout_use_case.dart   <- содержимое не менялось по сути, включён для полноты
lib/features/auth/presentation/providers/auth_provider.dart
lib/features/auth/presentation/providers/auth_providers.dart
lib/features/auth/presentation/screens/login_screen.dart
lib/features/auth/presentation/screens/register_screen.dart
lib/features/home/presentation/screens/home_screen.dart
test/features/auth/domain/usecases/login_use_case_test.dart
```

## Удалить (больше не используются — консолидировано в presentation/providers/)

```
lib/features/auth/providers/auth_providers.dart
lib/features/auth/providers/cache_auth_providers.dart
```
После удаления файлов папка `lib/features/auth/providers/` останется пустой — можно удалить и её.

## Не менялось, но стоит помнить

- `lib/features/auth/data/repositories/cached_user_repository_impl.dart` — остался пустым, как и был (кэширование сознательно не реализовывал, см. комментарий в `auth_repository_impl.dart`).
- `test/features/auth/presentation/screens/login_screen_golden_test.dart` — не менялся, но эталонный PNG нужно перегенерировать (`--update-goldens`) — UI экрана логина существенно изменился.

## TODO (перенесено из финального резюме)

1. **OAuth callback** — `oauth_buttons.dart` открывает браузер, но приём `access_token` после редиректа с `/auth/oauth/{provider}/callback/` не реализован (см. TODO-комментарий в файле — схема зависит от `redirect_uri`, что сами api-docs (§3.8) отмечают как открытый вопрос).
2. `verify_email_screen.dart` не читает токен из deep link/query-параметра — только ручной ввод.
3. Golden-тест `login_screen_golden_test.dart` нужно перегенерировать локально.
4. `user_model.g.dart` написан вручную (в песочнице не было доступа к `pub.dev`/Flutter SDK для `build_runner`) — стоит прогнать `dart run build_runner build --delete-conflicting-outputs` при первом реальном запуске, чтобы сверить с реальной генерацией.
5. `UserDetailEntity` (roles/permissions/sessions) не заведён — осознанно отложено до админ-экранов.
