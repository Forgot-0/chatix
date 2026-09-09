import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  const myUserId = 7;
  const otherUserId = 42;

  ProfileEntity profile(int id) => ProfileEntity(
    id: id,
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
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('profileDetailProvider — api-docs §4.1/§4.3', () {
    test(
      'loads MY OWN profile through GET /profiles/{id}/, never a "my" alias',
      () async {
        when(
          () => repository.getProfile(myUserId),
        ).thenAnswer((_) async => Right(profile(myUserId)));

        final container = makeContainer();

        final result = await container.read(
          profileDetailProvider(myUserId).future,
        );

        expect(result.id, myUserId);
        // `profile.id == user.id`, so own profile has no dedicated endpoint.
        // Regression guard: a separate self-path used to hit `/profiles/my/`,
        // which the backend resolves as profile_id="my" -> 422 VALIDATION.
        verify(() => repository.getProfile(myUserId)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    test('loads someone else through the very same repository call', () async {
      when(
        () => repository.getProfile(otherUserId),
      ).thenAnswer((_) async => Right(profile(otherUserId)));

      final container = makeContainer();

      final result = await container.read(
        profileDetailProvider(otherUserId).future,
      );

      expect(result.id, otherUserId);
      verify(() => repository.getProfile(otherUserId)).called(1);
      verifyNoMoreInteractions(repository);
    });

    test('surfaces the Failure as AsyncError, not as data', () async {
      const failure = ApiFailure(
        code: 'NOT_FOUND_PROFILE',
        message: 'Profile not found',
        detail: {'profile_id': myUserId},
        status: 404,
      );
      when(
        () => repository.getProfile(myUserId),
      ).thenAnswer((_) async => const Left(failure));

      final container = makeContainer();

      // Asserted through the AsyncValue, which is what the UI reads via
      // `.when(error:)`. Awaiting `provider.future` would hang here: Riverpod
      // only completes that future for thrown `Error`s, and a `Failure` is a
      // plain Equatable. See the note on avatar_upload_provider.dart:60.
      final states = <AsyncValue<ProfileEntity>>[];
      container.listen(
        profileDetailProvider(myUserId),
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);

      final settled = container.read(profileDetailProvider(myUserId));
      expect(settled.hasError, isTrue);
      expect(settled.error, failure);
      expect(settled.hasValue, isFalse);
    });
  });
}
