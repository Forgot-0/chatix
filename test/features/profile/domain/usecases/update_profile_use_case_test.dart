import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_update.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/domain/usecases/update_profile_use_case.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late UpdateProfileUseCase useCase;
  late MockProfileRepository mockProfileRepository;

  final tBirthday = DateTime(1995, 5, 20);

  const tUpdate = ProfileUpdate(
    specialization: 'Backend engineer',
    displayName: 'Jane',
    bio: 'Hello',
    skills: ['dart', 'flutter'],
  );

  setUpAll(() {
    registerFallbackValue(const ProfileUpdate());
  });

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    useCase = UpdateProfileUseCase(mockProfileRepository);
  });

  void stubUpdate([Either<Failure, void> answer = const Right(null)]) {
    when(
      () => mockProfileRepository.updateProfile(any(), any()),
    ).thenAnswer((_) async => answer);
  }

  test('passes the whole update through to the repository', () async {
    stubUpdate();

    final update = tUpdate.copyWith(dateBirthday: tBirthday);
    final result = await useCase.execute(1, update);

    expect(result, const Right<Failure, void>(null));
    verify(() => mockProfileRepository.updateProfile(1, update)).called(1);
  });

  test(
    'carries cleared fields as nulls rather than dropping them (§4.4)',
    () async {
      stubUpdate();

      // Everything blanked: a PUT that omitted these would leave the old
      // values in place, which is the bug this shape exists to prevent.
      const cleared = ProfileUpdate();
      await useCase.execute(1, cleared);

      final captured =
          verify(
                () => mockProfileRepository.updateProfile(1, captureAny()),
              ).captured.single
              as ProfileUpdate;

      expect(captured.displayName, isNull);
      expect(captured.specialization, isNull);
      expect(captured.bio, isNull);
      expect(captured.dateBirthday, isNull);
      expect(captured.skills, isEmpty);
    },
  );

  test('returns the repository Failure when the update fails', () async {
    const tFailure = ApiFailure(
      code: 'ACCESS_DENIED',
      message: 'Cannot edit this profile',
      detail: {},
      status: 403,
    );
    stubUpdate(const Left(tFailure));

    final result = await useCase.execute(1, tUpdate);

    expect(result, const Left<Failure, void>(tFailure));
  });

  test('rejects a non-positive profileId without a request', () async {
    final result = await useCase.execute(0, tUpdate);

    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('rejects a display name of 100 characters (TOO_LONG_*)', () async {
    final result = await useCase.execute(
      1,
      ProfileUpdate(displayName: 'a' * 100),
    );

    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('allows a display name exactly at the 99 character limit', () async {
    stubUpdate();

    final result = await useCase.execute(
      1,
      ProfileUpdate(displayName: 'a' * 99),
    );

    expect(result, const Right<Failure, void>(null));
  });

  test('rejects a bio of 1024 characters', () async {
    final result = await useCase.execute(1, ProfileUpdate(bio: 'a' * 1024));

    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('allows a bio exactly at the 1023 character limit', () async {
    stubUpdate();

    final result = await useCase.execute(1, ProfileUpdate(bio: 'a' * 1023));

    expect(result, const Right<Failure, void>(null));
  });

  test('rejects a skill longer than 30 characters', () async {
    final result = await useCase.execute(
      1,
      ProfileUpdate(skills: ['dart', 'a' * 31]),
    );

    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('allows a skill exactly at the 30 character limit', () async {
    stubUpdate();

    final result = await useCase.execute(
      1,
      ProfileUpdate(skills: ['a' * 30]),
    );

    expect(result, const Right<Failure, void>(null));
  });
}
