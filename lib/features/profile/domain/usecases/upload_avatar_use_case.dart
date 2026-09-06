import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/domain/repositories/avatar_uploader.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

class UploadAvatarUseCase {
  static const maxSizeBytes = 5 * 1024 * 1024;

  final ProfileRepository _repository;
  final AvatarUploader _avatarUploader;

  UploadAvatarUseCase(this._repository, this._avatarUploader);

  Stream<Either<Failure, AvatarUploadStage>> execute({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async* {
    final size = bytes.length;

    if (!contentType.startsWith('image/')) {
      yield const Left(InputFailure(message: 'File must be an image'));
      return;
    }

    if (size <= 0) {
      yield const Left(InputFailure(message: 'File is empty'));
      return;
    }

    if (size > maxSizeBytes) {
      yield const Left(InputFailure(message: 'Image must be 5MB or smaller'));
      return;
    }

    if (filename.isEmpty) {
      yield const Left(InputFailure(message: 'Filename cannot be empty'));
      return;
    }

    yield const Right(AvatarUploadStage.presigning);
    final presignResult = await _repository.presignAvatar(filename: filename);

    if (presignResult.isLeft()) {
      yield Left(presignResult.getLeft().toNullable()!);
      return;
    }
    final presign = presignResult.getRight().toNullable()!;

    yield const Right(AvatarUploadStage.uploading);
    final uploadResult = await _avatarUploader.upload(
      url: presign.url,
      bytes: bytes,
      contentType: contentType,
    );

    if (uploadResult.isLeft()) {
      yield Left(uploadResult.getLeft().toNullable()!);
      return;
    }

    yield const Right(AvatarUploadStage.confirming);
    final completeResult = await _repository.completeAvatarUpload(
      fileKey: presign.fileKey,
    );

    if (completeResult.isLeft()) {
      yield Left(completeResult.getLeft().toNullable()!);
      return;
    }

    yield const Right(AvatarUploadStage.done);
  }
}
