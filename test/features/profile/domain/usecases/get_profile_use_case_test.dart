import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/domain/usecases/get_profile_use_case.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late GetProfileUseCase useCase;
  late MockProfileRepository mockProfileRepository;

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    useCase = GetProfileUseCase(mockProfileRepository);
  });

  const tProfile = ProfileEntity(
    id: 42,
    username: 'ivan',
    avatars: {},
    specialization: null,
    displayName: null,
    bio: null,
    dateBirthday: null,
    skills: [],
    contacts: [],
  );

  const missingProfile = ApiFailure(
    code: 'NOT_FOUND_PROFILE',
    message: 'Profile not found',
    detail: {'profile_id': 42},
    status: 404,
  );

  test(
    'should return ProfileEntity from GET /profiles/{id}/ on success',
    () async {
      when(
        () => mockProfileRepository.getProfile(42),
      ).thenAnswer((_) async => const Right(tProfile));

      final result = await useCase.execute(42);

      expect(result, const Right(tProfile));
      verify(() => mockProfileRepository.getProfile(42)).called(1);
    },
  );

  test(
    'should return InputFailure and never hit the repository for a non-positive profileId',
    () async {
      final result = await useCase.execute(0);

      result.fold(
        (failure) => expect(failure, isA<InputFailure>()),
        (_) => fail('Should have returned a failure'),
      );
      verifyZeroInteractions(mockProfileRepository);
    },
  );

  group('NOT_FOUND_PROFILE is a wait, not an answer (api-docs §0.8/§4.1)', () {
    test('retries a missing profile and returns it once it appears', () async {
      var calls = 0;
      when(() => mockProfileRepository.getProfile(42)).thenAnswer((_) async {
        calls++;
        return calls < 3 ? const Left(missingProfile) : const Right(tProfile);
      });

      final result = await useCase.execute(
        42,
        delay: Duration.zero,
      );

      expect(result, const Right(tProfile));
      expect(calls, 3);
    });

    test('gives up after the attempt budget and reports the 404', () async {
      when(
        () => mockProfileRepository.getProfile(42),
      ).thenAnswer((_) async => const Left(missingProfile));

      final result = await useCase.execute(
        42,
        attempts: 3,
        delay: Duration.zero,
      );

      expect(result, const Left<Failure, ProfileEntity>(missingProfile));
      verify(() => mockProfileRepository.getProfile(42)).called(3);
    });

    test('never waits on a failure that is not a missing profile', () async {
      const denied = ApiFailure(
        code: 'ACCESS_DENIED',
        message: 'Not allowed',
        detail: {},
        status: 403,
      );
      when(
        () => mockProfileRepository.getProfile(42),
      ).thenAnswer((_) async => const Left(denied));

      final result = await useCase.execute(42, delay: Duration.zero);

      expect(result, const Left<Failure, ProfileEntity>(denied));
      // One attempt: a 403 will not become a 200 by being asked again.
      verify(() => mockProfileRepository.getProfile(42)).called(1);
    });

    test('a network failure is answered at once too', () async {
      when(
        () => mockProfileRepository.getProfile(42),
      ).thenAnswer((_) async => const Left(NetworkFailure()));

      final result = await useCase.execute(42, delay: Duration.zero);

      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      verify(() => mockProfileRepository.getProfile(42)).called(1);
    });
  });
}
