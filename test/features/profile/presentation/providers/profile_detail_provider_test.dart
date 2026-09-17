import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

/// Signed in as user 7, with none of the real controller's bootstrap.
class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: myUserId, username: 'me', email: 'me@example.com');
}

const int myUserId = 7;

void main() {
  const otherUserId = 42;

  ProfileEntity profile(int id) => ProfileEntity(
    id: id,
    username: 'user$id',
    avatars: const {},
    specialization: null,
    displayName: null,
    bio: null,
    dateBirthday: null,
    skills: const [],
    contacts: const [],
  );

  late MockProfileRepository repository;

  setUp(() {
    repository = MockProfileRepository();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(_FakeAuthController.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Lets the fake auth controller settle so the provider knows who "me" is.
  Future<void> signIn(ProviderContainer container) async {
    await container.read(authProvider.future);
  }

  group('profileDetailProvider — api-docs §4.1/§4.3', () {
    test('loads MY OWN profile through GET /profiles/my/', () async {
      when(
        () => repository.getMyProfile(),
      ).thenAnswer((_) async => Right(profile(myUserId)));

      final container = makeContainer();
      await signIn(container);

      final result = await container.read(
        profileDetailProvider(myUserId).future,
      );

      expect(result.id, myUserId);
      // `/profiles/my/` is a GetOrCreate: the row is normally written by the
      // `auth.user.verified` consumer, and until that lands
      // `GET /profiles/{id}/` answers 404 for an account that exists
      // (api-docs §0.8, §4.1). Asking for the numeric id here would
      // reintroduce that window.
      verify(() => repository.getMyProfile()).called(1);
      verifyNever(() => repository.getProfile(any()));
    });

    test('loads someone else through GET /profiles/{id}/', () async {
      when(
        () => repository.getProfile(otherUserId),
      ).thenAnswer((_) async => Right(profile(otherUserId)));

      final container = makeContainer();
      await signIn(container);

      final result = await container.read(
        profileDetailProvider(otherUserId).future,
      );

      expect(result.id, otherUserId);
      verify(() => repository.getProfile(otherUserId)).called(1);
      verifyNever(() => repository.getMyProfile());
    });

    test('surfaces the Failure as AsyncError, not as data', () async {
      // Deliberately not NOT_FOUND_PROFILE: that one is retried for several
      // seconds by GetProfileUseCase, which has its own test.
      const failure = ApiFailure(
        code: 'ACCESS_DENIED',
        message: 'Not allowed',
        detail: {},
        status: 403,
      );
      when(
        () => repository.getProfile(otherUserId),
      ).thenAnswer((_) async => const Left(failure));

      final container = makeContainer();
      await signIn(container);

      // Asserted through the AsyncValue, which is what the UI reads via
      // `.when(error:)`. Awaiting `provider.future` would hang here: Riverpod
      // only completes that future for thrown `Error`s, and a `Failure` is a
      // plain Equatable.
      container.listen(
        profileDetailProvider(otherUserId),
        (_, _) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);

      final settled = container.read(profileDetailProvider(otherUserId));
      expect(settled.hasError, isTrue);
      expect(settled.error, failure);
      expect(settled.hasValue, isFalse);
    });
  });
}
