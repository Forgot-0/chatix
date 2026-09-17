import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/data/datasources/avatar_uploader_impl.dart';
import 'package:chatix/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:chatix/features/profile/domain/entities/avatar_presign_entity.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/avatar_uploader.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/presentation/providers/avatar_upload_provider.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAvatarUploader extends Mock implements AvatarUploader {}

void main() {
  const profileId = 7;

  final bytes = Uint8List.fromList(List<int>.filled(64, 1));

  ProfileEntity withAvatars(Map<String, Map<String, String>> avatars) =>
      ProfileEntity(
        id: profileId,
        username: 'ivan',
        avatars: avatars,
        specialization: null,
        displayName: null,
        bio: null,
        dateBirthday: null,
        skills: const [],
        contacts: const [],
      );

  const noAvatar = <String, Map<String, String>>{};
  const oldAvatar = {
    '256': {'webp': 'https://cdn.example.com/old.webp'},
  };
  const newAvatar = {
    '256': {'webp': 'https://cdn.example.com/new.webp'},
  };

  late MockProfileRepository repository;
  late MockAvatarUploader uploader;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repository = MockProfileRepository();
    uploader = MockAvatarUploader();

    when(
      () => repository.presignAvatar(filename: any(named: 'filename')),
    ).thenAnswer(
      (_) async => const Right(
        AvatarPresignEntity(url: 'https://s3.example.com/put', fileKey: 'k'),
      ),
    );
    when(
      () => uploader.upload(
        url: any(named: 'url'),
        bytes: any(named: 'bytes'),
        contentType: any(named: 'contentType'),
      ),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => repository.completeAvatarUpload(fileKey: any(named: 'fileKey')),
    ).thenAnswer((_) async => const Right(null));
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        avatarUploaderProvider.overrideWithValue(uploader),
        // The real wait is ten seconds of polling; the behaviour under test
        // is what happens at the end of it.
        avatarPollScheduleProvider.overrideWithValue(
          const AvatarPollSchedule(attempts: 3, interval: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> upload(ProviderContainer container) {
    return container
        .read(avatarUploadProvider.notifier)
        .upload(
          profileId: profileId,
          bytes: bytes,
          filename: 'avatar.png',
          contentType: 'image/png',
        );
  }

  /// The profile reads the controller makes: one before the upload, then one
  /// per poll.
  void stubProfileReads(List<Map<String, Map<String, String>>> reads) {
    var call = 0;
    when(() => repository.getMyProfile()).thenAnswer((_) async {
      final avatars = reads[call < reads.length ? call : reads.length - 1];
      call++;
      return Right(withAvatars(avatars));
    });
  }

  group('the upload is only done when the avatar actually changed (§4.5)', () {
    test('a changed avatar map settles as done', () async {
      stubProfileReads([oldAvatar, oldAvatar, newAvatar]);

      final container = makeContainer();
      container.listen(avatarUploadProvider, (_, _) {});

      await upload(container);

      final state = container.read(avatarUploadProvider);
      expect(state.hasError, isFalse);
      expect(state.value, AvatarUploadStage.done);
      // Nothing left to retry once it worked.
      expect(container.read(avatarUploadProvider.notifier).lastAttempt, isNull);
    });

    test(
      'an avatar map that never changes is a failure, not a success',
      () async {
        // `upload_complete` answers 200 whatever the file is; the background
        // task's AVATAR_SIZE / AVATAR_NOT_TYPE_IMAGE never reach the client,
        // so the only evidence is that nothing appeared (api-docs §2.5).
        stubProfileReads([oldAvatar]);

        final container = makeContainer();
        container.listen(avatarUploadProvider, (_, _) {});

        await upload(container);

        final state = container.read(avatarUploadProvider);
        expect(state.hasError, isTrue);
        expect(state.error, isA<AvatarProcessingFailure>());
      },
    );

    test('a first avatar counts as a change even from an empty map', () async {
      stubProfileReads([noAvatar, newAvatar]);

      final container = makeContainer();
      container.listen(avatarUploadProvider, (_, _) {});

      await upload(container);

      expect(container.read(avatarUploadProvider).value, AvatarUploadStage.done);
    });

    test('an empty map on a poll is not mistaken for a new avatar', () async {
      // The picture was removed, or was never written: either way there is
      // no avatar to show, so this is not a successful upload.
      stubProfileReads([oldAvatar, noAvatar]);

      final container = makeContainer();
      container.listen(avatarUploadProvider, (_, _) {});

      await upload(container);

      expect(
        container.read(avatarUploadProvider).error,
        isA<AvatarProcessingFailure>(),
      );
    });
  });

  group('retrying', () {
    test('a failed run keeps its picture so it can be resent', () async {
      stubProfileReads([oldAvatar]);

      final container = makeContainer();
      container.listen(avatarUploadProvider, (_, _) {});

      await upload(container);

      final notifier = container.read(avatarUploadProvider.notifier);
      expect(notifier.lastAttempt?.filename, 'avatar.png');

      // The second run finds the avatar there and settles.
      stubProfileReads([oldAvatar, newAvatar]);
      await notifier.retry();

      expect(container.read(avatarUploadProvider).value, AvatarUploadStage.done);
      verify(
        () => repository.presignAvatar(filename: 'avatar.png'),
      ).called(2);
    });

    test('there is nothing to retry before anything was uploaded', () async {
      final container = makeContainer();

      await container.read(avatarUploadProvider.notifier).retry();

      verifyNever(
        () => repository.presignAvatar(filename: any(named: 'filename')),
      );
    });
  });

  group('a failure before the poll is reported as itself', () {
    test('a refused presign never reaches the polling stage', () async {
      stubProfileReads([oldAvatar]);
      when(
        () => repository.presignAvatar(filename: any(named: 'filename')),
      ).thenAnswer(
        (_) async => const Left(RateLimitFailure()),
      );

      final container = makeContainer();
      container.listen(avatarUploadProvider, (_, _) {});

      await upload(container);

      final state = container.read(avatarUploadProvider);
      expect(state.error, isA<RateLimitFailure>());
      verifyNever(
        () => repository.completeAvatarUpload(fileKey: any(named: 'fileKey')),
      );
    });

    test('an expired presigned PUT is surfaced verbatim', () async {
      stubProfileReads([oldAvatar]);
      when(
        () => uploader.upload(
          url: any(named: 'url'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
        ),
        // The link lives 90 seconds, which is short enough to actually miss.
      ).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'expired', statusCode: 403)),
      );

      final container = makeContainer();
      container.listen(avatarUploadProvider, (_, _) {});

      await upload(container);

      expect(container.read(avatarUploadProvider).error, isA<ServerFailure>());
    });
  });
}
