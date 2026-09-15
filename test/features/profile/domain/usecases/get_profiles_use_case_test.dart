import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

/// `q` searches username OR display_name in one request; `username` and
/// `display_name` are the old AND pair, and mixing the two is a 422
/// (api-docs §4.2).
void main() {
  late MockProfileRepository repository;
  late GetProfilesUseCase useCase;

  setUp(() {
    repository = MockProfileRepository();
    useCase = GetProfilesUseCase(repository);

    when(
      () => repository.getProfiles(
        q: any(named: 'q'),
        username: any(named: 'username'),
        displayName: any(named: 'displayName'),
        skills: any(named: 'skills'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        PageResult<ProfileEntity>(items: [], total: 0, page: 1, pageSize: 20),
      ),
    );
  });

  test('a search goes out as one trimmed q', () async {
    await useCase.execute(q: '  ann  ');

    verify(
      () => repository.getProfiles(
        q: 'ann',
        username: null,
        displayName: null,
        skills: null,
        page: 1,
        pageSize: 20,
        sort: null,
        cancellation: null,
      ),
    ).called(1);
  });

  test('one character is not sent, because the server refuses it', () async {
    final result = await useCase.execute(q: 'a');

    expect(result.getLeft().toNullable(), isA<InputFailure>());
    verifyNever(
      () => repository.getProfiles(
        q: any(named: 'q'),
        username: any(named: 'username'),
        displayName: any(named: 'displayName'),
        skills: any(named: 'skills'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
        cancellation: any(named: 'cancellation'),
      ),
    );
  });

  test('a query longer than the server takes is refused here', () async {
    final result = await useCase.execute(
      q: 'x' * (GetProfilesUseCase.maxQueryLength + 1),
    );

    expect(result.getLeft().toNullable(), isA<InputFailure>());
  });

  test('q with a field is refused rather than sent to be 422d', () async {
    final result = await useCase.execute(q: 'ann', username: 'ann');

    expect(result.getLeft().toNullable(), isA<InputFailure>());
  });

  test('the old fields still work on their own', () async {
    await useCase.execute(username: 'ann', displayName: 'Ann');

    verify(
      () => repository.getProfiles(
        q: null,
        username: 'ann',
        displayName: 'Ann',
        skills: null,
        page: 1,
        pageSize: 20,
        sort: null,
        cancellation: null,
      ),
    ).called(1);
  });

  test('a listing with no query at all is still allowed', () async {
    final result = await useCase.execute(page: 2);

    expect(result.isRight(), isTrue);
  });
}
