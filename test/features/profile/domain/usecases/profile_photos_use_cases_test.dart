import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_photo.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/domain/usecases/get_profile_by_username_use_case.dart';
import 'package:chatix/features/profile/domain/usecases/get_profile_photos_use_case.dart';
import 'package:chatix/features/profile/domain/usecases/manage_profile_photos_use_case.dart';

class _MockRepository extends Mock implements ProfileRepository {}

const _profile = ProfileEntity(
  id: 42,
  username: 'durov',
  avatars: {},
  specialization: null,
  displayName: null,
  bio: null,
  dateBirthday: null,
  skills: [],
  contacts: [],
);

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  group('GetProfileByUsernameUseCase', () {
    test('takes the handle with or without its @, space around it', () {
      expect(GetProfileByUsernameUseCase.normalize('durov'), 'durov');
      expect(GetProfileByUsernameUseCase.normalize('@durov'), 'durov');
      expect(GetProfileByUsernameUseCase.normalize('  @ Durov '), 'Durov');
      expect(GetProfileByUsernameUseCase.normalize(' @ '), isNull);
    });

    test('asks the repository with the handle bare', () async {
      when(
        () => repository.getProfileByUsername(any()),
      ).thenAnswer((_) async => const Right(_profile));

      final result = await GetProfileByUsernameUseCase(
        repository,
      ).execute('@durov');

      expect(result.getRight().toNullable(), _profile);
      verify(() => repository.getProfileByUsername('durov')).called(1);
    });

    test('an empty handle never leaves the device', () async {
      final result = await GetProfileByUsernameUseCase(repository).execute('@');

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNever(() => repository.getProfileByUsername(any()));
    });
  });

  group('GetProfilePhotosUseCase', () {
    test('the whole history in one page of a hundred', () async {
      final photo = ProfilePhoto(
        id: 'p1',
        avatars: const {},
        isMain: true,
        createdAt: DateTime.utc(2026, 10, 1),
      );
      when(
        () => repository.getPhotos(any(), pageSize: any(named: 'pageSize')),
      ).thenAnswer(
        (_) async =>
            Right(PageResult(items: [photo], total: 1, page: 1, pageSize: 100)),
      );

      final result = await GetProfilePhotosUseCase(repository).execute(42);

      expect(result.getRight().toNullable(), [photo]);
      verify(
        () => repository.getPhotos(
          42,
          pageSize: GetProfilePhotosUseCase.maxPhotos,
        ),
      ).called(1);
    });

    test('a nonsense id is refused at once', () async {
      final result = await GetProfilePhotosUseCase(repository).execute(0);
      expect(result.getLeft().toNullable(), isA<InputFailure>());
    });
  });

  group('ManageProfilePhotosUseCase', () {
    test('passes a real id through', () async {
      when(
        () => repository.setMainPhoto(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => repository.deletePhoto(any()),
      ).thenAnswer((_) async => const Right(null));
      final useCase = ManageProfilePhotosUseCase(repository);

      expect((await useCase.makeMain('p1')).isRight(), isTrue);
      expect((await useCase.delete('p2')).isRight(), isTrue);
      verify(() => repository.setMainPhoto('p1')).called(1);
      verify(() => repository.deletePhoto('p2')).called(1);
    });

    test('a blank id is refused before a request', () async {
      final useCase = ManageProfilePhotosUseCase(repository);

      expect((await useCase.makeMain(' ')).isLeft(), isTrue);
      expect((await useCase.delete('')).isLeft(), isTrue);
      verifyNever(() => repository.setMainPhoto(any()));
      verifyNever(() => repository.deletePhoto(any()));
    });
  });
}
