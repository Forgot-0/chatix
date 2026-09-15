import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/notifications/notification_providers.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/storage/secure_storage_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:chatix/features/auth/domain/usecases/login_use_case.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/ensure_my_profile_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockGetCurrentUserUseCase extends Mock
    implements GetCurrentUserUseCase {}

class _MockEnsureMyProfileUseCase extends Mock
    implements EnsureMyProfileUseCase {}

class _MockSecureStorage extends Mock implements SecureStorageService {}

class _MockNotificationService extends Mock implements NotificationService {}

void main() {
  const tUser = UserEntity(id: 7, username: 'ivan', email: 'ivan@example.com');

  const tProfile = ProfileEntity(
    id: 7,
    avatars: {},
    specialization: null,
    displayName: null,
    bio: null,
    dateBirthday: null,
    skills: [],
    contacts: [],
  );

  late _MockLoginUseCase login;
  late _MockGetCurrentUserUseCase getCurrentUser;
  late _MockEnsureMyProfileUseCase ensureMyProfile;
  late _MockSecureStorage storage;
  late _MockNotificationService notifications;

  setUp(() {
    login = _MockLoginUseCase();
    getCurrentUser = _MockGetCurrentUserUseCase();
    ensureMyProfile = _MockEnsureMyProfileUseCase();
    storage = _MockSecureStorage();
    notifications = _MockNotificationService();

    // No token on disk: the controller resolves to a signed-out state.
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => login.execute(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => getCurrentUser.execute(),
    ).thenAnswer((_) async => const Right(tUser));
    when(
      () => ensureMyProfile.execute(),
    ).thenAnswer((_) async => const Right(tProfile));
    // Skips the push registration branch without touching Firebase.
    when(() => notifications.getToken()).thenAnswer((_) async => null);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        loginUseCaseProvider.overrideWithValue(login),
        getCurrentUserUseCaseProvider.overrideWithValue(getCurrentUser),
        ensureMyProfileUseCaseProvider.overrideWithValue(ensureMyProfile),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('login bootstraps the profile (api-docs §4.1)', () {
    test('calls GET /profiles/my/ once the user is loaded', () async {
      final container = makeContainer();
      await container.read(authProvider.future);

      await container
          .read(authProvider.notifier)
          .login(username: 'ivan', password: 'secret');

      verify(() => ensureMyProfile.execute()).called(1);
      expect(container.read(authProvider).value, tUser);
    });

    test('a failed bootstrap leaves the user signed in', () async {
      when(() => ensureMyProfile.execute()).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'kafka is behind')),
      );

      final container = makeContainer();
      await container.read(authProvider.future);

      await container
          .read(authProvider.notifier)
          .login(username: 'ivan', password: 'secret');

      // The account exists either way — the profile screen can retry.
      expect(container.read(authProvider).value, tUser);
      expect(container.read(authProvider).hasError, isFalse);
    });

    test('a failed login never reaches the profile', () async {
      when(
        () => login.execute(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const Left(AuthFailure(message: 'bad credentials')),
      );

      final container = makeContainer();
      await container.read(authProvider.future);

      await container
          .read(authProvider.notifier)
          .login(username: 'ivan', password: 'nope');

      verifyNever(() => ensureMyProfile.execute());
      expect(container.read(authProvider).hasError, isTrue);
    });
  });
}
