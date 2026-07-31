import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/avatar_presign_entity.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/domain/repositories/avatar_uploader.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/domain/usecases/upload_avatar_use_case.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAvatarUploader extends Mock implements AvatarUploader {}

void main() {
  late UploadAvatarUseCase useCase;
  late MockProfileRepository mockProfileRepository;
  late MockAvatarUploader mockAvatarUploader;

  setUpAll(() {
    registerFallbackValue(<String, String>{});
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    mockAvatarUploader = MockAvatarUploader();
    useCase = UploadAvatarUseCase(mockProfileRepository, mockAvatarUploader);
  });

  final tBytes = Uint8List.fromList(List.filled(10, 1));
  const tFilename = 'avatar.png';
  const tContentType = 'image/png';

  const tPresign = AvatarPresignEntity(
    url: 'https://minio.example.com/avatars',
    fields: {'key': 'avatars/1/avatar.png', 'policy': 'xyz'},
    keyBase: 'avatars/1',
  );

  test('should emit presigning -> uploading -> confirming -> done on full success', () async {
    // Arrange
    when(
      () => mockProfileRepository.presignAvatar(
        filename: tFilename,
        size: tBytes.length,
        contentType: tContentType,
      ),
    ).thenAnswer((_) async => const Right(tPresign));
    when(
      () => mockAvatarUploader.upload(
        url: tPresign.url,
        fields: tPresign.fields,
        bytes: tBytes,
        filename: tFilename,
        contentType: tContentType,
      ),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => mockProfileRepository.completeAvatarUpload(
        keyBase: tPresign.keyBase,
        size: tBytes.length,
        contentType: tContentType,
      ),
    ).thenAnswer((_) async => const Right(null));

    // Act
    final stream = useCase.execute(bytes: tBytes, filename: tFilename, contentType: tContentType);

    // Assert
    await expectLater(
      stream,
      emitsInOrder([
        const Right<Failure, AvatarUploadStage>(AvatarUploadStage.presigning),
        const Right<Failure, AvatarUploadStage>(AvatarUploadStage.uploading),
        const Right<Failure, AvatarUploadStage>(AvatarUploadStage.confirming),
        const Right<Failure, AvatarUploadStage>(AvatarUploadStage.done),
        emitsDone,
      ]),
    );
    verify(
      () => mockProfileRepository.presignAvatar(
        filename: tFilename,
        size: tBytes.length,
        contentType: tContentType,
      ),
    ).called(1);
    verify(
      () => mockAvatarUploader.upload(
        url: tPresign.url,
        fields: tPresign.fields,
        bytes: tBytes,
        filename: tFilename,
        contentType: tContentType,
      ),
    ).called(1);
    verify(
      () => mockProfileRepository.completeAvatarUpload(
        keyBase: tPresign.keyBase,
        size: tBytes.length,
        contentType: tContentType,
      ),
    ).called(1);
  });

  test(
    'should emit presigning then the Failure and stop, never calling the uploader, when presign fails',
    () async {
      // Arrange
      const tFailure = ApiFailure(
        code: 'AVATAR_NOT_TYPE_IMAGE',
        message: 'Not an image',
        detail: {'type': 'image/png'},
        status: 400,
      );
      when(
        () => mockProfileRepository.presignAvatar(
          filename: tFilename,
          size: tBytes.length,
          contentType: tContentType,
        ),
      ).thenAnswer((_) async => const Left(tFailure));

      // Act
      final stream = useCase.execute(bytes: tBytes, filename: tFilename, contentType: tContentType);

      // Assert
      await expectLater(
        stream,
        emitsInOrder([
          const Right<Failure, AvatarUploadStage>(AvatarUploadStage.presigning),
          const Left<Failure, AvatarUploadStage>(tFailure),
          emitsDone,
        ]),
      );
      verifyNever(
        () => mockAvatarUploader.upload(
          url: any(named: 'url'),
          fields: any(named: 'fields'),
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
          contentType: any(named: 'contentType'),
        ),
      );
      verifyNever(
        () => mockProfileRepository.completeAvatarUpload(
          keyBase: any(named: 'keyBase'),
          size: any(named: 'size'),
          contentType: any(named: 'contentType'),
        ),
      );
    },
  );

  test('should stop after uploading fails, never calling completeAvatarUpload', () async {
    // Arrange
    const tFailure = ServerFailure(message: 'Avatar storage rejected the upload', statusCode: 403);
    when(
      () => mockProfileRepository.presignAvatar(
        filename: tFilename,
        size: tBytes.length,
        contentType: tContentType,
      ),
    ).thenAnswer((_) async => const Right(tPresign));
    when(
      () => mockAvatarUploader.upload(
        url: tPresign.url,
        fields: tPresign.fields,
        bytes: tBytes,
        filename: tFilename,
        contentType: tContentType,
      ),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final stream = useCase.execute(bytes: tBytes, filename: tFilename, contentType: tContentType);

    // Assert
    await expectLater(
      stream,
      emitsInOrder([
        const Right<Failure, AvatarUploadStage>(AvatarUploadStage.presigning),
        const Right<Failure, AvatarUploadStage>(AvatarUploadStage.uploading),
        const Left<Failure, AvatarUploadStage>(tFailure),
        emitsDone,
      ]),
    );
    verifyNever(
      () => mockProfileRepository.completeAvatarUpload(
        keyBase: any(named: 'keyBase'),
        size: any(named: 'size'),
        contentType: any(named: 'contentType'),
      ),
    );
  });

  test(
    'should emit a single InputFailure and never call the repository when contentType is not an image',
    () async {
      // Act
      final stream = useCase.execute(bytes: tBytes, filename: tFilename, contentType: 'text/plain');

      // Assert
      await expectLater(
        stream,
        emitsInOrder([isA<Left<Failure, AvatarUploadStage>>(), emitsDone]),
      );
      verifyZeroInteractions(mockProfileRepository);
      verifyZeroInteractions(mockAvatarUploader);
    },
  );

  test(
    'should emit a single InputFailure and never call the repository when the file exceeds 5MB',
    () async {
      // Arrange
      final tooLargeBytes = Uint8List(UploadAvatarUseCase.maxSizeBytes + 1);

      // Act
      final stream = useCase.execute(
        bytes: tooLargeBytes,
        filename: tFilename,
        contentType: tContentType,
      );

      // Assert
      await expectLater(
        stream,
        emitsInOrder([isA<Left<Failure, AvatarUploadStage>>(), emitsDone]),
      );
      verifyZeroInteractions(mockProfileRepository);
      verifyZeroInteractions(mockAvatarUploader);
    },
  );

  test('should emit a single InputFailure and never call the repository for an empty file', () async {
    // Act
    final stream = useCase.execute(
      bytes: Uint8List(0),
      filename: tFilename,
      contentType: tContentType,
    );

    // Assert
    await expectLater(
      stream,
      emitsInOrder([isA<Left<Failure, AvatarUploadStage>>(), emitsDone]),
    );
    verifyZeroInteractions(mockProfileRepository);
    verifyZeroInteractions(mockAvatarUploader);
  });
}